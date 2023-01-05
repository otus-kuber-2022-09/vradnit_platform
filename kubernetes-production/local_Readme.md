1. Kubeadm.

   Подготовка машин
   
   Кластер будем поднимать в vagrant.
   Для автоматизации преднастроек виртуальных машин будем использовать "provision shell script" в Vagrantfile.

   Запускаем создание виртуальных машин и проверяем их статус:
```console
# cd kubernetes-production/ubuntu-kubeadm

# vagrant up
 
# vagrant status
Current machine states:

master-1                  running (virtualbox)
worker-1                  running (virtualbox)
worker-2                  running (virtualbox)
worker-3                  running (virtualbox)
```
   
   Опишем шаги, выполненные в провиженинге Vagrantfile:

   Отключаем swap ( + комментируем swap в /etc/fstab )
```console
# swapoff -a
# sed -i '/ swap / s/^/#/' /etc/fstab
```

   Загружаем модули
```console
# cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
# modprobe overlay
# modprobe br_netfilter
```

   Включаем маршрутизацию:
```console
# cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
# sysctl -p /etc/sysctl.d/99-kubernetes-cri.conf
```

   Устанавливаем docker:
```console
# apt-get update && apt-get install -y \
apt-transport-https ca-certificates curl software-properties-common gnupg2

#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"

# apt-get update && apt-get install -y \
containerd.io=1.2.13-1 \
docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)

# cat > /etc/docker/daemon.json <<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
"max-size": "100m"
},
"storage-driver": "overlay2"
}
EOF
# mkdir -p /etc/systemd/system/docker.service.d
# systemctl daemon-reload
# systemctl restart docker
```

   Устанавливаем kubeadm, kubelet и kubectl
```console
# apt-get update && apt-get install -y apt-transport-https curl

# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

# cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# apt-get update
# apt-get install -y kubelet=1.17.4-00 kubeadm=1.17.4-00 kubectl=1.17.4-00
```

   Следующие шаги выполняем с мастер ноды:

   Создаем кластер:
```console
# kubeadm init --pod-network-cidr=10.244.0.0/24 --apiserver-advertise-address=192.168.56.101

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.56.101:6443 --token 0mtcsw.7p8b4hxiowxlvqte \
    --discovery-token-ca-cert-hash sha256:eba1ddfe31b6af7ba2b9ce39e4455f1e06cc9559e9a94b08be208fee80397dd5
```

   Копируем конфиг kubectl:
```console
# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
   
   Проверяем доступность мастер ноды:
```console
# kubectl get nodes -o wide 
NAME       STATUS     ROLES    AGE    VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
master-1   NotReady   master   3m5s   v1.17.4   10.0.2.15     <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
```

   Устанавливаем сетевой плагин
   Документация:
   - https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
   - https://projectcalico.docs.tigera.io/archive/v3.17/getting-started/kubernetes/quickstart
     ( т.к. у нас версия k8s 1.17, то необходимо использовать совместимую версию calico v3.17 )
```console
# kubectl create -f https://docs.projectcalico.org/archive/v3.17/manifests/tigera-operator.yaml
# kubectl create -f https://docs.projectcalico.org/archive/v3.17/manifests/custom-resources.yaml
```
   через "kubectl edit Installation default" меняем "cidr" на "cidr": "10.244.0.0/24"

   Проверяем статус ноды и подов:
```console
# kubectl get nodes -o wide
NAME       STATUS   ROLES    AGE     VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
master-1   Ready    master   5m43s   v1.17.4   192.168.56.101   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8

