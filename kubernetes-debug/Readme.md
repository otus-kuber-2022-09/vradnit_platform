  Тестирование работы "strace" при "kubectl debug"

  Протестируем работу "strace" в двух режимах:
  "kubectl-debug" ( "сторонний плагин" )
  "kubectl debug" ( т.е. с "ephemeralContainers" )

  Поднимем однонодовый кластер ( cni calico будет использоваться во второй части ДЗ ) 
```console
$ minikube start --driver='virtualbox' --cni='calico' --kubernetes-version='1.24.6'

$ kubectl get nodes -o wide
NAME       STATUS   ROLES           AGE     VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE               KERNEL-VERSION   CONTAINER-RUNTIME
minikube   Ready    control-plane   3m24s   v1.24.6   192.168.59.104   <none>        Buildroot 2021.02.12   5.10.57          docker://20.10.23
```

  Для тестирования плагина "kubectl-debug" воспользуемся документацией: 
  https://github.com/aylei/kubectl-debug#install-the-kubectl-debug-plugin

  Устанавливаем "kubectl-debug"
```console
$ export PLUGIN_VERSION=0.1.1
$ curl -Lo kubectl-debug.tar.gz https://github.com/aylei/kubectl-debug/releases/download/v${PLUGIN_VERSION}/kubectl-debug_${PLUGIN_VERSION}_linux_amd64.tar.gz

$ tar -zxvf kubectl-debug.tar.gz kubectl-debug
$ sudo mv kubectl-debug /usr/local/bin/

$ kubectl-debug --version
debug version v0.0.0-master+$Format:%h$
```

  Устанавливаем "debug agent DaemonSet"
```console
$ kubectl apply -f https://raw.githubusercontent.com/aylei/kubectl-debug/master/scripts/agent_daemonset.yml
daemonset.apps/debug-agent created

$ kubectl get daemonset 
NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
debug-agent   1         1         1       1            1           <none>          4s
```

  Для тестирования "strace" запустим тестовый под с nginx:
```console
$ kubectl create -f pod-app.yaml
pod/app created

$ k get pods 
NAME                READY   STATUS    RESTARTS   AGE
app                 1/1     Running   0          23s
debug-agent-ps56p   1/1     Running   0          2m14s

$ k logs app -c app
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2023/03/05 15:45:41 [notice] 1#1: using the "epoll" event method
2023/03/05 15:45:41 [notice] 1#1: nginx/1.23.3
2023/03/05 15:45:41 [notice] 1#1: built by gcc 10.2.1 20210110 (Debian 10.2.1-6) 
2023/03/05 15:45:41 [notice] 1#1: OS: Linux 5.10.57
2023/03/05 15:45:41 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2023/03/05 15:45:41 [notice] 1#1: start worker processes
2023/03/05 15:45:41 [notice] 1#1: start worker process 28
2023/03/05 15:45:41 [notice] 1#1: start worker process 29
```

  Пробуем запустить "strace" на процессы nginx^
```console
$  kubectl-debug -n default app
container created, open tty...
app:~# 
app:~# ps
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   28 101       0:00 nginx: worker process
   29 101       0:00 nginx: worker process
   30 root      0:00 bash
   36 root      0:00 ps
app:~# 
app:~# strace -fp 28,29
strace: Process 28 attached
strace: Process 29 attached
[pid    29] epoll_wait(11,  <unfinished ...>
[pid    28] epoll_wait(9, 
```
  Как видно "strace" успешно запускается при использовании "kubectl-debug"



  Тестирование "родного" режима "kubectl debug" ( т.е. с "ephemeralContainers" )
  Воспользуемся документацией:
```console
https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/
https://iximiuz.com/en/posts/kubernetes-ephemeral-containers/
https://betterprogramming.pub/debugging-kubernetes-pods-deep-dive-d6b2814cd8ce
```

  Проверяем, что на тек. момент нет никаких "ephemeralContainers"
```console
$ kubectl get pods app -o jsonpath='{ .spec.ephemeralContainers }' | jq  
```
  Создаем "ephemeralContainers" с именем "debugger" в поде "app" и подключем его "pid namespace" контейнера "app"
