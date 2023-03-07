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
```console
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



  iptables-tailer

  Установка "netperf-operator"
```console
  https://github.com/piontec/netperf-operator
```
  берем манифесты из директории "https://github.com/piontec/netperf-operator/tree/master/deploy", приводим их к акутальному виду
  ( модифицирован crd.yaml и rbac.yaml )
  Применяем манифесты и проверяем что оператор запустился:
```console
$ kubectl apply -f ./kit/netperf-operator/crd.yaml 
$ kubectl apply -f ./kit/netperf-operator/rbac.yaml
$ kubectl apply -f ./kit/netperf-operator/operator.yaml

$ kubectl get pods 
NAME                               READY   STATUS    RESTARTS      AGE
netperf-operator-d7f8d55d5-cbkxs   1/1     Running   2 (30m ago)   30m
```

  Создаем CR "Netperf" "example", применяем его и проверяем что "поды" "client" и "server" запустились:
```console
$ cat ./kit/netperf-operator/cr.yaml 
apiVersion: "app.example.com/v1alpha1"
kind: "Netperf"
metadata:
  name: "example"
spec:
  serverNode: "minikube"
  clientNode: "minikube"
 
$ kubectl create -f ./kit/netperf-operator/cr.yaml 
netperf.app.example.com/example created
 
$ kubectl get pods 
NAME                               READY   STATUS    RESTARTS      AGE
netperf-client-e11d1fb9c98a        1/1     Running   0             4s
netperf-operator-d7f8d55d5-cbkxs   1/1     Running   2 (32m ago)   33m
netperf-server-e11d1fb9c98a        1/1     Running   0             6s
```

  Через минуты 2-3 когда "поды" "client" и "server" исчезнут, можно проверить статус "Netperf" "example"
```console
$ kubectl get pods 
NAME                               READY   STATUS    RESTARTS      AGE
netperf-operator-d7f8d55d5-cbkxs   1/1     Running   2 (37m ago)   37m

$ kubectl describe netperf example
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2023-03-05T18:46:06Z
  Generation:          4
  Managed Fields:
    API Version:  app.example.com/v1alpha1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        .:
        f:clientNode:
        f:serverNode:
    Manager:      kubectl-create
    Operation:    Update
    Time:         2023-03-05T18:46:06Z
    API Version:  app.example.com/v1alpha1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:clientPod:
        f:serverPod:
        f:speedBitsPerSec:
        f:status:
    Manager:         netperf-operator
    Operation:       Update
    Time:            2023-03-05T18:46:06Z
  Resource Version:  31136
  UID:               49cef5ec-4e54-41f1-a569-e11d1fb9c98a
Spec:
  Client Node:  minikube
  Server Node:  minikube
Status:
  Client Pod:          netperf-client-e11d1fb9c98a
  Server Pod:          netperf-server-e11d1fb9c98a
  Speed Bits Per Sec:  11604.95
  Status:              Done
Events:                <none>
```
  Тестирование прошло успешно


  Создадим заведомо неисправную "сетевую политику" netperf-calico-policy
  Запустим повторно "netperf"
```console
$ kubectl create -f ./kit/networkpolicy/networkpolicy.yaml 

$ kubectl create -f ./kit/netperf-operator/cr.yaml 

$ kubectl get pod
NAME                               READY   STATUS    RESTARTS      AGE
netperf-client-696e3d2e605c        1/1     Running   1 (37s ago)   2m49s
netperf-operator-d7f8d55d5-cbkxs   1/1     Running   2 (78m ago)   78m
netperf-server-696e3d2e605c        1/1     Running   0             2m51s

$ kubectl describe netperf example
Name:         example
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  app.example.com/v1alpha1
Kind:         Netperf
Metadata:
  Creation Timestamp:  2023-03-05T19:28:28Z
  Generation:          3
  Managed Fields:
    API Version:  app.example.com/v1alpha1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        .:
        f:clientNode:
        f:serverNode:
    Manager:      kubectl-create
    Operation:    Update
    Time:         2023-03-05T19:28:28Z
    API Version:  app.example.com/v1alpha1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:clientPod:
        f:serverPod:
        f:speedBitsPerSec:
        f:status:
    Manager:         netperf-operator
    Operation:       Update
    Time:            2023-03-05T19:28:28Z
  Resource Version:  32932
  UID:               8c8edb55-17c3-4b1a-b56b-696e3d2e605c
