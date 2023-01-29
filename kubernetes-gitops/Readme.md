# ДЗ-14 Kubernetes-gitops

1. На gitlab.com создан "учебный публичный проект":

        https://gitlab.com/vradnit/microservices-demo

2. В этот "учебный публичный проект" сохранен код репозитория microservices-demo:
```console
        git clone https://github.com/GoogleCloudPlatform/microservices-demo
        cd microservices-demo
        git remote add gitlab https://github.com/GoogleCloudPlatform/microservices-demo.git
        git remote remove origin
        git push gitlab main
```

3. В директорию "deploy/charts" "учебный публичного проект" скопированы charts приложений из "deploy/charts":

       https://gitlab.com/express42/kubernetes-platform-demo/microservices-demo/

   Каждый чарт параметризирован (например чарт frontend):
```console
       image:
         repository: frontend
         tag: v0.0.0
```
   В итоге директория "deploy/charts" "учебного публичного проекта" имеет вид:
```console
        # tree -L 1 deploy/charts
        deploy/charts
        ├── adservice
        ├── cartservice
        ├── checkoutservice
        ├── currencyservice
        ├── emailservice
        ├── frontend
        ├── grafana-load-dashboards
        ├── loadgenerator
        ├── paymentservice
        ├── productcatalogservice
        ├── recommendationservice
        └── shippingservice
```

4. Имеем собственный кубернетес кластер (развернутый через kubeadm):
```console
        # k get nodes 
        NAME      STATUS   ROLES                  AGE   VERSION
        k8s-m-1   Ready    control-plane,worker   84d   v1.24.6
        k8s-m-2   Ready    control-plane,worker   84d   v1.24.6
        k8s-m-3   Ready    control-plane,worker   84d   v1.24.6
        k8s-w-1   Ready    worker                 17d   v1.24.6
```

5. Для автоматизации развертывания сборки образов приложений в https://gitlab.com/vradnit/microservices-demo
   был создан gitlab pipeline, содержащий стадии build и push docker образов для каждого приложения

   В качестве тега образа используется tag коммита, инициирующего сборку 
   (переменная CI_COMMIT_TAG в GitLab CI)

   Копия пайплайна сохренена в:

        "kubernetes-gitops/pipeline/.gitlab-ci.yml"

6. Установка Flux2.

   В дз описана установка flux1, а т.к. он уже depricated, то изменим условия задачи.
   Установим flux2 и выполним требования ДЗ используя его примитивы.

   На локальный компьютер скачаем и установим бинарник flux2:
   https://github.com/fluxcd/flux2/releases/tag/v0.38.2

   Проинсталлируем flux2 в отдельный неймспейс "flux-system", при этом будем использовать 
   отдельный инфраструктурный репозиторий: https://gitlab.com/vradnit/radnit-k8s-gitops.git
```console
        # flux bootstrap gitlab --components-extra=image-reflector-controller,image-automation-controller --owner=vradnit --personal  --repository=radnit-k8s-gitops --branch=main --token-auth
        Please enter your GitLab personal access token (PAT): 
        ► connecting to https://gitlab.com
        ► cloning branch "main" from Git repository "https://gitlab.com/vradnit/radnit-k8s-gitops.git"
        ✔ cloned repository
        ► generating component manifests
        ✔ generated component manifests
        ✔ committed sync manifests to "main" ("eab673b9fbd044c46b1396e3a635d1b9c10a4709")
        ► pushing component manifests to "https://gitlab.com/vradnit/radnit-k8s-gitops.git"
        ► installing components in "flux-system" namespace
        ✔ installed components
        ✔ reconciled components
        ► determining if source secret "flux-system/flux-system" exists
        ► generating source secret
        ► applying source secret "flux-system/flux-system"
        ✔ reconciled source secret
        ► generating sync manifests
        ✔ generated sync manifests
        ✔ committed sync manifests to "main" ("e213784e2098e787e7c4a055c359192fcdc5b8c7")
        ► pushing sync manifests to "https://gitlab.com/vradnit/radnit-k8s-gitops.git"
        ► applying sync manifests
        ✔ reconciled sync configuration
        ◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
        ✔ Kustomization reconciled successfully
        ► confirming components are healthy
        ✔ helm-controller: deployment ready
        ✔ image-automation-controller: deployment ready
        ✔ image-reflector-controller: deployment ready
        ✔ kustomize-controller: deployment ready
        ✔ notification-controller: deployment ready
        ✔ source-controller: deployment ready
        ✔ all components are healthy
```

    Проверка успешности создания компонентов:
```console
        # k get gitrepo -n flux-system flux-system 
        NAME          URL                                                AGE    READY   STATUS
        flux-system   https://gitlab.com/vradnit/radnit-k8s-gitops.git   4m6s   True    stored artifact for revision 'main/e213784e2098e787e7c4a055c359192fcdc5b8c7'

        # k get secret -n flux-system flux-system 
        NAME          TYPE     DATA   AGE
        flux-system   Opaque   2      4m17s

        # k get kustomization -n flux-system
        NAME          AGE     READY   STATUS
        flux-system   4m51s   True    Applied revision: main/e213784e2098e787e7c4a055c359192fcdc5b8c7


        # flux version
        flux: v0.38.2
        helm-controller: v0.28.1
        image-automation-controller: v0.28.0
        image-reflector-controller: v0.23.1
        kustomize-controller: v0.32.0
        notification-controller: v0.30.2
        source-controller: v0.33.0

        # flux get all -n flux-system
        NAME                     	REVISION    	SUSPENDED	READY	MESSAGE                                                                      
        gitrepository/flux-system	main/e213784	False    	True 	stored artifact for revision 'main/e213784e2098e787e7c4a055c359192fcdc5b8c7'	

        NAME                     	REVISION    	SUSPENDED	READY	MESSAGE                        
        kustomization/flux-system	main/e213784	False    	True 	Applied revision: main/e213784
```

7. Создаем GitRepository для релизов "microservices-demo", добавляем "deploy key" в "учебный проект" gitlab ( не забываем добавить grant write permission )
```console
        # flux create source git microservices-demo --url=ssh://git@gitlab.com/vradnit/microservices-demo --branch=main -n microservices-demo
        ✚ generating GitRepository source
        ✔ collected public key from SSH server:
        gitlab.com ecdsa-sha2-nistp256 AAAAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=
        ✚ deploy key: ecdsa-sha2-nistp384 AAAAXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=

        Have you added the deploy key to your repository: y
        ► applying secret with repository credentials
        ✔ authentication configured
        ► applying GitRepository source
        ✔ GitRepository source created
        ◎ waiting for GitRepository source reconciliation
        ✔ GitRepository source reconciliation completed
        ✔ fetched revision: main/edde88a944f737e16602c0a61846dc4bd22947df
```
    Проверяем, что GitRepository и secret создались:
```console
        # k get GitRepository -n microservices-demo microservices-demo
        NAME                 URL                                               AGE     READY   STATUS
        microservices-demo   ssh://git@gitlab.com/vradnit/microservices-demo   3m35s   True    stored artifact for revision 'main/edde88a944f737e16602c0a61846dc4bd22947df'

        # k get secret -n microservices-demo microservices-demo
        NAME                 TYPE     DATA   AGE
        microservices-demo   Opaque   3      3m43s
```

8. В директории "deploy/releases" "учебного проекта" для каждого приложения создаем манифесты helmrelease, в которых указываем путь до хелмчарта + gitrepo,
   а также с помощью "placeholder" указываем места в манифесте для коммитов со стороны "imageupdateautomation"
    например:
```console
        values:
          image:
            repository: vradnit/cartservice # {"$imagepolicy": "microservices-demo:cartservice:name"}
            tag: v0.0.1 # {"$imagepolicy": "microservices-demo:cartservice:tag"}
```

    В манифесте "deploy/releases/release_imageupdateautomation.yaml", для каждого приложения объявлены манифесты ImageRepository и ImagePolicy,
    которые предназначены для определения "за каким doker-registry следить" и "policy отслеживания" ( в нашем случае semver )
```console
        apiVersion: image.toolkit.fluxcd.io/v1beta1
        kind: ImageRepository
        metadata:
          name: frontend
          namespace: microservices-demo 
        spec:
          image: vradnit/frontend
          interval: 2m0s


        apiVersion: image.toolkit.fluxcd.io/v1beta1
        kind: ImagePolicy
        metadata:
          name: frontend
          namespace: microservices-demo
        spec:
          imageRepositoryRef:
            name: frontend
          policy:
            semver:
              range: 0.0.x
```
    В этом же манифесте объявлен общий манифест "ImageUpdateAutomation", необходимы для определения "gitrepo" + "путь в girepo" + "темплейт коммита":
```console    
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: frontend
  namespace: microservices-demo
spec:
  interval: 2m0s
  sourceRef:
    kind: GitRepository
    name: microservices-demo
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: fluxcdbot@radnit.ru
        name: fluxcdbot
      messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}'
    push:
      branch: main
  update:
    path: ./deploy/releases/
    strategy: Setters
```

    В манифесте "./deploy/releases/release_kustomization.yaml" объявлен основной kustomization releas, который предназначен для "разливки" всех манифестов в дирекории "./deploy/releases"
    ( а также самого себя )
```console
# cat ./deploy/releases/release_kustomization.yaml 
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: microservices-demo
  namespace: microservices-demo
spec:
  force: false
  interval: 2m
  path: ./deploy/releases
  prune: true
  sourceRef:
    kind: GitRepository
    name: microservices-demo
```

    Итоговый список манифестов:
```console
# tree ./deploy/releases/
./deploy/releases/
├── helmrelease_adservice.yaml
├── helmrelease_cartservice.yaml
├── helmrelease_checkoutservice.yaml
├── helmrelease_currencyservice.yaml
├── helmrelease_emailservice.yaml
├── helmrelease_frontend.yaml
├── helmrelease_grafana-load-dashboards.yaml
├── helmrelease_loadgenerator.yaml
├── helmrelease_paymentservice.yaml
├── helmrelease_productcatalogservice.yaml
├── helmrelease_recommendationservice.yaml
├── helmrelease_shippingservice.yaml
├── release_gitrepository.yaml
├── release_imageupdateautomation.yaml
└── release_kustomization.yaml
```

9. На текущий момент у нас все готово для "раскатки" релиза "microservices-demo", но еще нет неймспейса "microservices-demo"
   Для создания неймспейса воспользуемся инфраструктурным репозиторием, создадим в нем отдельную директорию, для инфра-манифестов "microservices-demo"
   ( сразу добавим лейбл для istio )

```console
# cat  radnit-k8s-gitops/microservices-demo/namespace.yaml 
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: microservices-demo
```

    Итоговая структура репозитория "https://gitlab.com/vradnit/radnit-k8s-gitops.git":
```console
├── flux-system
│   ├── gotk-components.yaml
│   ├── gotk-sync.yaml
│   └── kustomization.yaml
└── microservices-demo
    └── namespace.yaml
```

    Через некоторое время в нашем кластере должен появится неймспейс "microservices-demo"


10. Запускаем создание "общего kustomize релиза":
```console
# k create -n microservices-demo -f ./deploy/releases/release_kustomization.yaml
kustomization.kustomize.toolkit.fluxcd.io/microservices-demo created
```

    Через некторое время в кластере появится kustomization "microservices-demo" и helmrelease для каждого приложения.
    
    проверяем:
```console
# k get kustomization -n microservices-demo
NAME                 AGE   READY   STATUS
microservices-demo   30s   True    Applied revision: main/edde88a944f737e16602c0a61846dc4bd22947df

# k get hr -n microservices-demo
NAME                      AGE   READY   STATUS
adservice                 40s   True    Release reconciliation succeeded
cartservice               40s   True    Release reconciliation succeeded
checkoutservice           40s   True    Release reconciliation succeeded
currencyservice           40s   True    Release reconciliation succeeded
emailservice              40s   True    Release reconciliation succeeded
frontend                  40s   True    Release reconciliation succeeded
grafana-load-dashboards   40s   True    Release reconciliation succeeded
loadgenerator             40s   True    Release reconciliation succeeded
paymentservice            40s   True    Release reconciliation succeeded
productcatalogservice     40s   True    Release reconciliation succeeded
recommendationservice     40s   True    Release reconciliation succeeded
shippingservice           40s   True    Release reconciliation succeeded


# flux get hr -n microservices-demo
NAME                   	REVISION           	SUSPENDED	READY	MESSAGE                          
adservice              	0.5.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	
cartservice            	0.4.1+edde88a944f7 	False    	True 	Release reconciliation succeeded	
checkoutservice        	0.4.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	
currencyservice        	0.4.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	
emailservice           	0.4.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	
frontend               	0.21.0+edde88a944f7	False    	True 	Release reconciliation succeeded	
grafana-load-dashboards	0.0.3+edde88a944f7 	False    	True 	Release reconciliation succeeded	
loadgenerator          	0.4.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	
paymentservice         	0.3.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	
productcatalogservice  	0.3.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	
recommendationservice  	0.3.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	
shippingservice        	0.3.0+edde88a944f7 	False    	True 	Release reconciliation succeeded	

# flux get ks -n microservices-demo
NAME              	REVISION    	SUSPENDED	READY	MESSAGE                        
microservices-demo	main/edde88a	False    	True 	Applied revision: main/edde88a
```


11. Проверка автоматизации деплоя.
    Если сейчас произвести любые изменения в репе "microservices-demo", затем добавить новый тэг v0.0.2, то после 
    окончания CICD в докерхабе будут лежать новые образы всех приложений с тэгом "v0.0.2"

    Соответствующая ImagePolicy контролируя свой ImageRepository сдетектирует появление нового тэга в docker-registry,
    а ImageUpdateAutomation сделает коммит в репо.

    пример коммита:    
```console
@@ -15,4 +15,4 @@ spec:
   values:
     image:
       repository: vradnit/frontend
-      tag: v0.0.1
+      tag: v0.0.2
```

    Т.к. в соответствующем helmrelease изменяться "values", то произойдет обновление релиза

    Нужно также учитывать, что сейчас у нас во всех helmrelease используется "reconcileStrategy: Revision", т.е. обновление происходит
    при любом изменении внутри чарта. При использовании "reconcileStrategy: ChartVersion" обновления будут происходить только при изменении в версии чарта или values.


