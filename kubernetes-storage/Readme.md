  Поднимаем однонодовый кластер:
```console
# minikube start --driver='docker' --kubernetes-version='1.24.6'
```
  Проверка
```console
$ kubectl get nodes 
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   33s   v1.24.6
```

 
  Устанавливем "csi-driver-host-path" используя документацию:
  https://github.com/kubernetes-csi/csi-driver-host-path/blob/master/docs/deploy-1.17-and-later.md

  Устанавливать будем в отдельный неймспейс.
  Создадим неймспейс и установим на него "текущий контекст":
```console
$ kubectl create namespace csi-driver-host-path
namespace/csi-driver-host-path created
                                     
$ kubectl config set-context --current --namespace=csi-driver-host-path
Context "minikube" modified.
```

  Скачиваем исходники "external-snapshotter":
```console
# git clone https://github.com/kubernetes-csi/external-snapshotter.git
# cd external-snapshotter

  Добавим в "kustomization.yaml", созданный ранее нами, неймспейс "csi-driver-host-path": 
```console
$ git diff
diff --git a/deploy/kubernetes/csi-snapshotter/kustomization.yaml b/deploy/kubernetes/csi-snapshotter/kustomization.yaml
index 31115c90..4ad725e3 100644
--- a/deploy/kubernetes/csi-snapshotter/kustomization.yaml
+++ b/deploy/kubernetes/csi-snapshotter/kustomization.yaml
@@ -4,3 +4,5 @@ resources:
   - rbac-csi-snapshotter.yaml
   - rbac-external-provisioner.yaml
   - setup-csi-snapshotter.yaml
+
+namespace: csi-driver-host-path
diff --git a/deploy/kubernetes/snapshot-controller/kustomization.yaml b/deploy/kubernetes/snapshot-controller/kustomization.yaml
index 883ea154..0f584613 100644
--- a/deploy/kubernetes/snapshot-controller/kustomization.yaml
+++ b/deploy/kubernetes/snapshot-controller/kustomization.yaml
@@ -3,3 +3,5 @@ kind: Kustomization
 resources:
   - rbac-snapshot-controller.yaml
   - setup-snapshot-controller.yaml
+
+namespace: csi-driver-host-path
```

  Устанавливаем CRD "external-snapshotter":
```console
$ kubectl kustomize client/config/crd | kubectl create -f -
customresourcedefinition.apiextensions.k8s.io/volumesnapshotclasses.snapshot.storage.k8s.io created
customresourcedefinition.apiextensions.k8s.io/volumesnapshotcontents.snapshot.storage.k8s.io created
customresourcedefinition.apiextensions.k8s.io/volumesnapshots.snapshot.storage.k8s.io created
```
  Устанавливаем "snapshot-controller"
```console
$ kubectl kustomize deploy/kubernetes/snapshot-controller | kubectl create -f -
serviceaccount/snapshot-controller created
role.rbac.authorization.k8s.io/snapshot-controller-leaderelection created
clusterrole.rbac.authorization.k8s.io/snapshot-controller-runner created
rolebinding.rbac.authorization.k8s.io/snapshot-controller-leaderelection created
clusterrolebinding.rbac.authorization.k8s.io/snapshot-controller-role created
deployment.apps/snapshot-controller created
```
  Проверяем
```console
$ kubectl get pods -n csi-driver-host-path
NAME                                   READY   STATUS    RESTARTS   AGE
snapshot-controller-76494bf6c9-zc5pj   1/1     Running   0          32s
snapshot-controller-76494bf6c9-zjx68   1/1     Running   0          32s
```


  Скачиваем исходники "csi-driver-host-path":
```console
# git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
# cd csi-driver-host-path
```

  Т.к. мы решили устанавливать "csi-driver-host-path" в неймспейс "csi-driver-host-path", то мы должны внести изменения в "csi-hostpath-plugin.yaml"
```console
$ git diff
diff --git a/deploy/kubernetes-1.24/hostpath/csi-hostpath-plugin.yaml b/deploy/kubernetes-1.24/hostpath/csi-hostpath-plugin.yaml
index 82c1aeb9..78a40f15 100644
--- a/deploy/kubernetes-1.24/hostpath/csi-hostpath-plugin.yaml
+++ b/deploy/kubernetes-1.24/hostpath/csi-hostpath-plugin.yaml
@@ -4,7 +4,7 @@ kind: ServiceAccount
 apiVersion: v1
 metadata:
   name: csi-hostpathplugin-sa
