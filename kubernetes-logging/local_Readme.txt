./export.ndjson
./nginx-ingress.json
./helmfile-efk.yaml
./ingress-nginx.values.yaml
./example-img
./example-img/kibana-3.png
./example-img/nginx-ingress-1.png
./example-img/nginx-ingress-2.png
./example-img/kibana-2.png
./example-img/kibana-1.png
./helmfile-kube-prometheus.yaml
./helmfile-k8s-event-logger.yaml
./loki-stack.values.yaml
./elasticsearch.values.yaml
./kibana.values.yaml
./audit
./audit/audit-policy-manifest-create.sh
./audit/audit-policy.yaml
./prometheus-elasticsearch-exporter.values.yaml
./example-elastic-json
./local_Readme.txt
./helmfile-ingress.yaml
./helmfile-loki-stack.yaml
./prometheus-operator.values.yaml
./fluent-bit.values.yaml




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
   
6.4. Т.к. логи приложений из "microservices-demo" используют разный формат даты в полях "time" и "data",
     elastic "иногда" возвращал ошибку:

        status":400,"error":{"type":"mapper_parsing_exception","reason":"failed to parse field [timestamp] of type [float] in document with id 

     Для решения этой проблемы, в elastic был создан "Index Templates" для индекса "microservices-demo", и в нем сконфигурирован "Mappings":
     
        { "properties": {
            "time": {"type": "date"},
            "timestamp": {"type": "date"},
            "ts": {"type": "date"}
        }}

   
 