12. При деплое приложений в кластере столкнулся с проблемой запуска нескольких приложений.
    Проблема возникла изз включенного профилирования в некоторых приложениях.

    удаляем профилирование
    https://github.com/GoogleCloudPlatform/microservices-demo/issues/801
    https://user-images.githubusercontent.com/10292865/199751426-88295dfd-3f59-45c2-a60e-5bb41a80585a.png

```console
--- a/deploy/charts/emailservice/templates/deployment.yaml
+++ b/deploy/charts/emailservice/templates/deployment.yaml
@@ -19,6 +19,8 @@ spec:
         env:
         - name: PORT
           value: "8080"
+        - name: DISABLE_PROFILER
+          value: "1"
         readinessProbe:
           periodSeconds: 5
           exec:
```


13. Настройка Canary deployment посредством Flagger+Istio.

    Установка istioctl:
```console
# curl -L https://istio.io/downloadIstio | sh -
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   101  100   101    0     0    279      0 --:--:-- --:--:-- --:--:--   279
100  4856  100  4856    0     0   8445      0 --:--:-- --:--:-- --:--:-- 33958

Downloading istio-1.16.1 from https://github.com/istio/istio/releases/download/1.16.1/istio-1.16.1-linux-amd64.tar.gz ...

Istio 1.16.1 Download Complete!

Istio has been successfully downloaded into the istio-1.16.1 folder on your system.

Next Steps:
See https://istio.io/latest/docs/setup/install/ to add Istio to your Kubernetes cluster.

To configure the istioctl client tool for your workstation,
add the /usr/local/bin/istio-1.16.1/bin directory to your environment path variable with:
	 export PATH="$PATH:/usr/local/bin/istio-1.16.1/bin"

Begin the Istio pre-installation check by running:
	 istioctl x precheck 

Need more information? Visit https://istio.io/latest/docs/setup/install/ 
# mv istio-1.16.1/bin/istioctl /usr/local/bin/
```

    Установка Istio в кластер:
```console
# istioctl x precheck
✔ No issues found when checking the cluster. Istio is safe to install or upgrade!
  To get started, check out https://istio.io/latest/docs/setup/getting-started/

# istioctl install --set profile=demo -y
✔ Istio core installed                                                                                                                                                                                                                                                                             
✔ Istiod installed                                                                                                                                                                                                                                                                                 
✔ Egress gateways installed                                                                                                                                                                                                                                                                        
✔ Ingress gateways installed                                                                                                                                                                                                                                                                       
✔ Installation complete                                                                                                                                                                                                                                                                            Making this installation the default for injection and validation.

Thank you for installing Istio 1.16.  Please take a few minutes to tell us about your install/upgrade experience!  https://forms.gle/99uiMML96AmsXY5d6
```

    После установки istio и "ручного" перезапуска всех подов ( label "istio-injection: enabled" на неймспейсе у нас уже стоит ),
    столкнулся с проблемой запуска подов с sidecar istio, изза отсутствия модулей в ядре 
    Добавляем модули ipt_nat и тд: https://github.com/istio/istio/issues/23009


    В итоге получили следующую картину:
```console
# k get pods -n microservices-demo -o wide
NAME                                            READY   STATUS    RESTARTS       AGE   IP               NODE      NOMINATED NODE   READINESS GATES
adservice-56b4587549-2bzhd                      2/2     Running   1 (104s ago)   24m   10.244.196.103   k8s-w-1   <none>           <none>
cartservice-65dd75c585-nbn7v                    2/2     Running   0              24m   10.244.196.90    k8s-w-1   <none>           <none>
checkoutservice-5bdd494bbc-g6zql                2/2     Running   0              24m   10.244.196.96    k8s-w-1   <none>           <none>
currencyservice-5c7665cbcc-4mr58                2/2     Running   0              24m   10.244.196.97    k8s-w-1   <none>           <none>
emailservice-567cd6479b-d4zbt                   2/2     Running   0              24m   10.244.196.105   k8s-w-1   <none>           <none>
frontend-dd44f8998-pxqxk                2/2     Running   0              24m   10.244.196.91    k8s-w-1   <none>           <none>
loadgenerator-775d68c57f-4gwlz                  2/2     Running   0              24m   10.244.196.74    k8s-w-1   <none>           <none>
microservices-demo-cartservice-redis-master-0   2/2     Running   0              23m   10.244.196.81    k8s-w-1   <none>           <none>
paymentservice-dfb9c9d4c-69mlq                  2/2     Running   0              24m   10.244.196.92    k8s-w-1   <none>           <none>
productcatalogservice-8586bf6d85-vp567          2/2     Running   0              24m   10.244.196.94    k8s-w-1   <none>           <none>
recommendationservice-6b956ccd7d-hn9bs          2/2     Running   0              24m   10.244.196.102   k8s-w-1   <none>           <none>
shippingservice-849f97c7f5-v9sjr                2/2     Running   0              24m   10.244.196.68    k8s-w-1   <none>           <none>
```