-  namespace: default
+  namespace: csi-driver-host-path
   labels:
     app.kubernetes.io/instance: hostpath.csi.k8s.io
     app.kubernetes.io/part-of: csi-driver-host-path
@@ -27,7 +27,7 @@ roleRef:
 subjects:
 - kind: ServiceAccount
   name: csi-hostpathplugin-sa
-  namespace: default
+  namespace: csi-driver-host-path
 ---
 apiVersion: rbac.authorization.k8s.io/v1
 kind: ClusterRoleBinding
@@ -45,7 +45,7 @@ roleRef:
 subjects:
 - kind: ServiceAccount
   name: csi-hostpathplugin-sa
-  namespace: default
+  namespace: csi-driver-host-path
 ---
 apiVersion: rbac.authorization.k8s.io/v1
 kind: ClusterRoleBinding
@@ -63,7 +63,7 @@ roleRef:
 subjects:
 - kind: ServiceAccount
   name: csi-hostpathplugin-sa
-  namespace: default
+  namespace: csi-driver-host-path
 ---
 apiVersion: rbac.authorization.k8s.io/v1
 kind: ClusterRoleBinding
@@ -81,7 +81,7 @@ roleRef:
 subjects:
 - kind: ServiceAccount
   name: csi-hostpathplugin-sa
-  namespace: default
+  namespace: csi-driver-host-path
 ---
 apiVersion: rbac.authorization.k8s.io/v1
 kind: ClusterRoleBinding
@@ -99,7 +99,7 @@ roleRef:
 subjects:
 - kind: ServiceAccount
   name: csi-hostpathplugin-sa
-  namespace: default
+  namespace: csi-driver-host-path
 ---
 apiVersion: rbac.authorization.k8s.io/v1
 kind: RoleBinding
```
  Для этого выполним следующую команду:
```console
$ sed -i 's/namespace: .\+/namespace: csi-driver-host-path/g' ./deploy/kubernetes-latest/hostpath/csi-hostpath-plugin.yaml
``` 

  Запускаем установку "csi-hostpath-plugin":
```console
$ ./deploy/kubernetes-latest/deploy.sh
applying RBAC rules
curl https://raw.githubusercontent.com/kubernetes-csi/external-provisioner/v3.3.0/deploy/kubernetes/rbac.yaml --output /tmp/tmp.cqmtfksZ2s/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.cqmtfksZ2s
serviceaccount/csi-provisioner created
role.rbac.authorization.k8s.io/external-provisioner-cfg created
clusterrole.rbac.authorization.k8s.io/external-provisioner-runner created
rolebinding.rbac.authorization.k8s.io/csi-provisioner-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-provisioner-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-attacher/v4.0.0/deploy/kubernetes/rbac.yaml --output /tmp/tmp.cqmtfksZ2s/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.cqmtfksZ2s
serviceaccount/csi-attacher created
role.rbac.authorization.k8s.io/external-attacher-cfg created
clusterrole.rbac.authorization.k8s.io/external-attacher-runner created
rolebinding.rbac.authorization.k8s.io/csi-attacher-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-attacher-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/v6.1.0/deploy/kubernetes/csi-snapshotter/rbac-csi-snapshotter.yaml --output /tmp/tmp.cqmtfksZ2s/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.cqmtfksZ2s
serviceaccount/csi-snapshotter created
role.rbac.authorization.k8s.io/external-snapshotter-leaderelection created
clusterrole.rbac.authorization.k8s.io/external-snapshotter-runner created
rolebinding.rbac.authorization.k8s.io/external-snapshotter-leaderelection created
clusterrolebinding.rbac.authorization.k8s.io/csi-snapshotter-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-resizer/v1.6.0/deploy/kubernetes/rbac.yaml --output /tmp/tmp.cqmtfksZ2s/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.cqmtfksZ2s
serviceaccount/csi-resizer created
role.rbac.authorization.k8s.io/external-resizer-cfg created
clusterrole.rbac.authorization.k8s.io/external-resizer-runner created
rolebinding.rbac.authorization.k8s.io/csi-resizer-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-resizer-role created
curl https://raw.githubusercontent.com/kubernetes-csi/external-health-monitor/v0.7.0/deploy/kubernetes/external-health-monitor-controller/rbac.yaml --output /tmp/tmp.cqmtfksZ2s/rbac.yaml --silent --location
kubectl apply --kustomize /tmp/tmp.cqmtfksZ2s
serviceaccount/csi-external-health-monitor-controller created
role.rbac.authorization.k8s.io/external-health-monitor-controller-cfg created
clusterrole.rbac.authorization.k8s.io/external-health-monitor-controller-runner created
rolebinding.rbac.authorization.k8s.io/csi-external-health-monitor-controller-role-cfg created
clusterrolebinding.rbac.authorization.k8s.io/csi-external-health-monitor-controller-role created
deploying hostpath components
   /usr/local/src/csi-driver-host-path/deploy/kubernetes-latest/hostpath/csi-hostpath-driverinfo.yaml