# kubectl get pods -o wide -A  
NAMESPACE         NAME                                       READY   STATUS    RESTARTS   AGE     IP             NODE       NOMINATED NODE   READINESS GATES
calico-system     calico-kube-controllers-668b579f5c-hbksx   1/1     Running   0          114s    10.244.0.131   master-1   <none>           <none>
calico-system     calico-node-jrksj                          1/1     Running   0          115s    10.0.2.15      master-1   <none>           <none>
calico-system     calico-typha-566bcbf596-tjgs4              1/1     Running   0          115s    10.0.2.15      master-1   <none>           <none>
kube-system       coredns-6955765f44-f2pbd                   1/1     Running   0          5m58s   10.244.0.129   master-1   <none>           <none>
kube-system       coredns-6955765f44-tp6ch                   1/1     Running   0          5m58s   10.244.0.130   master-1   <none>           <none>
kube-system       etcd-master-1                              1/1     Running   0          5m52s   10.0.2.15      master-1   <none>           <none>
kube-system       kube-apiserver-master-1                    1/1     Running   0          5m52s   10.0.2.15      master-1   <none>           <none>
kube-system       kube-controller-manager-master-1           1/1     Running   0          5m52s   10.0.2.15      master-1   <none>           <none>
kube-system       kube-proxy-sfzgw                           1/1     Running   0          5m58s   10.0.2.15      master-1   <none>           <none>
kube-system       kube-scheduler-master-1                    1/1     Running   0          5m52s   10.0.2.15      master-1   <none>           <none>
tigera-operator   tigera-operator-5d44f8865b-bjcwn           1/1     Running   0          2m37s   10.0.2.15      master-1   <none>           <none>
```

   Подключаем worker ноды, для этого на каждой воркер-ноде запускаем команду:
```console
# kubeadm join 192.168.56.101:6443 --token 0mtcsw.7p8b4hxiowxlvqte \
    --discovery-token-ca-cert-hash sha256:eba1ddfe31b6af7ba2b9ce39e4455f1e06cc9559e9a94b08be208fee80397dd5
```

   Если вывод команды потерялся, токены можно посмотреть командой
```console
# kubeadm token list
```

   Получить хеш
```console
# openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
openssl dgst -sha256 -hex | sed 's/^.* //'
```

   Проверяем статус нод кластера:
```console
# kubectl get nodes -o wide 
NAME       STATUS   ROLES    AGE    VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
master-1   Ready    master   111m   v1.17.4   192.168.56.101   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-1   Ready    <none>   102m   v1.17.4   192.168.56.111   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-2   Ready    <none>   101m   v1.17.4   192.168.56.112   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-3   Ready    <none>   100m   v1.17.4   192.168.56.113   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
```

   Пробуем задеплоить в кластер тестовый деплоймент с nginx и проверяем статус подов:
```console
# kubectl apply -f deployment-nginx.yaml
# kubectl get pods -A -o wide | grep nginx-deployment
default           nginx-deployment-c8fd555cc-bcjwc           1/1     Running   0          95m    10.244.0.1     worker-3   <none>           <none>
default           nginx-deployment-c8fd555cc-fhq6k           1/1     Running   0          95m    10.244.0.193   worker-2   <none>           <none>
default           nginx-deployment-c8fd555cc-wmjlm           1/1     Running   0          95m    10.244.0.65    worker-1   <none>           <none>
default           nginx-deployment-c8fd555cc-zrl66           1/1     Running   0          95m    10.244.0.194   worker-2   <none>           <none>
```

  Обновление кластера
  Так как кластер мы разворачивали с помощью kubeadm, то и производить обновление будем с помощью него.
  Обновлять ноды будем по очереди.
  Допускается, отставание версий worker-нод от master, но не наоборот.
  Поэтому обновление будем начинать с master-ноды у нас версии v1.17.4

  Обновление пакетов:
```console
# apt-get update && apt-get install -y kubeadm=1.18.0-00 \
 kubelet=1.18.0-00 kubectl=1.18.0-00

# kubelet --version
Kubernetes v1.18.0

# kubectl version --short
Client Version: v1.18.0
Server Version: v1.17.17

