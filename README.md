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




# ДЗ-3 kubernetes-networks

1. С помощью minikube развернут однонодовый кластер kubernetes.

2. В манифест пода "kubernetes-intro/web-pod.yaml" добавлены проверки состояния liveness и readiness.
   (проверка readiness заведомо неверная)

3. Вопрос для самопроверки по liveness пробе 'ps aux | grep <process web >'
   . в данном случае, указанная конфигурация не имеет смысла т.к. 
   .. процесс httpd имеет pid=1 и если он упадет то kubelet перезапустит контейнер.
   .. наличие процесса в контейнере не означает что процесс "нормально" работает
   .. нужно учесть что 'ps aux | grep <process web >' всегда успешно завершается, т.к. "греп отгрепывает сам себя"
      ( как вариант использовать regex )
   . но данная проверка может применятся в случае, если "основной процесс контейнера" с помощью "дочерних процессов" выполняет какую-то работу с внешними системами,
     и "отсутсвие" таких "дочерних процессов" означает что "основной процесс завис и требует перезапуска"

3. На основе манифеста пода создан манифест deployment-а "kubernetes-networks/web-deploy.yaml"
   По результатам анализа 'kubectl describe deployment XXX' исправлена "ошибка" в liveness пробе.

4. Протестированы различные режимы обновления deployment-а ( strategy "RollingUpdate" )
   maxUnavailable, maxSurge = (0,0 <ошибка) (100%,0) (0,100%) (100%,100%)

5. Создан сервис "kubernetes-networks/web-svc-cip.yaml"
   С ноды кластера minikube протестирована работа этого сервиса "curl http://<CLUSTER-IP>/index.html"
   Просмотрены "цепочки" iptables созданные kube-proxy для этого сервиса.

6. Процесс kube-proxy в minikube переведен в режим "ipvs"
   Проанализировано изменения в работе iptables.
   Просмотрены "цепочки" в ipset и "правила" в ipvsadm

7. Установлен и сконфигурирован сервис MetalLB ( конфигмап "kubernetes-networks/metallb-config.yaml" )

8. На основе манифеста web-svc-cip.yaml создан манифест "kubernetes-networks/web-svc-lb.yaml" типа LoadBalancer
   Настройка необходимого роутинга и проверка доступности сервиса "из вне" кластера minikube

9. Создан манифест типа LoadBalancer (extip 172.17.255.10) "coredns/coredns-svc-lb.yaml" для доступа к внутреннему CoreDns minikube.
   Проверка работы сервиса "nslookup web-svc-lb.default.svc.cluster.local 172.17.255.10"

10. Установлен ingress-nginx контроллер.
    Для доступа "снаружи кластера" сконфигурирован LB сервис "kubernetes-networks/nginx-lb.yaml"

11. Для доступа к приложению deployment/web сконфигурированы:
    сервис "kubernetes-networks/web-svc-headless.yaml" ( типа ClusterIP )
    и ingress "kubernetes-networks/web-ingress.yaml"

    Проверка доступности приложения: "curl http://<LB_IP>/web/index.html"

12. Установлен kubernetes-dashboard из "https://github.com/kubernetes/dashboard"
    Для доступа к kubernetes-dashboard через ingress-nginx cоздан и протестирован манифест "kubernetes-networks/dashboard/dashboard-ingress.yaml"

13. По документации "https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md#canary" созданы
    манифесты для канареечного развертывания:
    "kubernetes-networks/canary/canary-web-deploy.yaml"
    "kubernetes-networks/canary/canary-web-ingress.yaml"
    "kubernetes-networks/canary/canary-web-svc.yaml"




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



# ДЗ-5 Kubernetes-security

1. С помощью kind установлен однонодовый кластер kubernetes.