csidriver.storage.k8s.io/hostpath.csi.k8s.io created
   /usr/local/src/csi-driver-host-path/deploy/kubernetes-latest/hostpath/csi-hostpath-plugin.yaml
        using           image: registry.k8s.io/sig-storage/hostpathplugin:v1.9.0
        using           image: registry.k8s.io/sig-storage/csi-external-health-monitor-controller:v0.7.0
        using           image: registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.6.0
        using           image: registry.k8s.io/sig-storage/livenessprobe:v2.8.0
        using           image: registry.k8s.io/sig-storage/csi-attacher:v4.0.0
        using           image: registry.k8s.io/sig-storage/csi-provisioner:v3.3.0
        using           image: registry.k8s.io/sig-storage/csi-resizer:v1.6.0
        using           image: registry.k8s.io/sig-storage/csi-snapshotter:v6.1.0
serviceaccount/csi-hostpathplugin-sa created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-attacher-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-health-monitor-controller-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-provisioner-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-resizer-cluster-role created
clusterrolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-snapshotter-cluster-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-attacher-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-health-monitor-controller-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-provisioner-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-resizer-role created
rolebinding.rbac.authorization.k8s.io/csi-hostpathplugin-snapshotter-role created
statefulset.apps/csi-hostpathplugin created
   /usr/local/src/csi-driver-host-path/deploy/kubernetes-latest/hostpath/csi-hostpath-snapshotclass.yaml
volumesnapshotclass.snapshot.storage.k8s.io/csi-hostpath-snapclass created
   /usr/local/src/csi-driver-host-path/deploy/kubernetes-latest/hostpath/csi-hostpath-testing.yaml
        using           image: docker.io/alpine/socat:1.7.4.3-r0