# kubectl get nodes 
NAME       STATUS   ROLES    AGE   VERSION
master-1   Ready    master   14h   v1.18.0
worker-1   Ready    <none>   13h   v1.17.4
worker-2   Ready    <none>   13h   v1.17.4
worker-3   Ready    <none>   13h   v1.17.4
```

   Обновим остальные компоненты кластера
   Обновление компонентов кластера (API-server, kube-proxy, controllermanager)

   Просмотр изменений, которые собирает сделать kubeadm
```console
# kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.17.17
[upgrade/versions] kubeadm version: v1.18.0
I0105 10:14:13.310999    5261 version.go:252] remote version is much newer: v1.26.0; falling back to: stable-1.18
[upgrade/versions] Latest stable version: v1.18.20
[upgrade/versions] Latest stable version: v1.18.20
[upgrade/versions] Latest version in the v1.17 series: v1.17.17
[upgrade/versions] Latest version in the v1.17 series: v1.17.17

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       AVAILABLE
Kubelet     3 x v1.17.4   v1.18.20
            1 x v1.18.0   v1.18.20

Upgrade to the latest stable version:

COMPONENT            CURRENT    AVAILABLE
API Server           v1.17.17   v1.18.20
Controller Manager   v1.17.17   v1.18.20
Scheduler            v1.17.17   v1.18.20
Kube Proxy           v1.17.17   v1.18.20
CoreDNS              1.6.5      1.6.7
Etcd                 3.4.3      3.4.3-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.18.20

Note: Before you can perform this upgrade, you have to update kubeadm to v1.18.20.
```
 
   Применение изменений:
   ( будем обновляться до предлагаемой в дз версии )
```console
# kubeadm upgrade apply v1.18.0
...
...
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.18.0". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```
   
   Проверка:
```console
# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:56:30Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
 
# kubelet --version
Kubernetes v1.18.0
 
# kubectl version
Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:58:59Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:50:46Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
 
# kubectl exec -it kube-apiserver-master-1 -n kube-system -- kube-apiserver --version
Kubernetes v1.18.0
```

   Вывод worker-нод из планирования
   kubectl drain убирает всю нагрузку, кроме DaemonSet, поэтому мы явно должны сказать, что уведомлены об этом
```console
# kubectl drain worker-1 --ignore-daemonsets
node/worker-1 already cordoned
WARNING: ignoring DaemonSet-managed Pods: calico-system/calico-node-zq7tf, kube-system/kube-proxy-5xjhr
evicting pod kube-system/coredns-66bff467f8-kpwvf
evicting pod calico-system/calico-typha-566bcbf596-glbkj
evicting pod default/nginx-deployment-c8fd555cc-wmjlm
pod/calico-typha-566bcbf596-glbkj evicted
pod/nginx-deployment-c8fd555cc-wmjlm evicted
pod/coredns-66bff467f8-kpwvf evicted
node/worker-1 drained
```

   Когда мы вывели ноду на обслуживание, к статусу добавилась строчка SchedulingDisabled
```console
# kubectl get nodes -o wide
NAME       STATUS                     ROLES    AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
master-1   Ready                      master   14h   v1.18.0   192.168.56.101   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-1   Ready,SchedulingDisabled   <none>   14h   v1.17.4   192.168.56.111   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-2   Ready                      <none>   14h   v1.17.4   192.168.56.112   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-3   Ready                      <none>   14h   v1.17.4   192.168.56.113   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
```

   На worker-1 выполняем
```console
# apt-get install -y kubelet=1.18.0-00 kubeadm=1.18.0-00
# kubeadm upgrade node
# systemctl daemon-reload
# systemctl restart kubelet
```

   После обновления kubectl показывает новую версию, и статус SchedulingDisabled
```console
# kubectl get nodes -o wide
NAME       STATUS                     ROLES    AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
master-1   Ready                      master   14h   v1.18.0   192.168.56.101   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-1   Ready,SchedulingDisabled   <none>   14h   v1.18.0   192.168.56.111   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-2   Ready                      <none>   14h   v1.17.4   192.168.56.112   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
worker-3   Ready                      <none>   14h   v1.17.4   192.168.56.113   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   docker://19.3.8
```

   Возвращение ноды в планирование