2. task01:
   . создан serviceaccount bob и ему выдана роль admin на весь кластер
     task01/01-serviceaccount-bob.yaml
     task01/02-clusterrolebinding-admin-bob.yaml
     
   . создан serviceaccount dave без доступа к кластеру
     task01/03-serviceaccount-dave.yaml

   . проверка:
     kubectl auth can-i --list --as=system:serviceaccount:default:bob --namespace=xxx
     kubectl auth can-i --list --as=system:serviceaccount:default:dave --namespace=default

3. task02:
   . создан неймспейс "prometheus" и в нем создан ServiceAccount "carol"
     task02/01-namespace-prometheus.yaml
     task02/02-serviceaccount-carol.yaml

   . Всем ServiceAccount в неймспейсе "prometheus" выданы права на "get/list/watch" в отношении "Pod" для всего кластера
     task02/03-clusterrole-for-ns-prometheus.yaml
     task02/04-clusterrolebinding-for-ns-prometheus.yaml

   . проверка:
     kubectl auth can-i --list --as=system:serviceaccount:prometheus:xxx --namespace=kube-system
     kubectl auth can-i --list --as=system:serviceaccount:xxx:xxx --namespace=kube-system

4. task03:
   . создан неймспейс "dev", в нем ServiceAccount "jane" с ролью "admin" в рамках этого неймспейса
     task03/01-namespace-dev.yaml
     task03/02-serviceaccount-jane.yaml
     task03/03-clusterrolebinding-jane.yaml

   . в неймспейсе "dev" создан ServiceAccount "ken" с ролью "view" в рамках этого неймспейса
     task03/04-serviceaccount-ken.yaml
     task03/05-clusterrolebinding-ken.yaml
   
   . проверка: 
     kubectl auth can-i --list --as=system:serviceaccount:dev:jane --namespace=dev
     kubectl auth can-i --list --as=system:serviceaccount:dev:jane --namespace=kube-system

     kubectl auth can-i --list --as=system:serviceaccount:dev:ken --namespace=dev
     kubectl auth can-i --list --as=system:serviceaccount:dev:ken --namespace=kube-system




# ДЗ-7 Kubernetes-templating

1. В собственной инфраструктуре, с помощью kubeadm, развернут кластер k8s.
   На локальный компьютер установлен helm3 (v3.10.1)

2. Установка ingress-nginx
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --version=4.3.0 --namespace=ingress-nginx --create-namespace --wait

3. Установка cert-manager
   helm repo add jetstack https://charts.jetstack.io
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.0/cert-manager.crds.yaml
   helm upgrade --install cert-manager jetstack/cert-manager --namespace=cert-manager --version=v1.10.0 --create-namespace --wait

   Для работы certmanager требуется создать ресурсы ClusterIssue:
   kubectl create -f kubernetes-templating/cert-manager/clusterissuer-letsencrypt-production.yaml
   kubectl create -f kubernetes-templating/cert-manager/clusterissuer-letsencrypt-staging.yaml

4. Установка chartmuseum
   Создан kubernetes-templating/chartmuseum/values.yaml с кастомными параметрами
   helm upgrade chartmuseum -n chartmuseum chartmuseum/chartmuseum -f ./chartmuseum/values.yaml --version=3.9.1 --set=env.secret.BASIC_AUTH_USER=admin --set env.secret.BASIC_AUTH_PASS='XXXXXX'

   Просмотр с какими параметрами был установлен chart:
   helm status chartmuseum -n chartmuseum -o json | jq .config

   Для загрузки chart в chartmuseum.radnit.ru установим плагин для helm:
   helm plugin install https://github.com/chartmuseum/helm-push

   Добавим repo для локального использования:
   helm repo add templating https://chartmuseum.radnit.ru

   Загрузка chart в repo:
   helm cm-push -u admin -p 'XXXXXX' ./frontend https://chartmuseum.radnit.ru
   helm repo update templating/

   Удаление chart из repo:
   curl -XDELETE 'https://admin:XXXXXX@chartmuseum.radnit.ru/api/charts/frontend/0.1.0'
   helm repo update templating/

   Проверка:
   curl -D - https://chartmuseum.radnit.ru

