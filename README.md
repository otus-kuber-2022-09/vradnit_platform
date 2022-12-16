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




# ДЗ-9 Kubernetes-logging

1. Создали кластер из 4х нод
    на 3х мастерах удалили taint "node-role.kubernetes.io/master:NoSchedule"
    и установили taint "node-role=infra:NoSchedule":

        kubectl get nodes 
        NAME      STATUS   ROLES                  AGE     VERSION
        k8s-m-1   Ready    control-plane,worker   74d     v1.24.6
        k8s-m-2   Ready    control-plane,worker   74d     v1.24.6
        k8s-m-3   Ready    control-plane,worker   74d     v1.24.6
        k8s-w-1   Ready    worker                 7d19h   v1.24.6

        kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints --no-headers
        k8s-m-1   [map[effect:NoSchedule key:node-role value:infra]]
        k8s-m-2   [map[effect:NoSchedule key:node-role value:infra]]
        k8s-m-3   [map[effect:NoSchedule key:node-role value:infra]]
        k8s-w-1   <none>
   
2. В неймспейс "microservices-demo" установили тестовое приложение HipsterShop 

        kubectl create ns microservices-demo
        kubectl apply -f https://raw.githubusercontent.com/express42/otus-platform-snippets/master/Module-02/Logging/microservices-demo-without-resources.yaml \
        -n microservices-demo

   Проверяем, что компоненты приложения развернулись на одной ноде:

        kubectl get pods -n microservices-demo -o wide
        NAME                                     READY   STATUS    RESTARTS      AGE   IP              NODE      NOMINATED NODE   READINESS GATES
        adservice-856964cfb9-lm892               1/1     Running   0             23m   10.244.196.76   k8s-w-1   <none>           <none>
        cartservice-6f6b5b875d-8sq9l             1/1     Running   0             23m   10.244.196.85   k8s-w-1   <none>           <none>
        checkoutservice-b5545dc95-n8lwf          1/1     Running   0             23m   10.244.196.78   k8s-w-1   <none>           <none>
        currencyservice-f7b9cc-2jdhn             1/1     Running   0             23m   10.244.196.83   k8s-w-1   <none>           <none>
        emailservice-59954c6bff-vppt9            1/1     Running   0             23m   10.244.196.75   k8s-w-1   <none>           <none>
	frontend-75f46fcfb7-9d54k                1/1     Running   0             23m   10.244.196.77   k8s-w-1   <none>           <none>
	loadgenerator-7d88bdbbf8-ncp87           1/1     Running   5 (21m ago)   23m   10.244.196.74   k8s-w-1   <none>           <none>
	paymentservice-556f7b5695-z49r8          1/1     Running   0             23m   10.244.196.80   k8s-w-1   <none>           <none>
	productcatalogservice-78854d86ff-kk9nf   1/1     Running   0             23m   10.244.196.84   k8s-w-1   <none>           <none>
	recommendationservice-b8f974fc-lcgs5     1/1     Running   0             23m   10.244.196.81   k8s-w-1   <none>           <none>
	redis-cart-745456dd9b-xgrnn              1/1     Running   0             23m   10.244.196.82   k8s-w-1   <none>           <none>
	shippingservice-7b5695bdb5-2hp8t         1/1     Running   0             23m   10.244.196.79   k8s-w-1   <none>           <none>

3. Установка ingress-nginx, cert-manager:
   Для установки будем использовать helmfile и необходимые values файлы, с нужными tolerations, nodeaffinity, podAntiAffinity и replicas:

       kubernetes-logging/helmfile-ingress.yaml
       kubernetes-logging/ingress-nginx.values.yaml

   запускаем установку:

       helmfile -f helmfile-ingress.yaml apply   

   проверяем, что ingress-nginx запустился на "infra" нодах:

       k get pods -n ingress-nginx -o wide 
       NAME                                        READY   STATUS    RESTARTS   AGE   IP               NODE      NOMINATED NODE   READINESS GATES
       ingress-nginx-controller-7f47fdb549-ddw4p   1/1     Running   0          37h   10.244.133.189   k8s-m-1   <none>           <none>
       ingress-nginx-controller-7f47fdb549-dfpwl   1/1     Running   0          37h   10.244.61.214    k8s-m-2   <none>           <none>
       ingress-nginx-controller-7f47fdb549-sh4ln   1/1     Running   0          37h   10.244.34.58     k8s-m-3   <none>           <none>