```console
# kubectl uncordon worker-instance-1
```

   Аналогично обновляем оставшиеся ноды и проверяем статус нод кластера:
```console
# kubectl get nodes
NAME       STATUS   ROLES    AGE   VERSION
master-1   Ready    master   15h   v1.18.0
worker-1   Ready    <none>   15h   v1.18.0
worker-2   Ready    <none>   15h   v1.18.0
worker-3   Ready    <none>   15h   v1.18.0
```
   В итоге мы обновили кластер с v1.17.4 до v1.18.0


2. Kubespray

   Подготовка машин

   Кластер будем поднимать в vagrant.
   Для автоматизации преднастроек виртуальных машин будем использовать "provision shell script" в Vagrantfile.
   ( в преднастройках только копирование ssh_pub ключа на каждую ноду кластера )

   Запускаем создание виртуальных машин и проверяем их статус:
```console
# cd kubernetes-production/ubuntu-kubespray

# vagrant up

# vagrant status
Current machine states:

master-1                  running (virtualbox)
worker-1                  running (virtualbox)
worker-2                  running (virtualbox)
worker-3                  running (virtualbox)
```

   Для удобства kubespray будем запускать в докере:
   Спуллим образ с нужной версией
```console
# docker pull quay.io/kubespray/kubespray:v2.20.0
```

   В поддиректории "inventory" создадим инвентори файл:
   ( ip адреса взяты из Vagrantfile )
```
# cat ./inventory/inventory.ini 
[all]
master-1 ansible_host=192.168.56.101 etcd_member_name=etcd1
worker-1 ansible_host=192.168.56.111
worker-2 ansible_host=192.168.56.112
worker-3 ansible_host=192.168.56.113

# в блоке kube-master мы указывем master-ноды
[kube-master]
master-1

# в блоке etcd ноды, где будет установлен etcd
# если мы хотим HA кластер, то etcd устанавливаетcя отдельно от API-server
[etcd]
master-1

# в блоке kube-node описываем worker-ноды
[kube-node]
worker-1
worker-2
worker-3

# в блоке k8s-cluster:children соединяем kube-master и kube-node
[k8s-cluster:children]
kube-master
kube-node
```

    Запускаем докер с kubesrpay:
```console
# docker run --rm -it --mount type=bind,source="$(pwd)/inventory",dst=/inventory   --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa   quay.io/kubespray/kubespray:v2.20.0 bash
```

    Проверяем, что ansible имеет доступ на все ноды:
```console
ansible -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa -m ping all
```

    Запускаем ansible-playbook "cluster.yml":
```console
ansible-playbook -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa cluster.yml
```

    Если бы у нас пользователь бы непривелигированный нужно было добавлять ключи: "--become --become-user=root"
```console
ansible-playbook -i inventory/mycluster/inventory.ini --become --become-user=root --user=${SSH_USERNAME} --key-file=${SSH_PRIVATE_KEY} cluster.yml
```

    Полный лог ansible приведен в файле:
    "kubernetes-production/ubuntu-kubespray/ansible-kubespray.log"

    Проверяем статус нод кластера.
    Заходим на мастер ноду и выполняем команды: 
```console
# export KUBECONFIG=/etc/kubernetes/admin.conf
# kubectl get nodes -o wide 
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
master-1   Ready    control-plane   19m   v1.24.6   192.168.56.101   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   containerd://1.6.8
worker-1   Ready    <none>          18m   v1.24.6   192.168.56.111   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   containerd://1.6.8
worker-2   Ready    <none>          18m   v1.24.6   192.168.56.112   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   containerd://1.6.8
worker-3   Ready    <none>          18m   v1.24.6   192.168.56.113   <none>        Ubuntu 18.04.6 LTS   4.15.0-200-generic   containerd://1.6.8
```
    
    В итоге мы получили кластер версии v1.24.6