5. Установка harbor
   helm add harbor https://helm.goharbor.io

   Создан kubernetes-templating/harbor/values.yaml с кастомными параметрами
   helm upgrade --install harbor harbor/harbor -f harbor/values.yaml --version=1.10.1 --namespace=harbor --create-namespace --wait

   Просмотр с какими параметрами был установлен chart harbor:
   helm status harbor -n harbor -o json | jq ' .config '

   Проверка:
   curl -D - https://harbor.radnit.ru

6. Helmfile.
   Вариант с использованием helmfile, для установки ingress-nginx, cert-manager и harbor:
   Создан манифест kubernetes-templating/helmfile/helmfile.yaml с описанием общей конфигурации
   Создан "chart" kubernetes-templating/helmfile/charts/cert-manager-clusterissuers
   для установки ресурсов ClusterIssue для cert-manager

   установка через helmfile
   cd kubernetes-templating/helmfile && helmfile lint && helmfile apply

   helmfile status

7. Создаем helm chart "hipster-shop":
   Используя https://github.com/express42/otus-platform-snippets/blob/master/Module-04/05-Templating/manifests/all-hipster-shop.yaml
   в директории kubernetes-templating/hipster-shop создан helm chart "hipster-shop"

   Устанавливаем его:
   helm upgrade --install hipster-shop kubernetes-templating/hipster-shop -n hipster-shop --create-namespace

   Проверка:
   curl -D - https://shop.radnit.ru

8. Создаем helm chart "frontend":
   В директории kubernetes-templating/frontend создаем helm chart "frontend"
   Используем для него манифесты deployment, service и ingress микросервиса "frontend" из chart-а "hipster-shop"
   ( и соотвественно удаляем вынесенные манифесты из chart-а "hipster-shop" )
   Выносим "нужные" параметры конфигурации микросервиса frontnend в kubernetes-templating/frontend/values.yaml

   Устанавливаем chart:
   helm upgrade --install frontend kubernetes-templating/frontend --namespace hipster-shop

9. Конфигурирум chart "frontend" как subchart chart-a "hipster-shop"
   Предварительно удаляем chart "frontend"
   helm delete frontend -n hipster-shop

   В файл  kubernetes-templating/hipster-shop/Chart.yaml в dependencies вносим chart "frontend"
   и обновляем chart "hipster-shop"
   helm dep update kubernetes-templating/hipster-shop

   Проверяем что в kubernetes-templating/hipster-shop/charts появился subchart "frontend"

   Обновляем release "hipster-shop":
   helm upgrade --install hipster-shop kubernetes-templating/hipster-shop -n hipster-shop

10. Микросервис "redis" вынесен из chart "hipster-shop", и добавлен как subchart
    Для этого использован redis от https://charts.bitnami.com/bitnami

    Необходимая конфигурация внесена в:
    kubernetes-templating/hipster-shop/Chart.yaml
    kubernetes-templating/hipster-shop/values.yaml

    и изменен микросервис cartservice ( в связи с изменением имен )

    helm dep update kubernetes-templating/hipster-shop
    helm upgrade --install hipster-shop kubernetes-templating/hipster-shop -n hipster-shop

11. Sops + helm-secret
    Создан зашифрованный файл с секретом: kubernetes-templating/frontend/secrets.yaml
    Создан темплейт для формирования манифеста с секретом: kubernetes-templating/frontend/templates/secret.yaml

    проверка, что файл расшифровывается:
    sops -d kubernetes-templating/frontend/secrets.yaml

    Установка chart-a с зашифрованным секретом:
    helm secrets upgrade --install frontend kubernetes-templating/frontend -n hipster-shop \
    -f kubernetes-templating/frontend/values.yaml \
    -f kubernetes-templating/frontend/secrets.yaml

