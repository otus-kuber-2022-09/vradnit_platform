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