service/hostpath-service created
statefulset.apps/csi-hostpath-socat created
19:58:21 waiting for hostpath deployment to complete, attempt #0
19:58:31 waiting for hostpath deployment to complete, attempt #1
19:58:41 waiting for hostpath deployment to complete, attempt #2
19:58:51 waiting for hostpath deployment to complete, attempt #3
19:59:01 waiting for hostpath deployment to complete, attempt #4
19:59:11 waiting for hostpath deployment to complete, attempt #5
19:59:21 waiting for hostpath deployment to complete, attempt #6
19:59:31 waiting for hostpath deployment to complete, attempt #7
19:59:42 waiting for hostpath deployment to complete, attempt #8
19:59:52 waiting for hostpath deployment to complete, attempt #9
20:00:02 waiting for hostpath deployment to complete, attempt #10
20:00:12 waiting for hostpath deployment to complete, attempt #11
20:00:22 waiting for hostpath deployment to complete, attempt #12
20:00:32 waiting for hostpath deployment to complete, attempt #13
20:00:42 waiting for hostpath deployment to complete, attempt #14
20:00:53 waiting for hostpath deployment to complete, attempt #15
20:01:03 waiting for hostpath deployment to complete, attempt #16
20:01:13 waiting for hostpath deployment to complete, attempt #17
20:01:23 waiting for hostpath deployment to complete, attempt #18
20:01:33 waiting for hostpath deployment to complete, attempt #19
20:01:43 waiting for hostpath deployment to complete, attempt #20
20:01:53 waiting for hostpath deployment to complete, attempt #21
20:02:04 waiting for hostpath deployment to complete, attempt #22
20:02:14 waiting for hostpath deployment to complete, attempt #23
20:02:24 waiting for hostpath deployment to complete, attempt #24
20:02:34 waiting for hostpath deployment to complete, attempt #25
20:02:44 waiting for hostpath deployment to complete, attempt #26
20:02:54 waiting for hostpath deployment to complete, attempt #27
```
  Проверка
```console 
$ kubectl get pods -n csi-driver-host-path
NAME                                   READY   STATUS    RESTARTS   AGE
csi-hostpath-socat-0                   1/1     Running   0          5m46s
csi-hostpathplugin-0                   8/8     Running   0          5m47s
snapshot-controller-76494bf6c9-zc5pj   1/1     Running   0          7m19s
snapshot-controller-76494bf6c9-zjx68   1/1     Running   0          7m19s
```

  Вернем неймспейс "текущего контекста" в "default"
```console
$ kubectl config set-context --current --namespace=default
Context "minikube" modified.
```

  Создаем "storageclass" "pvc" и "тестовый" pod c примонтированным volume в "/data" 
```console
$ kubectl create -f ./hw/01-storageclass-csi-hostpath-sc.yaml 
storageclass.storage.k8s.io/csi-hostpath-sc created
 
$ kubectl create -f ./hw/02-storage-pvc.yaml 
persistentvolumeclaim/storage-pvc created

$ kubectl create -f ./hw/03-storage-pod.yaml 
pod/storage-pod created
```

  Поверка
```console
$ kubectl get pods -n default
NAME          READY   STATUS    RESTARTS   AGE
storage-pod   1/1     Running   0          25s

$ oc get pvc storage-pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc   Bound    pvc-d9d8a381-c9ee-4c19-82f3-9034d518ac4c   1Gi        RWO            csi-hostpath-sc   78m
 
$ oc describe pod storage-pod
Name:         storage-pod
Namespace:    default
Priority:     0
Node:         minikube/192.168.49.2
Start Time:   Sat, 04 Mar 2023 20:05:23 +0300
Labels:       <none>
Annotations:  <none>
Status:       Running
IP:           10.244.0.7
IPs:
  IP:  10.244.0.7