4. Установка elasticsearch, kibana, fluent-bit:
   Для установки будем использовать helmfile и необходимые values файлы, с нужными tolerations и nodeaffinity.
   Cразу конфигурируем ingress для kibana.

        kubernetes-logging/helmfile-efk.yaml
        kubernetes-logging/elasticsearch.values.yaml
        kubernetes-logging/kibana.values.yaml
        kubernetes-logging/fluent-bit.values.yaml

   запускаем установку:

        kubectl create ns observability
        helmfile -f helmfile-efk.yaml apply

   проверяем что компоненты EFK запустились на "infra" нодах:

        kubectl get pods -o wide | grep -E '^(elasticsearch-master|fluent-bit|kibana)'
        elasticsearch-exporter-prometheus-elasticsearch-exporter-6sftkz   1/1     Running   0             46h     10.244.61.216    k8s-m-2
        elasticsearch-master-0                                            1/1     Running   0             5d16h   10.244.34.25     k8s-m-3
        elasticsearch-master-1                                            1/1     Running   0             5d16h   10.244.61.253    k8s-m-2
        elasticsearch-master-2                                            1/1     Running   0             46h     10.244.133.179   k8s-m-1
        fluent-bit-29qtr                                                  1/1     Running   0             115m    10.244.34.53     k8s-m-3
        fluent-bit-48zcl                                                  1/1     Running   0             116m    10.244.133.137   k8s-m-1
        fluent-bit-fltgw                                                  1/1     Running   0             116m    10.244.196.118   k8s-w-1
        fluent-bit-kt6z5                                                  1/1     Running   0             116m    10.244.61.200    k8s-m-2
        kibana-kibana-55c7b9b8b-bztn4                                     1/1     Running   0             3m6s    10.244.34.12     k8s-m-3

   проверяем доступность kibana:
        https://kibana.radnit.ru

5. Проверяем логи fluent-bit, видим что он использует неверное имя сервиса elasticsearh, а также т.к. elastic требует авторизацию, то 
   добавляем для fluent-bit реквизиты доступа ( через переменные окружения FLUENT_ELASTICSEARCH_USER, FLUENT_ELASTICSEARCH_PASSWD )

   
6. Решение проблем с логами из fluent-bit в elasticsearch:

6.1. Проблем с дублированием полей "time" и "timestamp" не обнаружено, вероятнее всего это "старая проблема" fluent-bit.
     Пример лога приложения со "всеми полями" приведен в:
         kubernetes-logging/example-elastic-json

     Возможная причина данной проблемы: при merge JSON лога приложений в структуру лога, fluent-bit формировал лог с дублированными полями. 
     Данная проблема пофикшена в патче:
     https://github.com/fluent/fluent-bit/commit/1d148860a8825d5f80aef40efd0d6d2812419740

     Если предположить, что данного патча нет, то проблему можно было решить lua скриптом пример которого приведен в:
     https://github.com/fluent/fluent-bit/issues/1835

6.2. В секции OUTPUT добавлена опция "Suppress_Type_Name On" т.к. у нас версия elasica 8.5.1,
     а "Types are deprecated in APIs in v7.0. This options is for v7.0 or later"

6.3. Логи от приложений из неймспесов "ingress-nginx" и "microservices-demo" выделены в отдельные индексы,
     иначе возникала каша из логов

     Все остальные логи пишутся в индекс "radnit-kube"

     При "разделении" логов на разные неймспейсы, обнаружена проблема с отсутстием метаинформации в итоговых логах от "ingress-nginx" и "microservices-demo".
     Проблема решена добавлением опций Kube_Tag_Prefix.
   
6.4. Т.к. логи приложений из "microservices-demo" используют разный формат даты в полях "time" и "data",
     elastic "иногда" возвращал ошибку:

        status":400,"error":{"type":"mapper_parsing_exception","reason":"failed to parse field [timestamp] of type [float] in document with id 

     Для решения этой проблемы, в elastic был создан "Index Templates" для индекса "microservices-demo", и в нем сконфигурирован "Mappings":
     
        { "properties": {
            "time": {"type": "date"},
            "timestamp": {"type": "date"},
            "ts": {"type": "date"}
        }}