14. Обеспечение доступа к frontend "microservices-demo" снаружи кластера:

    В хелм чарте frontend создаем манифесты Istio.

    Манифест "Gateway", обеспечивающий (через loadbalancer и имя "shop.radnit.ru" ) доступ снаружи:
```console
# cat ./deploy/charts/frontend/templates/gateway.yaml 
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: frontend-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "{{ .Values.ingress.host }}"
```

    Манифест "VirtualService" маршрутизирующий трафик c "shop.radnit.ru" на сервис "frontend"
```console
# cat ./deploy/charts/frontend/templates/virtualService.yaml 
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: frontend
spec:
  hosts:
  - "{{ .Values.ingress.host }}"
  gateways:
  - frontend-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
```

    Таким образом трафик с 'Host: shop.radnit.ru' пришедший на внешний IP: 192.168.0.129 будет маршрутизироваться в pod "frontend":
```console
# k get svc -n istio-system istio-ingressgateway
NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.105.205.130   192.168.0.129   15021:32369/TCP,80:31301/TCP,443:32261/TCP,31400:30024/TCP,15443:32505/TCP   7d18h
```


15. Установка Flagger.
    Установку flagger произведем через helmfile: "kubernetes-gitops/helmfile-flagger.yaml",
    где укажем также создать podmonitor для сбора метрик с контроллера flagger, тип "meshProvider: istio"
    а также укажем имя сервиса kube-prometheus ( для сбора метрик с istio sidecar ).
    ( "kube-prometheus" у нас уже установлен )

```console
# kubectl apply -f https://raw.githubusercontent.com/weaveworks/flagger/master/artifacts/flagger/crd.yaml
# helmfile -f helmfile-flagger.yaml apply
```

   В итоге на этом шаге имеем:
```console
# k get pod -n istio-system
NAME                                   READY   STATUS                   RESTARTS       AGE
flagger-7dffb69748-nkrvg               1/1     Running                  1              6d3h
istio-egressgateway-688d4797cd-9jd6k   1/1     Running                  1              7d18h
istio-ingressgateway-6bd9cfd8-26f5s    1/1     Running                  1              7d18h
istiod-68fdb87f7-ht77f                 1/1     Running                  1              7d18h

# k get podmonitor -n istio-system
NAME                  AGE
envoy-stats-monitor   4d7h
flagger               3d21h
```

16. Создание манифеста Canary.yaml:
    В чарт frontend добавим манифест описывающий стратегию обновления (тестирования) ресурса "frontend":

```console
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: frontend
spec:
  provider: istio
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  progressDeadlineSeconds: 60
  service:
    port: 80
    targetPort: 8080
    gateways:
    - frontend-gateway
    hosts:
    - {{ .Values.ingress.host }}
    trafficPolicy:
      tls:
        mode: DISABLE
  analysis:
    interval: 60s
    threshold: 6
    maxWeight: 50
    stepWeight: 5
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 60s
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 60s
```

    По итогам "разливки" манифеста "Canary" в кластере должны появится:
```console
# kubectl get canary -n microservices-demo
NAME       STATUS      WEIGHT   LASTTRANSITIONTIME
frontend   Initializing   0        2022-12-22T19:17:11Z

# kubectl get pods -n microservices-demo -l app=frontend-primary
NAME                                READY   STATUS    RESTARTS   AGE
frontend-primary-79c4f459d8-bclg8   2/2     Running   2          19h
```
, т.е. к имени "frontend" добавился суффикс "-primary"


16. Выкатка тестового релиза.
    Произведем тестовую сборку образа frontend с новым тэгом v0.0.3 и зугрузим его в докерхаб.
    После необходимых итераций контроллеров "flux" произведена попытка деплоя микросервиса "frontend",
    но она неудачная, т.к. нет необходимых метрик в прометее "kube-system"
```console
11m         Warning   Synced                       canary/frontend                                        Halt advancement no values found for istio metric request-success-rate probably frontend.microservices-demo is not receiving traffic: running query failed: no values found
10m         Warning   Synced                       canary/frontend                                        Rolling back frontend.microservices-demo failed checks threshold reached 6
10m         Warning   Synced                       canary/frontend                                        Canary failed! Scaling down frontend.microservices-demo
```

    Уточнение, что в values чарта "loadgenerator" мы указывали "shop.radnit.ru", для того чтобы трафик приходил во frontend "снаружи"

17. Через инфрастуктурный репозиторий создадим "podmonitor" для скрейпа метрик со всех sidecar istio:
    (  за пример этого podmonitor, отдельное спасибо Евгению Павлову :) за практику в лекции )

      "kubernetes-gitops/istio-podmonitor.yaml"