Containers:
  busybox:
    Container ID:  docker://b3ee8fdbb5386c9d223013449d9292d14088fb682510a037071ee979f750b70d
    Image:         busybox
    Image ID:      docker-pullable://busybox@sha256:7b3ccabffc97de872a30dfd234fd972a66d247c8cfc69b0550f276481852627c
    Port:          <none>
    Host Port:     <none>
    Command:
      sleep
      infinity
    State:          Running
      Started:      Sat, 04 Mar 2023 20:05:36 +0300
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /data from volume-storage-pod (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-hbnkp (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  volume-storage-pod:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  storage-pvc
    ReadOnly:   false
  kube-api-access-hbnkp:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:                      <none>
```

  Как видим "тестовый под" имее требуемы маунт "/data from volume-storage-pod"


  Протестируем создание снапшота и клона с "pvc: storage-pvc"

  Создадим в "/data" пода "storage-pod" тестовые данные:
```console
$ kubectl exec storage-pod -- ls -al /data
total 0
drwxr-xr-x    1 root     root             0 Mar  4 19:12 .
drwxr-xr-x    1 root     root            14 Mar  4 19:12 ..

$ for ii in file-{1..3}; do echo "testcontent-${ii}" | kubectl exec -i storage-pod -- tee -a /data/${ii} ; done
testcontent-file-1
testcontent-file-2
testcontent-file-3
 
$ kubectl exec storage-pod -- ls -al /data
total 12
drwxr-xr-x    1 root     root            36 Mar  4 19:19 .
drwxr-xr-x    1 root     root            14 Mar  4 19:12 ..
-rw-r--r--    1 root     root            19 Mar  4 19:19 file-1
-rw-r--r--    1 root     root            19 Mar  4 19:19 file-2
-rw-r--r--    1 root     root            19 Mar  4 19:19 file-3
```
  Создадим снапшот "storage-snapshot":
```console
$ kubectl create -f ./hw-test-snapshot/05-snapshot.yaml 
volumesnapshot.snapshot.storage.k8s.io/storage-snapshot created
 
$ kubectl get VolumeSnapshot
NAME               READYTOUSE   SOURCEPVC     SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS            SNAPSHOTCONTENT                                    CREATIONTIME   AGE
storage-snapshot   true         storage-pvc                           1Gi           csi-hostpath-snapclass   snapcontent-ad2590c6-a348-42ff-bb76-670394cd7c38   13s            13s
 
$ kubectl get VolumeSnapshotContent 
NAME                                               READYTOUSE   RESTORESIZE   DELETIONPOLICY   DRIVER                VOLUMESNAPSHOTCLASS      VOLUMESNAPSHOT     VOLUMESNAPSHOTNAMESPACE   AGE
snapcontent-ad2590c6-a348-42ff-bb76-670394cd7c38   true         1073741824    Delete           hostpath.csi.k8s.io   csi-hostpath-snapclass   storage-snapshot   default                   36s
```

  Удаляем наш тестовый под и его pvc:
```console 
$ kubectl get pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc   Bound    pvc-d9d8a381-c9ee-4c19-82f3-9034d518ac4c   1Gi        RWO            csi-hostpath-sc   8m46s

$ kubectl get pods 
NAME          READY   STATUS    RESTARTS   AGE
storage-pod   1/1     Running   0          10m

$ kubectl delete pods storage-pod
pod "storage-pod" deleted
$ kubectl delete pvc storage-pvc
persistentvolumeclaim "storage-pvc" deleted

$ kubectl get pods 
No resources found in default namespace. 
$ kubectl get pvc
No resources found in default namespace.
```
  Создаем pvc "storage-pvc-restore" из снапшота "storage-snapshot" и создаем ( с этим pvc ) тестовый pod "storage-pvc-restore":
```console
$ kubectl create -f ./hw-test-snapshot/06-storage-pvc-restore.yaml 
persistentvolumeclaim/storage-pvc-restore created
 
$ kubectl create -f ./hw-test-snapshot/08-storage-restore-pod.yaml 
pod/storage-restore-pod created
 
$ kubectl get pvc
NAME                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
storage-pvc-restore   Bound    pvc-935f44c4-20e2-453f-a311-058103ab0654   1Gi        RWO            csi-hostpath-sc   17s
 
$ kubectl get pods
NAME                  READY   STATUS    RESTARTS   AGE
storage-restore-pod   1/1     Running   0          10s
```
  
  Проверяем наличие наших тестовых данных:
```console 
$ kubectl exec storage-restore-pod -- ls -al /data
total 12
drwxr-xr-x    1 root     root            36 Mar  4 19:24 .
drwxr-xr-x    1 root     root            14 Mar  4 19:24 ..
-rw-r--r--    1 root     root            19 Mar  4 19:19 file-1
-rw-r--r--    1 root     root            19 Mar  4 19:19 file-2
-rw-r--r--    1 root     root            19 Mar  4 19:19 file-3
```




  