12. На мой взгляд, для того, чтобы "исключить" попадания файлов с секретами в во внешний git repo,
    необходимо исключить push для всех в основные ветки, и использовать для только merge-requests.
    При появлении в repo новых веток, а также при каждом merge-requests необходимо в CI обеспечить запуск линтеров и сканеров безопасности.
    При появлении "чувствительных данных" необходимо или блокировать доступ к новой-ветке, или удалять ее, или вырезать commit c "чувствительными даннными"

13. Создан файл:
    kubernetes-templating/repo.sh

    для установки чартов:
     templating/frontend
     templating/hipster-shop

14. Kubecfg.
    Установлен kubecfg из https://github.com/kubecfg/kubecfg/releases/tag/v0.28.0

    Используя файлы манифестов paymentservice и shippingservice из chart "hipster-shop"
    , а также внешнюю библиотеку: https://raw.githubusercontent.com/bitnami-labs/kube-libsonnet/master/kube.libsonnet
    сформированы файлы:
      kubernetes-templating/kubecfg/common.libsonnet
      kubernetes-templating/kubecfg/services.jsonnet

    ( манифесты paymentservice и shippingservice из chart "hipster-shop" удалены )

    Проверка:
    kubecfg show kubernetes-templating/kubecfg/services.jsonnet

    Установка:
    kubecfg update kubernetes-templating/kubecfg/services.jsonnet

15. Qbec
    Установлен qbec из https://github.com/splunk/qbec/releases/tag/v0.15.2

    На основе манифестов микросервиса recommendationservice из chart "hipster-shop" в
    kubernetes-templating/jsonnet/recommendationservice-qbec/
    создана шаблонизация на основе qbec
    ( манифесты recommendationservice из chart "hipster-shop" удалены )

    cd kubernetes-templating/jsonnet/recommendationservice-qbec

    Проверка и просмотр манифестов:
    qbec env list
    qbec show prod
    qbec show stage

    Установка для окружения "prod":
    qbec apply prod

16. Kustomize
    На основе манифестов микросервиса productcatalogservice из chart "hipster-shop" в
    kubernetes-templating/kustomize
    создана шаблонизация на основе kustomize
    ( манифесты productcatalogservice из chart "hipster-shop" удалены )

    Просмотр:
    kubectl kustomize kubernetes-templating/kustomize/overrides/hipster-shop
    kubectl kustomize kubernetes-templating/kustomize/overrides/hipster-shop-prod

    установка для окружения "hipster-shop":
    kubectl kustomize kubernetes-templating/kustomize/overrides/hipster-shop | kubectl apply -f -




# ДЗ-8 Kubernetes-monitoring

1.  Используя образы "nginxinc/nginx-unprivileged:1.22-alpine" и
    "nginx/nginx-prometheus-exporter:0.11.0" созданы манифесты:

        kubernetes-monitoring/configmap.yaml
        kubernetes-monitoring/deployment.yaml
        kubernetes-monitoring/service.yaml

    ( для кастомизации кофигурации nginx используется configMap )

2.  С помощью helm устанавливаем "kube-prometheus-stack":

        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm install --upgrade kube-prometheus -n monitoring prometheus-community/kube-prometheus-stack

    Для того, чтобы найти какую метку использовать для servicemonitor выполняем:

        kubectl get prometheus -n monitoring kube-prometheus-kube-prome-prometheus -o jsonpath='{ .spec.serviceMonitorSelector }'
        {"matchLabels":{"release":"kube-prometheus"}}

3.  Создаем манифест servicemonitor:

        kubernetes-monitoring/servicemonitor.yaml

4.  Для визуализации метрик использовался стандартный dashboard:

        https://raw.githubusercontent.com/nginxinc/nginx-prometheus-exporter/main/grafana/dashboard.json

    Скрин дашборда сохранен в:

        kubernetes-monitoring/grafana/nginx.png