7. Установка "prometheus-operator" и "elasticsearch-exporter":
   Для установки будем использовать helmfile и необходимые values файлы, с нужными tolerations, nodeaffinity, podAntiAffinity:

        kubernetes-logging/helmfile-kube-prometheus.yaml
        kubernetes-logging/prometheus-operator.values.yaml
        kubernetes-logging/prometheus-elasticsearch-exporter.values.yaml

   Также в values для grafana добавлено:
   создание ingress "https://grafana-k8s.radnit.ru"
   создание дашборда для "elasticsearch-exporter"
   автогенерация пароля для "admin" при рестарте ( плохой дефолный пароль, а графана доступна снаружи )

   В values для "prometheus-elasticsearch-exporter" добавлены реквизиты доступа к elasticsearch, а также создание 
   servicemonitor c "правильной" меткой "release: kube-prometheus"

   Установка:

        helmfile -l release=kube-prometheus -f helmfile-kube-prometheus.yaml apply


8. После "экспериментов" по "убиванию" кластера elasticsearch, решено добавить необходимы алертинг при:
        elasticsearch_cluster_health_number_of_nodes{} < 3
        (elasticsearch_jvm_memory_used_bytes{area="heap"} / elasticsearch_jvm_memory_max_bytes{area="heap"}) > 0.9
        elasticsearch_cluster_health_number_of_pending_tasks{} > 0

   Соответствующие rules добавлены в "kubernetes-logging/prometheus-elasticsearch-exporter.values.yaml"

   Применяем изенения:

        helmfile -l release=elasticsearch-exporter -f helmfile-kube-prometheus.yaml   

   Проверяем, что rules появились в графане.


9. Мониторинг ingress-nginx.
   Проверяем, что логов нет. Включаем сбор метрик в "kubernetes-logging/ingress-nginx.values.yaml", а также также меняем формат логов на JSON.
   
   Применяем изменения:

        helmfile -f helmfile-ingress.yaml apply

   Проверяем, доступность логов в Kibana.

   Пример логов:

        {"timestamp": "2022-12-13T20:12:27+00:00", "proxy_protocol_addr": "", "remote_addr": "192.168.0.91", "remote_user": "", "time_local": "13/Dec/2022:20:12:27 +0000", 
        "request": "GET /api/datasources/1/resources/api/v1/label/color/values?start=1670958747&end=1670962347 HTTP/2.0", "status": "200", "body_bytes_sent": "81", 
        "http_referer": "https://grafana-k8s.radnit.ru/explore?orgId=1&left=%7B%22datasource%22:%22prometheus%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22datasource%22:%7B%22type%22:%22prometheus%22,%22uid%22:%22prometheus%22%7D%7D%5D,%22range%22:%7B%22from%22:%22now-1h%22,%22to%22:%22now%22%7D%7D", 
        "http_user_agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36", 
        "request_length": "80", "request_time": "0.014", "proxy_upstream_name": "observability-kube-prometheus-grafana-80", 
        "proxy_alternative_upstream_name": "", "upstream_addr": "10.244.133.188:3000", "upstream_response_length": "81", "upstream_response_time": "0.013", 
        "upstream_status": "200", "req_id": "83dba8d5de53989604ed458e6a955187", "server_protocol":"HTTP/2.0", "host": "grafana-k8s.radnit.ru", 
        "uri": "/api/datasources/1/resources/api/v1/label/color/values", "args": "start=1670958747&end=1670962347", "x-forward-for": "192.168.0.91"}

10. На основе логов ingress-nginx в кибане создан дашборд по "status" ответа.
    Итоговый дашборд экпортирован в:

        kubernetes-logging/export.ndjson
    
    Также приложены скрины:

        kubernetes-logging/example-img/kibana-1.png
        kubernetes-logging/example-img/kibana-2.png
        kubernetes-logging/example-img/kibana-3.png

