# vradnit_platform
vradnit Platform repository




# ДЗ-1 Kubernetes-intro

1. Установлен minikub

2. При удалении подов через "kubectl delete":
   kube-proxy - создается заново с помощью контроллера daemonset ( на всех нодах с меткой kubernetes.io/os=linux )
   coredns    - создается заново с помощью контроллера replicaset ( который поддеживает кол-во подов 1 штука )
   etcd-minikube, kube-apiserver-minikube, kube-controller-manager-minikube, kube-scheduler-minikube - не изменяют свое состояние
     т.к. контроллируются сервисом kubelet ( из статических манифестов )

   При удалении контейнеров через "docker rm", контейнеры пересоздаются,
   т.к. kubelet контроллирует работоспособность контейнеров и стартует их заново.

3. Создан kubernetes-intro/web/Dockerfile
   В качестве web сервера используется httpd из образа busybox.
   Образ сохранен на dockerhub в vradnit/web:0.1

4. Создан kubernetes-intro/web-pod.yaml
   В качестве основного контейнера используется образ vradnit/web:0.1
   В качестве init контейнера используется образ "busybox c wget".
   Init контейнер необходим для "первоначального заполнения" директории /app

5. Используя https://github.com/GoogleCloudPlatform/microservices-demo/blob/master/src/frontend/Dockerfile , создан docker образ.
   Образ сохранен на dockerhub в vradnit/hipster-frontend:v0.0.1
   C помошью "kubectl run ... --dry-run" создан манифест пода frontend.
   После создания пода, его статус "error".
   Анализ его лога "kubectl logs frontend" подсказал причину ошибки "нет необходимых переменных окружения".
   Необходимые переменные окружения найдены в src main.go
   Исправленный манифест сохранен в kubernetes-intro/frontend-pod-healthy.yaml




# ДЗ-2 Kubernetes-controllers

1. С помощью kind установлен кластер kubernetes (1 master) + (3 workers).

2. Создан манифест replicaset kubernetes-controllers/frontend-replicaset.yaml
   При этом в манифест replicaset было добавлено обязательное поле "selector" с указанием метки, которая указана в темплейте пода.
   т.к. "In the ReplicaSet, .spec.template.metadata.labels must match spec.selector, or it will be rejected by the API"
   Проведено скалирование replicaset с помощью ad-hoc команды, а также "декларативно" изменив поле replicas в манифесте.

3. Образ vradnit/hipster-frontend:v0.0.1 перетегирован в vradnit/hipster-frontend:v0.0.2 и сохранен в dockerhub.
   Удостоверились, что ReplicaSet для контроля подов использует только метки указанные в "spec.selector" и изменение полей 
   в манифесте пода ( кроме .spec.template.metadata.labels ) не приводит к обновлению запущенных под
   
   Для проверки тега используемого образа в replicaset и поде использовался формат вывода "kubectl ... -o jsonpath"

4. Используя https://github.com/GoogleCloudPlatform/microservices-demo/src/paymentservice/Dockerfile
   coздан образ vradnit/hipster-paymentservice с двумя тегами "v0.0.1" и "v0.0.2"
   Создан манифест kubernetes-controllers/paymentservice-replicaset.yaml
   Изменяя поле kind c replicaset на deployment создан манифест kubernetes-controllers/paymentservice-deployment.yaml

5. После изменения тэга образа, в манифесте deployment, была проконтролирована дефолтная стратегия обновления подов "Rolling Update"
   Проверка состояния подов и replicaset.
   Просмотр "иcтории раскаток" deployment "kubectl rollout history"
   Откат на нужную версию из "истории раскаток" с помощью "kubectl rollout undo ... --to-revision=1"

6. Используя maxSurge и maxUnavailable в манифесте deployment созданы два сценария развернтывания подов:
   "blue-green" - kubernetes-controllers/paymentservice-deployment-bg.yaml
   "Reverse Rolling Update" - kubernetes-controllers/paymentservice-deployment-reverse.yaml

7. Из манифеста kubernetes-controllers/frontend-replicaset.yaml создан манифест deployment kubernetes-controllers/frontend-deployment.yaml
   В манифест deployment добавлены readinessProbe и протестирована их работа.
   При "провале" readinessProbe статус пода "Running", но не"Ready" (не готов принимать трафик) и развертывание deployment "замирает"
   Для контроля состояния розвертывания можно использовать "kubectl rollout status" с ключем "--timeout=XX" и при "провале" делать откат
   "kubectl rollout undo deployment/XXXX"
   
8. Создан манифест daemonset kubernetes-controllers/node-exporter-daemonset.yaml для развертывания NodeExporter.
   Для того чтобы daemonset запустил под на мастер ноде в манифест добавлен "tolerations" на taints 
   "node-role.kubernetes.io/control-plane:NoSchedule"




# ДЗ-4 Kubernetes-volumes

1. С помощью kind установлен однонодовый кластер kubernetes

2. Развернут statefulset Minio "kubernetes-volumes/minio-statefulset.yaml"
   ( оригинал https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Kuberenetes-volumes/minio-statefulset.yaml )

3. Развернут headless service для minio "kubernetes-volumes/minio-headless-service.yaml"
   ( оригинал https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Kuberenetes-volumes/minio-headless-service.yaml )

4. Проверки работы компонентов инстанса минио:
   kubectl get statefulsets
   kubectl get pods
   kubectl get pvc
   kubectl get pv
   kubectl describe <resource> <resource_name>

5. Для более "безопасного" хранения секретов, создан secret "kubernetes-volumes/minio-secrets.yaml"
   Манифест statefulset-a "kubernetes-volumes/minio-statefulset.yaml" переконфигурирован на использование этого secret