Spec:
  Client Node:  minikube
  Server Node:  minikube
Status:
  Client Pod:          netperf-client-696e3d2e605c
  Server Pod:          netperf-server-696e3d2e605c
  Speed Bits Per Sec:  0
  Status:              Started test
Events:                <none>
```
  Как видим "тест замер" на состоянии "Started test"
  
  Если подключиться на ноду миникуба по ssh, то можно увидеть ненулевые счетчики пакетов:
```console
iptables --list -nv | grep DROP - счетчики дропов ненулевые
iptables --list -nv | grep LOG - счетчики с действием логирования
```
  А если посмотреть лог systemd, то можно увидеть лог:
```console
journalctl -k | grep calico

Mar 05 19:36:57 minikube kernel: calico-packet: IN=calibc61a543ed4 OUT=cali58b23bc12af MAC=ee:ee:ee:ee:ee:ee:e2:be:7f:6b:6e:b2:08:00 SRC=10.244.120.96 DST=10.244.120.95 LEN=60 TOS=0x00 PREC=0x00 TTL=63 ID=45588 DF PROTO=TCP SPT=40287 DPT=12865 WINDOW=64800 RES=0x00 SYN URGP=0
```
  Т.е. блокируются пакеты от "netperf-client-696e3d2e605c" к "netperf-server-696e3d2e605c"
```console
$ kubectl get pods -A -o wide | grep 10.244.120.96
default       netperf-client-696e3d2e605c                1/1     Running   4 (2m3s ago)   11m   10.244.120.96    minikube   <none>           <none>
$ kubectl get pods -A -o wide | grep 10.244.120.95
default       netperf-server-696e3d2e605c                1/1     Running   0              11m   10.244.120.95    minikube   <none>           <none>
```


  Для удобства диагностики сетевых политик, без доступа по SSH на ноды кластера, лучше использовать "iptables-tailer"
  
  Установим его.

  После установки "iptables-tailer", из предоставленного в ДЗ манифеста:
```console
https://github.com/express42/otus-platform-snippets/tree/master/Module-03/Debugging/iptables-tailer.yaml
```
  в логе пода фикировались ошибки:
```console
E0307 18:11:52.254054       1 poster.go:71] Error retrying packet drop handling, backing off: packetDrop={LogTime:2023-03-07T18:11:05.907741+00:00 HostName:minikube SrcIP:10.244.120.75 DstIP:10.244.120.74}, retryIn=selfLink was empty, can't make reference secs, error=25.286467276
E0307 18:12:17.541155       1 poster.go:71] Error retrying packet drop handling, backing off: packetDrop={LogTime:2023-03-07T18:11:05.907741+00:00 HostName:minikube SrcIP:10.244.120.75 DstIP:10.244.120.74}, retryIn=selfLink was empty, can't make reference secs, error=22.091941049
```
  а в "events" kubernetes кластера и в подах "netperf" ожидаемых "событий" не появлялось.

  На github был найден проект "honestica" c "hеlm чартом" и докер образом "honestica/kube-iptables-tailer:master-91" 
```console
  https://github.com/honestica/lifen-charts/tree/master/kube-iptables-tailer