11. Установка Loki и Promtail.
    Для установки будем использовать helmfile и необходимые values файлы, с нужными tolerations и nodeaffinity.
    ( в values loki отключено автосоздание datasource Loki, т.к. это приводило к конфликту с datasource создаваемые kube-prometheus )
    ( для promtail разрешаем все tolerations, чтобы он запустился на всех нодах )

        kubernetes-logging/helmfile-loki-stack.yaml
        kubernetes-logging/loki-stack.values.yaml

    Для того, чтобы datasource Loki создавался через "prometheus-operator", внесены изменения в:

        kubernetes-logging/prometheus-operator.values.yaml

    Устанавливаем loki:

        helmfile -f helmfile-loki-stack.yaml apply
  
    Применяем изменения для kube-prometheus:
        
        helmfile -l release=kube-prometheus -f helmfile-kube-prometheus.yaml apply
    
    Проверяем, что datasource Loki появился в "https://grafana-k8s.radnit.ru"

    Проверяем, как установились компоненты Loki на нодах кластера:
        kubectl get pods -o wide | grep loki 
        loki-stack-0                                                      1/1     Running   0               2d16h   10.244.133.180   k8s-m-1   <none>           <none>
        loki-stack-promtail-6flb4                                         1/1     Running   0               2d16h   10.244.133.181   k8s-m-1   <none>           <none>
        loki-stack-promtail-pkxb7                                         1/1     Running   0               2d16h   10.244.34.63     k8s-m-3   <none>           <none>
        loki-stack-promtail-vfzvz                                         1/1     Running   0               2d16h   10.244.61.220    k8s-m-2   <none>           <none>
        loki-stack-promtail-vv24h                                         1/1     Running   0               2d16h   10.244.196.71    k8s-w-1   <none>           <none>

12.  Создание кастомного дашборда для мониторинга ingress-nginx в grafana + loki.
     Итоговый дашборд сохранен в:

         kubernetes-logging/nginx-ingress.json

     Добавляем "автосоздание" нашего дашборда в grafana через "kubernetes-logging/helmfile-kube-prometheus.yaml"
     Применяем изменения для kube-prometheus:

         helmfile -l release=kube-prometheus -f helmfile-kube-prometheus.yaml apply

     Скрины дашборда приложены в:

         kubernetes-logging/example-img/nginx-ingress-1.png
         kubernetes-logging/example-img/nginx-ingress-2.png

13.  Установка "k8s-event-logger".
     Создаем helmfile "kubernetes-logging/helmfile-k8s-event-logger.yaml"

     Установка:
         helmfile -f helmfile-k8s-event-logger.yaml apply

     Проверяем что events в виде логов видны и в kibana и в loki:
         {"metadata":{"name":"fluent-bit-m4sqs.1730fefc75a1a367","namespace":"observability","uid":"47d42734-5bd3-4bf4-9a13-683437137f7c",
          "resourceVersion":"19918249","creationTimestamp":"2022-12-15T14:50:22Z","managedFields":[{"manager":"kubelet","operation":"Update",
          "apiVersion":"v1","time":"2022-12-15T14:50:22Z","fieldsType":"FieldsV1","fieldsV1":{"f:count":{},"f:firstTimestamp":{},"f:involvedObject":{},
          "f:lastTimestamp":{},"f:message":{},"f:reason":{},"f:source":{"f:component":{},"f:host":{}},"f:type":{}}}]},"involvedObject":{"kind":"Pod",
          "namespace":"observability","name":"fluent-bit-m4sqs","uid":"5ff4c0fc-b74a-4902-94f4-b630490323d7","apiVersion":"v1","resourceVersion":"19918229",
          "fieldPath":"spec.containers{fluent-bit}"},"reason":"Started","message":"Started container fluent-bit","source":{"component":"kubelet","host":"k8s-m-3"},
          "firstTimestamp":"2022-12-15T14:50:22Z","lastTimestamp":"2022-12-15T14:50:22Z","count":1,"type":"Normal","eventTime":null,"reportingComponent":"","reportingInstance":""}

14. Audit logging.
    За "источик" манифеста "kind: Policy" для тестирования работы "audit loggin" kube-apiserver был взят кусок из скрипта:
        https://github.com/kubernetes/kubernetes/blob/master/cluster/gce/gci/configure-helper.sh

    Итоговый скрипт и пример манифеста приложены в:

        kubernetes-logging/audit/audit-policy-manifest-create.sh
        kubernetes-logging/audit/audit-policy.yaml

    Манифест скопирован на все мастер ноды в:
        /etc/kubernetes/audit-policy.yaml

    В манифесты всех kube-apiserver были добавлены параметры:

        #add to manifest kube-apiserver
        #---------------------------------------------------------
        --audit-policy-file=/etc/kubernetes/audit-policy.yaml
        --audit-log-path=-
        #---------------------------------------------------------
        volumeMounts:
        - mountPath: /etc/kubernetes/audit-policy.yaml
          name: audit
          readOnly: true
        #---------------------------------------------------------
        volumes:
        - name: audit
          hostPath:
          path: /etc/kubernetes/audit-policy.yaml
          type: File
        #---------------------------------------------------------

    Проверяем audit логи :

        {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"e52ba2da-df89-4d12-9209-acb4dac26036","stage":"ResponseComplete",
         "requestURI":"/readyz","verb":"get","user":{"username":"system:anonymous","groups":["system:unauthenticated"]},"sourceIPs":["192.168.0.91"],
         "userAgent":"kube-probe/1.24","responseStatus":{"metadata":{},"code":200},"requestReceivedTimestamp":"2022-12-15T18:24:15.908955Z",
         "stageTimestamp":"2022-12-15T18:24:15.912435Z","annotations":{"authorization.k8s.io/decision":"allow",
         "authorization.k8s.io/reason":"RBAC: allowed by ClusterRoleBinding \"system:public-info-viewer\" of ClusterRole \"system:public-info-viewer\" to Group \"system:unauthenticated\""}}

