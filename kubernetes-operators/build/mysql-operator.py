import kopf
import yaml
import kubernetes
import time
from jinja2 import Environment, FileSystemLoader
import logging


def render_template(filename, vars_dict):
    env = Environment(loader=FileSystemLoader('./templates'))
    template = env.get_template(filename)
    yaml_manifest = template.render(vars_dict)
    json_manifest = yaml.safe_load(yaml_manifest)
    return json_manifest


def delete_success_jobs(mysql_instance_name):
    api = kubernetes.client.BatchV1Api()
    jobs = api.list_namespaced_job('default')
    for job in jobs.items:
        jobname = job.metadata.name
        if (jobname == f"backup-{mysql_instance_name}-job") or \
                (jobname == f"restore-{mysql_instance_name}-job") or \
                (jobname == f"change-password-{mysql_instance_name}-job"):
            if job.status.succeeded == 1:
                api.delete_namespaced_job(jobname,
                                          'default',
                                          propagation_policy='Background')
                logging.info(f"Job with name:[{jobname}] deleted")
            else:
                logging.info(f"Job with name:[{jobname}] unsucceeded state NOT deleted")


def wait_until_job_end(jobname):
    api = kubernetes.client.BatchV1Api()
    job_finished = False
    jobs = api.list_namespaced_job('default')
    while (not job_finished) and \
            any(job.metadata.name == jobname for job in jobs.items):
        time.sleep(1)
        jobs = api.list_namespaced_job('default')
        for job in jobs.items:
            if job.metadata.name == jobname:
                logging.info(f"Job with name:[{jobname}] found, wait untill end")
                if job.status.succeeded == 1:
                    job_finished = True
                    logging.info(f"Job with name:[{jobname}] end sucessful")


@kopf.on.field('otus.homework', 'v1', 'mysqls', field='spec.password')
def password_changed(body, old, new, **_):
    name = body['metadata']['name']
    image = body['spec']['image']
    database = body['spec']['database']
    old_password = old
    new_password = new

    if old_password and new_password:
        change_password_job = render_template('change-password-job.yml.j2', {
            'name': name,
            'image': image,
            'old_password': old_password,
            'new_password': new_password,
            'database': database
            })

        api = kubernetes.client.BatchV1Api()
        change_password_job_name = change_password_job['metadata']['name']
        try:
            api.delete_namespaced_job(change_password_job_name,
                    'default', propagation_policy='Background')
        except kubernetes.client.ApiException as e:
            logging.info(f"Exception when calling delete_namespaced_job:[{change_password_job_name}] {e}")
        
        try:
            api.create_namespaced_job('default', change_password_job)
            wait_until_job_end(f"change-password-{name}-job")
        except kubernetes.client.ApiException as e:
            logging.info(f"Exception when calling create_namespaced_job:[{change_password_job_name}] {e}")


@kopf.on.create('otus.homework', 'v1', 'mysqls')
# Функция, которая будет запускаться при создании объектов тип MySQL:
def mysql_on_create(body, spec, **kwargs):
    name = body['metadata']['name']
    image = body['spec']['image']
    password = body['spec']['password']
    database = body['spec']['database']
    storage_size = body['spec']['storage_size']

    logging.info(f"A handler is called with body: {body}")

    # Генерируем JSON манифесты для деплоя
    persistent_volume = render_template('mysql-pv.yml.j2', 
            {'name': name, 'storage_size': storage_size})
    persistent_volume_claim = render_template('mysql-pvc.yml.j2', 
            {'name': name, 'storage_size': storage_size})
    service = render_template('mysql-service.yml.j2', 
            {'name': name})
    deployment = render_template('mysql-deployment.yml.j2', 
            {'name': name,
             'image': image,
             'password': password,
             'database': database
            })
    restore_job = render_template('restore-job.yml.j2', 
            {'name': name,
             'image': image,
             'password': password,
             'database': database
            })

    # Определяем, что созданные ресурсы являются дочерними к управляемому CustomResource:
    kopf.append_owner_reference(persistent_volume, owner=body)
    kopf.append_owner_reference(persistent_volume_claim, owner=body)
    kopf.append_owner_reference(service, owner=body)
    kopf.append_owner_reference(deployment, owner=body)
    kopf.append_owner_reference(restore_job, owner=body)

    api = kubernetes.client.CoreV1Api()
    # Создаем mysql PV:
    api.create_persistent_volume(persistent_volume)
    # Создаем mysql PVC:
    api.create_namespaced_persistent_volume_claim('default', persistent_volume_claim)
    # Создаем mysql SVC:
    api.create_namespaced_service('default', service)
    # Создаем mysql Deployment:
    api = kubernetes.client.AppsV1Api()
    api.create_namespaced_deployment('default', deployment)

    # Cоздаем PVC и PV для бэкапов:
    try:
        backup_pv = render_template('backup-pv.yml.j2', {'name': name, 'storage_size': storage_size})
        api = kubernetes.client.CoreV1Api()
        api.create_persistent_volume(backup_pv)
    except kubernetes.client.ApiException:
        pass

    new_pvc_created = False
    try:
        backup_pvc = render_template('backup-pvc.yml.j2', {'name': name, 'storage_size': storage_size})
        api = kubernetes.client.CoreV1Api()
        api.create_namespaced_persistent_volume_claim('default', backup_pvc)
        new_pvc_created = True
    except kubernetes.client.ApiException:
        pass

    # Пытаемся восстановиться из backup
    status_recovery_job = "unknown"
    if not new_pvc_created:
        restore_job_name = restore_job['metadata']['name']
        logging.info(f"Start restore job name:[{restore_job_name}]")
        try:
            api = kubernetes.client.BatchV1Api()
            api.create_namespaced_job('default', restore_job)
            wait_until_job_end(restore_job_name)
            logging.info(f"End restore job name:[{restore_job_name}]")
            status_recovery_job = "successful"
        except kubernetes.client.ApiException:
            logging.info(f"Fail restore job name:[{restore_job_name}]")
            status_recovery_job = "failed"
    else:
        status_recovery_job = "previous backup not found"

    return {'recoveryJob': str(status_recovery_job)}

@kopf.on.delete('otus.homework', 'v1', 'mysqls')
def delete_object_make_backup(body, **_):
    name = body['metadata']['name']
    image = body['spec']['image']
    password = body['spec']['password']
    database = body['spec']['database']

    delete_success_jobs(name)
    # Cоздаем backup job:
    api = kubernetes.client.BatchV1Api()
    backup_job = render_template('backup-job.yml.j2', {
        'name': name,
        'image': image,
        'password': password,
        'database': database})
    api.create_namespaced_job('default', backup_job)
    wait_until_job_end(f"backup-{name}-job")

    persistent_volume = render_template('mysql-pv.yml.j2', {'name': name})
    ms_pv_name = persistent_volume['metadata']['name']
    try:
        api = kubernetes.client.CoreV1Api()
        api.delete_persistent_volume(ms_pv_name)
        logging.info(f"PV with name:[{ms_pv_name}] delete sucessful")
    except kubernetes.client.ApiException:
        logging.info(f"PV with name:[{ms_pv_name}] delete failed")

    return {'message': "mysql and its children resources deleted"}