18. После появления метрик в графане, проведем повторную раскатку микросервиса "frontend".
    
    Логи раскатки сервиса "frontend" с версии v0.0.7 на v0.0.8 приведены в:
       "./flagger-logs/flagger-v0.0.7-v0.0.8.log"

    Для удобства анализа процесса раскатки canary релизов предварительно в графану был установлен дашборд:
       https://grafana.com/grafana/dashboards/15158-flagger-canary-status/

    Скрины успешности релиза "c v0.0.7 на v0.0.8" приведены в:
```console
# tree kubernetes-gitops/flagger-dashboard-img/
kubernetes-gitops/flagger-dashboard-img/
├── image_2022-12-21_22-06-32.png
├── image_2022-12-21_22-07-28.png
├── image_2022-12-21_22-08-00.png
└── image_2022-12-21_22-09-02.png
```



X. Argocd + Argocd-Image-Updater

   Установка "argocd" + "argocd-image-updater"
   Подготовим helmfile + values:
   "kubernetes-gitops/argocd/helmfile-argocd.yaml"
   "kubernetes-gitops/argocd/values-argocd.yaml" 

   Запускаем установку:
```console
# kubectl create namespace argocd 

#helmfile -f helmfile-argocd.yaml apply
...
UPDATED RELEASES:
NAME                   CHART                                       VERSION
argocd                 argocd/argo-cd                               5.17.1
argocd-image-updater   argocd-image-updater/argocd-image-updater     0.8.1
```

   Проверяем статус подов:
```console
# k get pods -n argocd 
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          3m52s
argocd-applicationset-controller-76bccb9647-wz6db   1/1     Running   0          3m52s
argocd-dex-server-98b669df6-lzl58                   1/1     Running   0          3m52s
argocd-image-updater-5d5959cb94-26llf               1/1     Running   0          4m1s
argocd-notifications-controller-579b4f8f4c-dsx6r    1/1     Running   0          3m52s
argocd-redis-57fbd6b455-qmj2q                       1/1     Running   0          3m52s
argocd-repo-server-5778d47fd7-pmgs6                 1/1     Running   0          3m52s
argocd-server-755bfbf69-4f9bw                       1/1     Running   0          3m52s
```

   Устанавливаем консольную утилиту argocd:
```console
# curl -L https://github.com/argoproj/argo-cd/releases/download/v2.5.6/argocd-linux-amd64 -o /usr/local/bin/argocd && chmod a+x /usr/local/bin/argocd

# argocd version
argocd: v2.5.6+9db2c94
  BuildDate: 2023-01-10T19:55:00Z
  GitCommit: 9db2c9471f6ff599c3f630b446e940d3a065620b
  GitTreeState: clean
  GoVersion: go1.18.9
  Compiler: gc
  Platform: linux/amd64
argocd-server: v2.5.6+9db2c94
```

   Проверяем доступность web интерфейса: https://argocd-k8s.radnit.ru
   используя секрет из:
```console
# k get secret -n argocd argocd-initial-admin-secret
NAME                          TYPE     DATA   AGE
argocd-initial-admin-secret   Opaque   1      6m48s
```

   Подключаемся с инстансу argocd и проверяем видимость дефолтного проекта:
```console
# argocd login --grpc-web argocd-k8s.radnit.ru
Username: admin
Password: 
'admin:login' logged in successfully

# argocd proj list
NAME     DESCRIPTION  DESTINATIONS  SOURCES  CLUSTER-RESOURCE-WHITELIST  NAMESPACE-RESOURCE-BLACKLIST  SIGNATURE-KEYS  ORPHANED-RESOURCES
default               *,*           *        */*                         <none>                        <none>          disabled
```

   Создадим две репы:
   . для приложения hepstershop:
     https://gitlab.com/vradnit/argocd-microservices-demo.git
   . для инфраструктурных манифестов:
     https://gitlab.com/vradnit/argocd-infra.git

   Для каждой репы в гитлабе создадим токен:
   . для приложения RW+майнтейнер ( т.к. нужен push в main )
   . для инфраструктуры только RO+reporter


   Добавляем полученные токены в argocd:
```console
# argocd repo add https://gitlab.com/vradnit/argocd-infra.git --username vradnit-infra --password glpat-XXXXXX --name vradnit-infra --type git
Repository 'https://gitlab.com/vradnit/argocd-infra.git' added

# argocd repo add https://gitlab.com/vradnit/argocd-microservices-demo.git --username vradnit-microservices-demo --password glpat-XXXXXX --name vradnit-microservices-demo --type git
Repository 'https://gitlab.com/vradnit/argocd-microservices-demo.git' added

# argocd repo list
TYPE  NAME                        REPO                                                      INSECURE  OCI    LFS    CREDS  STATUS      MESSAGE  PROJECT
git   vradnit-infra               https://gitlab.com/vradnit/argocd-infra.git               false     false  false  true   Successful           
git   vradnit-microservices-demo  https://gitlab.com/vradnit/argocd-microservices-demo.git  false     false  false  true   Successful 
```

   Добавим в репозиторий https://gitlab.com/vradnit/argocd-infra.git
   . aplication "application-infra", для создание всех манифестов из данной репы
   . создание неймспейса "microservices-demo" с лейбдлом istio
   . appproject "microservices-demo", где укажем разрешения на создание манифестов только в неймспейсе "microservices-demo"
   . aplication adservice,cartservice,checkoutservice...shippingservice , т.е. всех апликаций приложения "hipster-shop"

   итоговая структура репозитория https://gitlab.com/vradnit/argocd-infra.git:
```console
# tree ./argocd-infra/
./argocd-infra/
├── argocd
│   ├── application_adservice.yaml
│   ├── application_cartservice.yaml
│   ├── application_checkoutservice.yaml
│   ├── application_currencyservice.yaml
│   ├── application_emailservice.yaml
│   ├── application_frontend.yaml
│   ├── application_grafana-load-dashboards.yaml
│   ├── application_infra.yaml
│   ├── application_loadgenerator.yaml
│   ├── application_paymentservice.yaml
│   ├── application_productcatalogservice.yaml
│   ├── application_recommendationservice.yaml
│   ├── application_shippingservice.yaml
│   └── appproject_microservices-demo.yaml
├── microservices-demo
│   └── namespace.yaml
└── Readme.md
```

   Содержимое application "application-infra":
```console
# cat ./argocd-infra/argocd/application_infra.yaml 
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: application-infra
  namespace: argocd
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: default
  source:
    path: ./
    repoURL: https://gitlab.com/vradnit/argocd-infra.git
    targetRevision: HEAD
    directory:
      recurse: true
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

   Содержимое appproject "microservices-demo":
```console
# cat ./argocd-infra/argocd/appproject_microservices-demo.yaml 
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: microservices-demo
  namespace: argocd
spec:
  clusterResourceWhitelist: []
  destinations:
  - namespace: microservices-demo
    server: https://kubernetes.default.svc
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
  sourceNamespaces:
  - microservices-demo
  sourceRepos:
  - '*'
```

   Содержимое одной application, с аннотациями для "argocd-image-updater":
```console
# cat ./argocd-infra/argocd/application_adservice.yaml 
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd-image-updater.argoproj.io/adservice.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/adservice.helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/adservice.update-strategy: semver
    argocd-image-updater.argoproj.io/git-branch: main
    argocd-image-updater.argoproj.io/image-list: adservice=vradnit/adservice:v0.0.x
    argocd-image-updater.argoproj.io/write-back-method: git
  name: adservice
  namespace: argocd
spec:
  destination:
    namespace: microservices-demo
    server: https://kubernetes.default.svc
  project: microservices-demo
  source:
    helm:
      valueFiles:
      - values.yaml
    path: deploy/charts/adservice
    repoURL: https://gitlab.com/vradnit/argocd-microservices-demo.git
    targetRevision: HEAD
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

   Структура репозитория https://gitlab.com/vradnit/argocd-microservices-demo.git, отличается от "варианта с fluxcd", только тем что из нее удалена директория "./releases",
   т.е. в ней остались только helm charts: 
```console
# tree ./argocd-microservices-demo/
./argocd-microservices-demo/
└── deploy
    └── charts
        ├── adservice
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── deployment.yaml
        │   │   └── service.yaml
        │   └── values.yaml
        ├── cartservice
        │   ├── Chart.lock
        │   ├── charts
        │   │   └── redis-10.2.1.tgz
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── deployment.yaml
        │   │   ├── _helpers.tpl
        │   │   └── service.yaml
        │   └── values.yaml
        ├── checkoutservice
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── deployment.yaml
        │   │   └── service.yaml
        │   └── values.yaml
        ├── currencyservice
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── deployment.yaml
        │   │   └── service.yaml
        │   └── values.yaml
        ├── emailservice
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── deployment.yaml
        │   │   └── service.yaml
        │   └── values.yaml
        ├── frontend
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── canary.yaml
        │   │   ├── deployment.yaml
        │   │   ├── gateway.yaml
        │   │   ├── serviceMonitor.yaml
        │   │   ├── service.yaml
        │   │   └── virtualService.yaml
        │   └── values.yaml
        ├── grafana-load-dashboards
        │   ├── Chart.yaml
        │   ├── dashboards
        │   │   └── go-processes.json
        │   ├── README.md
        │   ├── templates
        │   │   └── configmap.yaml
        │   └── values.yaml
        ├── loadgenerator
        │   ├── Chart.yaml
        │   ├── templates
        │   │   └── deployment.yaml
        │   └── values.yaml
        ├── paymentservice
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── deployment.yaml
        │   │   └── service.yaml
        │   └── values.yaml
        ├── productcatalogservice
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── deployment.yaml
        │   │   └── service.yaml
        │   └── values.yaml
        ├── recommendationservice
        │   ├── Chart.yaml
        │   ├── templates
        │   │   ├── deployment.yaml
        │   │   └── service.yaml
        │   └── values.yaml
        └── shippingservice
            ├── Chart.yaml
            ├── templates
            │   ├── deployment.yaml
            │   └── service.yaml
            └── values.yaml
```


   После проведенных подготовительных работ, создаем "основную апликацию", и через некторое время в кластере появится приложение "hipster-shop"
   ( istio у нас уже установлен )