```

  Воспользовавшись найденным хельчмартом был доработан манифест "kube-iptables-tailer":
```console
# cat ./kit/iptables-tailer/iptables-tailer.yaml 
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-iptables-tailer
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kube-iptables-tailer
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["patch","create"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kube-iptables-tailer
subjects:
  - kind: ServiceAccount
    name: kube-iptables-tailer
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: kube-iptables-tailer
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: "apps/v1"
kind: "DaemonSet"
metadata:
  name: "kube-iptables-tailer"
  namespace: "kube-system"
spec:
  selector:
    matchLabels:
      app: "kube-iptables-tailer"
  template:
    metadata:
      labels:
        app: "kube-iptables-tailer"
    spec:
      serviceAccountName: kube-iptables-tailer
      containers:
        - name: "kube-iptables-tailer"
          command:
            - "/kube-iptables-tailer"
          env:
            - name: "JOURNAL_DIRECTORY"
              value: "/run/log/journal"
            - name: "POD_IDENTIFIER"
              value: "name"
            - name: "IPTABLES_LOG_PREFIX"
              value: "calico-packet:"
            - name: "LOG_LEVEL"
              value: "info"
          image: "honestica/kube-iptables-tailer:master-91"
          imagePullPolicy: Always
          volumeMounts:
            - name: "iptables-logs"
              mountPath: "/run/log"
              readOnly: true
      volumes:
        - name: "iptables-logs"
          hostPath:
            path: "/run/log"
```

  Применяем его:
```console
$ kubectl apply -f ./kit/iptables-tailer/iptables-tailer.yaml
```
  Смотрим его "describe":
```console
$ kubectl describe pods -n kube-system kube-iptables-tailer-4rl6j
Name:         kube-iptables-tailer-4rl6j
Namespace:    kube-system
Priority:     0
Node:         minikube/192.168.59.107
Start Time:   Tue, 07 Mar 2023 10:03:48 +0300
Labels:       app=kube-iptables-tailer
              controller-revision-hash=879558bcc
              pod-template-generation=1
Annotations:  cni.projectcalico.org/containerID: b2385f758475767f91624c7b83f2106fef207ee97fac3954bd2fa80baf241f23
              cni.projectcalico.org/podIP: 10.244.120.68/32
              cni.projectcalico.org/podIPs: 10.244.120.68/32
Status:       Running
IP:           10.244.120.68
IPs:
  IP:           10.244.120.68
Controlled By:  DaemonSet/kube-iptables-tailer
Containers:
  kube-iptables-tailer:
    Container ID:  docker://4bc7455a1c2896a7d0557756f31d67e38bc602c49c32ba144de4a2dae8707023
    Image:         honestica/kube-iptables-tailer:master-91
    Image ID:      docker-pullable://honestica/kube-iptables-tailer@sha256:a393242fb9399270af81e7981b5a099f2cf704f994547be2d233f8f162d194aa
    Port:          <none>
    Host Port:     <none>
    Command:
      /kube-iptables-tailer
    State:          Running
      Started:      Tue, 07 Mar 2023 10:04:12 +0300
    Ready:          True
    Restart Count:  0
    Environment:
      JOURNAL_DIRECTORY:    /run/log/journal
      POD_IDENTIFIER:       name
      IPTABLES_LOG_PREFIX:  calico-packet:
      LOG_LEVEL:            info
    Mounts:
      /run/log from iptables-logs (ro)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-xjw74 (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  iptables-logs:
    Type:          HostPath (bare host directory volume)
    Path:          /run/log
    HostPathType:  
  kube-api-access-xjw74:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/disk-pressure:NoSchedule op=Exists
                             node.kubernetes.io/memory-pressure:NoSchedule op=Exists
                             node.kubernetes.io/not-ready:NoExecute op=Exists
                             node.kubernetes.io/pid-pressure:NoSchedule op=Exists
                             node.kubernetes.io/unreachable:NoExecute op=Exists
                             node.kubernetes.io/unschedulable:NoSchedule op=Exists
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  13m   default-scheduler  Successfully assigned kube-system/kube-iptables-tailer-4rl6j to minikube
  Normal  Pulling    13m   kubelet            Pulling image "honestica/kube-iptables-tailer:master-91"
  Normal  Pulled     13m   kubelet            Successfully pulled image "honestica/kube-iptables-tailer:master-91" in 22.169248192s
  Normal  Created    13m   kubelet            Created container kube-iptables-tailer
  Normal  Started    13m   kubelet            Started container kube-iptables-tailer
```

  Запускаем повторно тест "netperf":
```console
kubectl delete -f ./kit/netperf-operator/cr.yaml
kubectl apply -f ./kit/netperf-operator/cr.yaml 
kubectl describe pod --selector=app=netperf-operator 
```

  Но events "сразу" не появились, т.к. из-за:
```console
https://github.com/box/kube-iptables-tailer/issues/28
```
  потребовалось вернуть "старое поведение systemd-journald", т.к. в миникубе версия systemd:
```console
$ systemctl --version
systemd 247 (247)
-PAM -AUDIT -SELINUX -IMA -APPARMOR -SMACK -SYSVINIT -UTMP -LIBCRYPTSETUP -GCRYPT -GNUTLS +ACL +XZ +LZ4 -ZSTD +SECCOMP +BLKID -ELFUTILS +KMOD -IDN2 -IDN -PCRE2 default-hierarchy=hybrid
```
  возвращаем "старое поведение journald"
```console
minikube ssh -n minikube

# mkdir /etc/systemd/system/systemd-journald.service.d/

# cat /etc/systemd/system/systemd-journald.service.d/override.conf
[Service]
Environment="SYSTEMD_JOURNAL_KEYED_HASH=0"

# systemctl daemon-reload
# systemctl restart systemd-journald.service
# systemctl status systemd-journald.service
# journalctl --rotate
```

  Проверяем наличие "events"^
```console
$ kubectl get pods -n default -o wide
NAME                               READY   STATUS    RESTARTS      AGE     IP              NODE       NOMINATED NODE   READINESS GATES
netperf-client-60872fee42c5        1/1     Running   2 (52s ago)   5m19s   10.244.120.70   minikube   <none>           <none>
netperf-operator-d7f8d55d5-zs9hr   1/1     Running   0             9m58s   10.244.120.67   minikube   <none>           <none>
netperf-server-60872fee42c5        1/1     Running   0             5m25s   10.244.120.69   minikube   <none>           <none>
```
  Евенты кубернетес кластера:
```console
$ kubectl get events -n default | grep drop
2m12s       Warning   PacketDrop                pod/netperf-client-60872fee42c5         Packet dropped when sending traffic to netperf-server-60872fee42c5 (10.244.120.69) on port 12865/TCP
4m23s       Warning   PacketDrop                pod/netperf-server-60872fee42c5         Packet dropped when receiving traffic from 10.244.120.70 on port 12865/TCP
2m12s       Warning   PacketDrop                pod/netperf-server-60872fee42c5         Packet dropped when receiving traffic from netperf-client-60872fee42c5 (10.244.120.70) on port 12865/TCP
```
  Просмотр евентов в подах "netperf"
```console
$ kubectl describe pod --selector=app=netperf-operator 
Name:         netperf-client-60872fee42c5
Namespace:    default
Priority:     0
Node:         minikube/192.168.59.107
Start Time:   Tue, 07 Mar 2023 10:07:54 +0300
Labels:       app=netperf-operator
              netperf-type=client
Annotations:  cni.projectcalico.org/containerID: f2b3cc91750ca806a2b6c95523159883e5e353af88c87fbddf7b3a589e6c9073
              cni.projectcalico.org/podIP: 10.244.120.70/32
              cni.projectcalico.org/podIPs: 10.244.120.70/32
Status:       Running
IP:           10.244.120.70
IPs:
  IP:           10.244.120.70
Controlled By:  Netperf/example
Containers:
  netperf-client-60872fee42c5:
    Container ID:  docker://01eb2ff6814a72fcbf8b8553766855af1db5fb09a177f45b25a7fa0bb63ed5d1
    Image:         tailoredcloud/netperf:v2.7
    Image ID:      docker-pullable://tailoredcloud/netperf@sha256:0361f1254cfea87ff17fc1bd8eda95f939f99429856f766db3340c8cdfed1cf1
    Port:          <none>
    Host Port:     <none>
    Command:
      netperf
      -H
      10.244.120.69
    State:          Running
      Started:      Tue, 07 Mar 2023 10:10:11 +0300
    Last State:     Terminated
      Reason:       Error
      Exit Code:    255
      Started:      Tue, 07 Mar 2023 10:07:56 +0300
      Finished:     Tue, 07 Mar 2023 10:10:10 +0300
    Ready:          True
    Restart Count:  1
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-6ffst (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  kube-api-access-6ffst:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason      Age                  From                  Message
  ----     ------      ----                 ----                  -------
  Normal   Scheduled   2m58s                default-scheduler     Successfully assigned default/netperf-client-60872fee42c5 to minikube
  Normal   Pulled      41s (x2 over 2m56s)  kubelet               Container image "tailoredcloud/netperf:v2.7" already present on machine
  Normal   Created     41s (x2 over 2m56s)  kubelet               Created container netperf-client-60872fee42c5
  Normal   Started     41s (x2 over 2m56s)  kubelet               Started container netperf-client-60872fee42c5
  Warning  PacketDrop  41s                  kube-iptables-tailer  Packet dropped when sending traffic to netperf-server-60872fee42c5 (10.244.120.69) on port 12865/TCP


Name:         netperf-server-60872fee42c5
Namespace:    default
Priority:     0
Node:         minikube/192.168.59.107
Start Time:   Tue, 07 Mar 2023 10:07:48 +0300
Labels:       app=netperf-operator
              netperf-type=server
Annotations:  cni.projectcalico.org/containerID: e9ce05f40d3c910e54be3cc5e32201c1161814d8822360db10fe51f044fdce9e
              cni.projectcalico.org/podIP: 10.244.120.69/32
              cni.projectcalico.org/podIPs: 10.244.120.69/32
Status:       Running
IP:           10.244.120.69
IPs:
  IP:           10.244.120.69
Controlled By:  Netperf/example
Containers:
  netperf-server-60872fee42c5:
    Container ID:   docker://4f59def1482c39b214d2a7f963c0971befdf106a31de86cd05fb4622d5f8537e
    Image:          tailoredcloud/netperf:v2.7
    Image ID:       docker-pullable://tailoredcloud/netperf@sha256:0361f1254cfea87ff17fc1bd8eda95f939f99429856f766db3340c8cdfed1cf1
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Tue, 07 Mar 2023 10:07:54 +0300
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-b6jpt (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  kube-api-access-b6jpt:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason      Age    From                  Message
  ----     ------      ----   ----                  -------
  Normal   Scheduled   3m4s   default-scheduler     Successfully assigned default/netperf-server-60872fee42c5 to minikube
  Normal   Pulling     3m3s   kubelet               Pulling image "tailoredcloud/netperf:v2.7"
  Normal   Pulled      2m58s  kubelet               Successfully pulled image "tailoredcloud/netperf:v2.7" in 4.753461594s
  Normal   Created     2m58s  kubelet               Created container netperf-server-60872fee42c5
  Normal   Started     2m58s  kubelet               Started container netperf-server-60872fee42c5
  Warning  PacketDrop  2m52s  kube-iptables-tailer  Packet dropped when receiving traffic from 10.244.120.70 on port 12865/TCP
  Warning  PacketDrop  41s    kube-iptables-tailer  Packet dropped when receiving traffic from netperf-client-60872fee42c5 (10.244.120.70) on port 12865/TCP
```


  В качестве дополнительного задания, требовалось:

  Добавить "имя пода" в events, для этого, в манифесте демонсета, изменена переменная окружения "POD_IDENTIFIER"
```console
  - name: "POD_IDENTIFIER"
    value: "name"
```

  Также требовалось исправить "netwokpolicy", 
  для этого исправлен 'selector: netperf-type == "client"', а также добавлена разрешающая политика для 'selector: netperf-type == "server"'
  Итоговая "networkpolicy":
```console
# cat ./kit/networkpolicy/networkpolicy-ok.yaml 
apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  name: netperf-calico-policy
  labels:
spec:
  order: 10
  selector: app == "netperf-operator"
  ingress:
  - action: Allow
    source:
      selector: netperf-type == "client"
  - action: Allow
    source:
      selector: netperf-type == "server"
  - action: Log
  - action: Deny
  egress:
  - action: Allow
    destination:
      selector: netperf-type == "client"
  - action: Allow
    destination:
      selector: netperf-type == "server"
  - action: Log
  - action: Deny
```