15. Централизованное хранение логов.
    Для реализации было выбрано решение на сбор всех логов генерируемых через systemd и их хранением в отдельном индексе "radnit-host" в elasticsearch: 

    В values файл fluent-bit "kubernetes-logging/fluent-bit.values.yaml" добавлено:

        [INPUT]
          Name systemd
          Tag host.*
          Read_From_Tail On
          
        [OUTPUT]
          Name es
          Match host.*
          Host elasticsearch-master
          Logstash_Format On
          Logstash_Prefix radnit-host
          Retry_Limit False
          tls On
          tls.verify Off
          HTTP_User ${FLUENT_ELASTICSEARCH_USER}
          HTTP_Passwd ${FLUENT_ELASTICSEARCH_PASSWD}
          Replace_Dots On
          Suppress_Type_Name On

    тамже добавлено монтирование директории с логами systemd:

        daemonSetVolumeMounts:
        - name: systemdlog
          mountPath: /run/log
          readOnly: true
        
        daemonSetVolumes:
        - name: systemdlog
          hostPath:
          path: /run/log


    Применяем изменения:

        helmfile -l release=fluent-bit -f helmfile-efk.yaml apply

    Пример лога приведен в:
        kubernetes-logging/fluent-bit_radnit-host_log.json




# ДЗ-10 Kubernetes-operators

1.  С помощью minikube создан однонодовый кластер k8s

2.  Создан CustomResourceDefinition "mysqls.otus.homework" в "kubernetes-operators/deploy/crd.yml",
    а также соответствующий ему CR (customResource) "kind: MySQL" в "kubernetes-operators/deploy/cr.yml"

3.  Для того, чтобы все поля "описанные" в CustomResourceDefinition были "обязательными" в схему было добавлено поле "required"
    со списком всех "обязательных" полей

4.  В директории "kubernetes-operators/build/templates/" сохранены используемые шаблоны:

        kubernetes-operators/build/templates/backup-pv.yml.j2
        kubernetes-operators/build/templates/mysql-pvc.yml.j2
        kubernetes-operators/build/templates/mysql-deployment.yml.j2
        kubernetes-operators/build/templates/mysql-pv.yml.j2
        kubernetes-operators/build/templates/mysql-service.yml.j2
        kubernetes-operators/build/templates/backup-job.yml.j2
        kubernetes-operators/build/templates/restore-job.yml.j2
        kubernetes-operators/build/templates/backup-pvc.yml.j2

5.  В результате выполнения шагов ДЗ, используя python + библиотеку kopf, был создан kubernetes-operator
    "kubernetes-operators/build/mysql-operator.py"
    Diff file (для понимания, что изменено) "kubernetes-operators/build/mysql-operator.diff"

    В кратце:
    . для обеспечения логгирование добавлен модуль "logging" ( print заменен на logging )
    . в "backup_pvc" и в "backup-pv" добавлена переменная "storage_size" ( требование шиблонов )
    . в функцию "delete_success_jobs" добавлено удаление "restore-job" ( + change-password-job )
    . в функцию "delete_object_make_backup" добавлено удаление "mysql-pv", т.к. не смотря на
      "kopf.append_owner_reference(persistent_volume, owner=body)" эта сущность не удаляется при удалении CR ( несмотря на наличие adopt )
    . изменена логика восстановления из бекапа:
    .. пропуск восстановления если бекапов нет
    .. ожидание выполения джобы

6.  Оператор собран в образ "vradnit/mysql-operator:0.6" и запушен в dockerhub
    Для сборки оператора в образ использовался Dockerfile:
    "kubernetes-operators/build/Dockerfile"