```console
# kubectl create -f ./argocd-infra/argocd/application_infra.yaml
```

   Проверяем статус "application" и статус подов:
```console
# argocd proj list
NAME                DESCRIPTION  DESTINATIONS                                       SOURCES  CLUSTER-RESOURCE-WHITELIST  NAMESPACE-RESOURCE-BLACKLIST  SIGNATURE-KEYS  ORPHANED-RESOURCES
default                          *,*                                                *        */*                         <none>                        <none>          disabled
microservices-demo               https://kubernetes.default.svc,microservices-demo  *        <none>                      <none>                        <none>          disabled
 
# argocd app list
NAME                            CLUSTER                         NAMESPACE           PROJECT             STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                                                      PATH                                   TARGET
argocd/adservice                https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/adservice                HEAD
argocd/application-infra        https://kubernetes.default.svc  argocd              default             Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-infra.git               ./                                     HEAD
argocd/cartservice              https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/cartservice              HEAD
argocd/checkoutservice          https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/checkoutservice          HEAD
argocd/currencyservice          https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/currencyservice          HEAD
argocd/emailservice             https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/emailservice             HEAD
argocd/frontend                 https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Unknown  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/frontend                 HEAD
argocd/grafana-load-dashboards  https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/grafana-load-dashboards  HEAD
argocd/loadgenerator            https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/loadgenerator            HEAD
argocd/paymentservice           https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/paymentservice           HEAD
argocd/productcatalogservice    https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/productcatalogservice    HEAD
argocd/recommendationservice    https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/recommendationservice    HEAD
argocd/shippingservice          https://kubernetes.default.svc  microservices-demo  microservices-demo  Synced  Healthy  Auto-Prune  <none>      https://gitlab.com/vradnit/argocd-microservices-demo.git  deploy/charts/shippingservice          HEAD
 
# k get pods -n microservices-demo
NAME                                    READY   STATUS    RESTARTS      AGE
adservice-74bc4457cd-rmk7g              2/2     Running   1 (70m ago)   71m
cartservice-648c5c87d5-4qj99            2/2     Running   0             71m
cartservice-redis-master-0              2/2     Running   0             75m
checkoutservice-65644b6f7d-ghsh6        2/2     Running   0             71m
currencyservice-6594476596-pmd8w        2/2     Running   0             71m
emailservice-7d955f9696-ddx7q           2/2     Running   0             71m
frontend-6b54f89477-67jkp               2/2     Running   0             60m
loadgenerator-748fb7fc95-xzhj8          2/2     Running   0             71m
paymentservice-5f897b99d9-xswfc         2/2     Running   0             71m
productcatalogservice-ccbbf994f-z6lxz   2/2     Running   0             71m
recommendationservice-b75d7cc-94z57     2/2     Running   0             71m
shippingservice-6b6f9d74d7-dr6v2        2/2     Running   0             71m
```

   Проверка работы "argocd-image-updater".
   Загрузили в докерхаб образы для всех деплойментов с тегом 'v0.0.11'.

   Через некторое время "argocd-image-updater" обнаружил новый тег и сделал коммит в каждый хелм чарт.

   Пример коммита:
```console
commit 03b72b51a0da2af9d802fc0630ae46331f095fb3 (HEAD -> main, origin/main, origin/HEAD)
Author: argocd-image-updater <noreply@argoproj.io>
Date:   Sat Jan 14 20:55:00 2023 +0000

    build: automatic update of shippingservice
    
    updates image vradnit/shippingservice tag 'v0.0.9' to 'v0.0.11'

diff --git a/deploy/charts/shippingservice/.argocd-source-shippingservice.yaml b/deploy/charts/shippingservice/.argocd-source-shippingservice.yaml
index 160cb53..c23e33b 100644
--- a/deploy/charts/shippingservice/.argocd-source-shippingservice.yaml
+++ b/deploy/charts/shippingservice/.argocd-source-shippingservice.yaml
@@ -4,5 +4,5 @@ helm:
     value: vradnit/shippingservice
     forcestring: true
   - name: image.tag
-    value: v0.0.9
+    value: v0.0.11
     forcestring: true
```

   Через некторое время "argocd-repo-server" обнаружил новый коммит и "оттемплейтил" helm chart с новыми параметрами.
   Логи "argocd-image-updater" и "argocd-repo-server" приведены в файлах:
```console
argocd/log_argocd-image-updater.log
agocd/log_argocd-repo-server.log
```   

   На этом этапе мы установили argocd и настроили его на работу с argocd-image-updater


