

1. Создали кластер из 4х нод
    на 3х мастерах удалили taint "node-role.kubernetes.io/master:NoSchedule"
    и установили taint "node-role=infra:NoSchedule"
   
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

3. Установка elasticsearch, kibana, fluent-bit:
        helm repo add elastic https://helm.elastic.co
        helm repo add fluent https://fluent.github.io/helm-charts

        kubectl create ns observability

        helm upgrade --install elasticsearch elastic/elasticsearch --namespace observability
        helm upgrade --install kibana elastic/kibana --namespace observability
        helm upgrade --install  fluent-bit fluent/fluent-bit --namespace observability



#elasticsearch	observability	1       	2022-12-07 20:28:58.115388034 +0300 MSK	deployed	elasticsearch-8.5.1	8.5.1      
#fluent-bit   	observability	3       	2022-12-08 08:55:02.328985658 +0300 MSK	deployed	fluent-bit-0.21.5  	2.0.6      
#kibana       	observability	5       	2022-12-07 21:17:27.923070543 +0300 MSK	deployed	kibana-8.5.1       	8.5.1 