7.  Для деплоя оператора в кластер kubernetes созданы манифесты:

        kubernetes-operators/deploy/deploy-operator.yml
        kubernetes-operators/deploy/service-account.yml
        kubernetes-operators/deploy/role.yml
        kubernetes-operators/deploy/role-binding.yml

8.  Для тестирования загрузки тестовых данных написан скрипт:
    "kubernetes-operators/build/testdata.sh"
    пример использования:

        ./testdata.sh [upload|show] [password]

9.  После итераций "создание"->"удаление(+backup)"->"создание(+recovery from backup)"
    Состояние джоб:

        kubectl get jobs
        NAME                         COMPLETIONS   DURATION   AGE
        backup-mysql-instance-job    1/1           5s         2m31s
        restore-mysql-instance-job   1/1           108s       110s

    Состояние БД:

        ./testdata.sh show otuspassword
        | id | name        |
        |  1 | some data-1 |
        |  2 | some data-2 |
        |  3 | some data-3 |
        |  4 | some data-4 |

10. Для того, чтобы оператор стал "писать" в "status subresource"
    в спецификации CRD было добавлено описание поля "status"

            status:
              type: object
              x-kubernetes-preserve-unknown-fields: true

    а для вывода "статуса" выполнения "restore-job" в участок кода добавлена переменная "status_restore_job",
    в которую сохраняется "статус" выполения джобы, а функция "mysql_on_create" возвращает"
    " return {'restoreJob': str(status_restore_job)} "

    результат:

        status:
          kopf:
            progress: {}
          mysql_on_create:
            restoreJob: successful

11. Для реализации логики изменения пароля в "mysql" при его изменении в CR
    Добавлена функция "password_changed(body, old, new, **_)"
    с декоратором "@kopf.on.field('otus.homework', 'v1', 'mysqls', field='spec.password')"
    Функция срабатывает при изменении field='spec.password' в CR,
    при этом в "old" содержится "старый пароль", а в "new" новый пароль

    Для ислючения запуска джобы с пустыми значениями "old" или "new" ( допустим при первом deploе "old" пустой )
    используется -> "if old_password and new_password"

    Для запуска джобы создан темплейт манифеста "change-password-job.yml.j2", его задача выполнить команду смены пароля:
        mysql -u root -h {{ name }} -p{{ old_password }} mysql -e "ALTER USER root IDENTIFIED BY '{{ new_password }}', 'root'@'localhost' IDENTIFIED BY '{{ new_password }}'"

    Перед запуском "джобы смены пароля", предыдущая аналогичная джоба удаляется

    Пример лога оператора при изменении пароля через CR:

        [2022-12-05 18:35:26,596] kopf.objects         [INFO    ] [default/mysql-instance] Handler 'password_changed/spec.password' succeeded.
        [2022-12-05 18:35:26,597] kopf.objects         [INFO    ] [default/mysql-instance] Updating is processed: 1 succeeded; 0 failed.
        [2022-12-05 18:37:09,677] root                 [INFO    ] Job with name:[change-password-mysql-instance-job] found, wait untill end
        [2022-12-05 18:37:10,693] root                 [INFO    ] Job with name:[change-password-mysql-instance-job] found, wait untill end
        [2022-12-05 18:37:11,708] root                 [INFO    ] Job with name:[change-password-mysql-instance-job] found, wait untill end
        [2022-12-05 18:37:12,724] root                 [INFO    ] Job with name:[change-password-mysql-instance-job] found, wait untill end
        [2022-12-05 18:37:13,742] root                 [INFO    ] Job with name:[change-password-mysql-instance-job] found, wait untill end
        [2022-12-05 18:37:14,759] root                 [INFO    ] Job with name:[change-password-mysql-instance-job] found, wait untill end
        [2022-12-05 18:37:14,760] root                 [INFO    ] Job with name:[change-password-mysql-instance-job] end sucessful
        [2022-12-05 18:37:14,761] kopf.objects         [INFO    ] [default/mysql-instance] Handler 'password_changed/spec.password' succeeded.
        [2022-12-05 18:37:14,762] kopf.objects         [INFO    ] [default/mysql-instance] Updating is processed: 1 succeeded; 0 failed.

    При этом статус джоб:

        kubectl get jobs
        NAME                                 COMPLETIONS   DURATION   AGE
        backup-mysql-instance-job            1/1           5s         42m
        change-password-mysql-instance-job   1/1           5s         3m2s
        restore-mysql-instance-job           1/1           23s        42m
