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

10. В кибане создан дашборд по "status" ответа.
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

12.  Создание дашборда для мониторинга ingress-nginx в grafana + loki.
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
    Для реализации было выбрано решение на сбор всех логов генерируемых через systemd и их хранением в отдельном индексе elasticsearch: 

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

    а также монтирование директории с логами systemd:

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