```console
kubectl debug -it --attach=false -c debugger --image=nicolaka/netshoot --target=app app
```
  Проверяем что в "spec" пода появилось описание "ephemeralContainers":
```console
$ kubectl get pods app -o jsonpath='{ .spec.ephemeralContainers }' | jq
[
  {
    "image": "nicolaka/netshoot",
    "imagePullPolicy": "Always",
    "name": "debugger",
    "resources": {},
    "stdin": true,
    "targetContainerName": "app",
    "terminationMessagePath": "/dev/termination-log",
    "terminationMessagePolicy": "File",
    "tty": true
  }
]
```
  Подклюаемся к контейнеру "debugger" и пробуем запустить "strace": 
```console
$ kubectl exec -it app -c debugger -- sh
~ # 
~ # ps 
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   28 101       0:00 nginx: worker process
   29 101       0:00 nginx: worker process
   40 root      0:00 zsh
   47 root      0:00 sh
   53 root      0:00 ps
~ # 
~ # strace -fp 28,29
strace: attach: ptrace(PTRACE_SEIZE, 28): Operation not permitted
strace: attach: ptrace(PTRACE_SEIZE, 29): Operation not permitted
```
  Как видим у "ephemeralContainers" нет необходимых прав ( capabilities: SYS_PTRACE )
  К сожалению конфигурация "spec.ephemeralContainers" имутабельна, а также нет возможности через "kubectl debug" создать "ephemeralContainers" с необходимыми "capabilities"

  Но мы можем воспользоваться "kubernetes api" и создать второй "ephemeralContainers" с именем "debugger2" c "capabilities=SYS_PTRACE"
  Для этого в отдельной консоли запустим:
```console
$ kubectl proxy
Starting to serve on 127.0.0.1:8001
```
  И подготовим скрипт 
```console
# cat ./strace/create_ephemeralcontainers-debugger2.sh
#!/bin/bash

NAMESPACE="default"
POD_NAME="app"

curl  http://127.0.0.1:8001/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/ephemeralcontainers \
  -XPATCH \
  -H "Content-Type: application/strategic-merge-patch+json" \
  -d '
{
    "spec":
    {
        "ephemeralContainers":
        [
            {
                "name": "debugger2",
                "image": "nicolaka/netshoot",
                "targetContainerName": "app",
                "stdin": true,
                "tty": true,
		"securityContext": {"capabilities": {"add": ["SYS_PTRACE"]}}
            }
        ]
    }
}'
```
  Запускаем скрипт и проверяем, что появился "ephemeralContainers" с именем "debugger2" с нужными "capabilites":
```console 
$ ./strace/create_ephemeralcontainers-debugger2.sh

$ kubectl get pods app -o jsonpath='{ .spec.ephemeralContainers }' | jq
[
  {
    "image": "nicolaka/netshoot",
    "imagePullPolicy": "Always",
    "name": "debugger2",
    "resources": {},
    "securityContext": {
      "capabilities": {
        "add": [
          "SYS_PTRACE"
        ]
      }
    },
    "stdin": true,
    "targetContainerName": "app",
    "terminationMessagePath": "/dev/termination-log",
    "terminationMessagePolicy": "File",
    "tty": true
  },
  {
    "image": "nicolaka/netshoot",
    "imagePullPolicy": "Always",
    "name": "debugger",
    "resources": {},
    "stdin": true,
    "targetContainerName": "app",
    "terminationMessagePath": "/dev/termination-log",
    "terminationMessagePolicy": "File",
    "tty": true
  }
]
```
  Подключаемся с контейнеру "debugger2" и пробуем запустить "strace":
```
$ kubectl exec -it app -c debugger2 -- sh
~ # 
~ # ps
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   28 101       0:00 nginx: worker process
   29 101       0:00 nginx: worker process
   40 root      0:00 zsh
   57 root      0:00 zsh
   65 root      0:00 sh
   71 root      0:00 ps
~ # 
~ # strace -fp 28,29
strace: Process 28 attached
strace: Process 29 attached
[pid    28] epoll_wait(9,  <unfinished ...>
[pid    29] epoll_wait(11, 
```
  Успех, strace заработал.




