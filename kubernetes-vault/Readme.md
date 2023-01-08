#ДЗ-11 Kubernetes-vault

1. Устанавливаем helm + consul.

Устанавливаем плагин "helm-git" для helm:

```console
# helm plugin install https://github.com/aslafy-z/helm-git --version 0.14.0
Installed plugin: helm-git
```
Создаем helmfile: kubernetes-vault/helmfile-vault.yaml

Устанавливаем consul и vault:
```console
#helmfile -f helmfile-vault.yaml apply 
```

Вывод "helm status"
```console
# helm status vault -n vault
NAME: vault
LAST DEPLOYED: Mon Dec 26 14:52:58 2022
NAMESPACE: vault
STATUS: deployed
REVISION: 1
NOTES:
Thank you for installing HashiCorp Vault!

Now that you have deployed Vault, you should look over the docs on using
Vault with Kubernetes available here:

https://www.vaultproject.io/docs/


Your release is named vault. To learn more about the release, try:

  $ helm status vault
  $ helm get manifest vault
```

Вывод "kubectl logs vault-0"
```console
# kubectl logs vault-0 -n vault | tail -n 2
2022-12-26T12:04:51.859Z [INFO]  core: security barrier not initialized
2022-12-26T12:04:51.861Z [INFO]  core: seal configuration missing, not initialized
```

Текущий статус подов:
```console
# k get pods -n vault
NAME                                  READY   STATUS    RESTARTS   AGE
consul-consul-7pdlp                   1/1     Running   0          12m
consul-consul-chz5x                   1/1     Running   0          12m
consul-consul-m95rt                   1/1     Running   0          12m
consul-consul-server-0                1/1     Running   0          12m
consul-consul-server-1                1/1     Running   0          12m
consul-consul-server-2                1/1     Running   0          12m
consul-consul-zr7m2                   1/1     Running   0          12m
vault-0                               0/1     Running   0          12m
vault-1                               0/1     Running   0          12m
vault-2                               0/1     Running   0          12m
vault-agent-injector-5775f68f-znh2d   1/1     Running   0          12m
```


2. Инициализация vault
```console
# kubectl exec -it -n vault vault-0 -- vault operator init --key-shares=1 --key-threshold=1
Unseal Key 1: /rI2lB2cia++UGkQ0JF3P+rsNAJE6ekMqBoQU3vLKE4=

Initial Root Token: hvs.YwfppIZj6MeG3RN9UiovgCAk

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

Просматриваем логи:
```console
#kubectl logs vault-0 -n vault
2022-12-26T12:06:24.090Z [INFO]  core: security barrier initialized: stored=1 shares=1 threshold=1
2022-12-26T12:06:24.234Z [INFO]  core: post-unseal setup starting
2022-12-26T12:06:24.284Z [INFO]  core: loaded wrapping token key
2022-12-26T12:06:24.304Z [INFO]  core: Recorded vault version: vault version=1.12.1 upgrade time="2022-12-26 12:06:24.284989319 +0000 UTC" build date=2022-10-27T12:32:05Z
2022-12-26T12:06:24.306Z [INFO]  core: successfully setup plugin catalog: plugin-directory=""
2022-12-26T12:06:24.311Z [INFO]  core: no mounts; adding default mount table
2022-12-26T12:06:24.402Z [INFO]  core: successfully mounted backend: type=cubbyhole version="" path=cubbyhole/
2022-12-26T12:06:24.419Z [INFO]  core: successfully mounted backend: type=system version="" path=sys/
2022-12-26T12:06:24.420Z [INFO]  core: successfully mounted backend: type=identity version="" path=identity/
2022-12-26T12:06:24.612Z [INFO]  core: successfully enabled credential backend: type=token version="" path=token/ namespace="ID: root. Path: "
2022-12-26T12:06:24.699Z [INFO]  rollback: starting rollback manager
2022-12-26T12:06:24.700Z [INFO]  core: restoring leases
2022-12-26T12:06:24.703Z [INFO]  expiration: lease restore complete
2022-12-26T12:06:24.769Z [INFO]  identity: entities restored
2022-12-26T12:06:24.787Z [INFO]  identity: groups restored
2022-12-26T12:06:24.815Z [INFO]  core: usage gauge collection is disabled
2022-12-26T12:06:27.237Z [INFO]  core: post-unseal setup complete
2022-12-26T12:06:27.322Z [INFO]  core: root token generated
2022-12-26T12:06:27.322Z [INFO]  core: pre-seal teardown starting
2022-12-26T12:06:27.323Z [INFO]  rollback: stopping rollback manager
2022-12-26T12:06:27.324Z [INFO]  core: pre-seal teardown complete
```

Проверяем статус vault, и обращаем внимание на "Initialized" и "Sealed":
```console
# kubectl exec -it vault-0 -n vault -- vault status
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.12.1
Build Date         2022-10-27T12:32:05Z
Storage Type       consul
HA Enabled         true
command terminated with exit code 2
```

Обращаем внимание на переменные окружения в подах:
```console
# kubectl exec -n vault -it vault-0 -- env | grep VAULT 
VAULT_K8S_POD_NAME=vault-0
VAULT_ADDR=http://127.0.0.1:8200
VAULT_CLUSTER_ADDR=https://vault-0.vault-internal:8201
VAULT_K8S_NAMESPACE=vault
VAULT_API_ADDR=http://10.244.196.89:8200
VAULT_UI_PORT_8200_TCP=tcp://10.104.133.234:8200
VAULT_SERVICE_HOST=10.111.120.200
VAULT_SERVICE_PORT=8200
VAULT_PORT_8200_TCP_PORT=8200
VAULT_PORT_8201_TCP_ADDR=10.111.120.200
VAULT_ACTIVE_SERVICE_PORT_HTTPS_INTERNAL=8201
VAULT_AGENT_INJECTOR_SVC_PORT=tcp://10.109.68.197:443
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP_ADDR=10.109.68.197
VAULT_UI_PORT_8200_TCP_PROTO=tcp
VAULT_STANDBY_SERVICE_PORT=8200
VAULT_STANDBY_PORT_8201_TCP=tcp://10.108.9.240:8201
VAULT_PORT_8200_TCP=tcp://10.111.120.200:8200
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP=tcp://10.109.68.197:443
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP_PORT=443
VAULT_ACTIVE_PORT_8201_TCP_PORT=8201
VAULT_ACTIVE_PORT_8201_TCP_ADDR=10.109.213.74
VAULT_AGENT_INJECTOR_SVC_PORT_443_TCP_PROTO=tcp
VAULT_UI_SERVICE_HOST=10.104.133.234
VAULT_STANDBY_PORT_8200_TCP_PROTO=tcp
VAULT_AGENT_INJECTOR_SVC_SERVICE_PORT=443
VAULT_UI_PORT_8200_TCP_PORT=8200
VAULT_ACTIVE_PORT=tcp://10.109.213.74:8200
VAULT_ACTIVE_PORT_8200_TCP_PORT=8200
VAULT_STANDBY_PORT=tcp://10.108.9.240:8200
VAULT_STANDBY_PORT_8201_TCP_PROTO=tcp
VAULT_SERVICE_PORT_HTTPS_INTERNAL=8201
VAULT_PORT=tcp://10.111.120.200:8200
VAULT_UI_SERVICE_PORT_HTTP=8200
VAULT_ACTIVE_SERVICE_HOST=10.109.213.74
VAULT_STANDBY_SERVICE_PORT_HTTP=8200
VAULT_STANDBY_SERVICE_PORT_HTTPS_INTERNAL=8201
VAULT_STANDBY_PORT_8201_TCP_PORT=8201
VAULT_PORT_8201_TCP=tcp://10.111.120.200:8201
VAULT_STANDBY_PORT_8200_TCP=tcp://10.108.9.240:8200
VAULT_PORT_8201_TCP_PROTO=tcp
VAULT_ACTIVE_PORT_8201_TCP=tcp://10.109.213.74:8201
VAULT_STANDBY_PORT_8201_TCP_ADDR=10.108.9.240
VAULT_SERVICE_PORT_HTTP=8200
VAULT_UI_PORT_8200_TCP_ADDR=10.104.133.234
VAULT_ACTIVE_PORT_8200_TCP_PROTO=tcp
VAULT_ACTIVE_PORT_8200_TCP_ADDR=10.109.213.74
VAULT_PORT_8200_TCP_PROTO=tcp
VAULT_AGENT_INJECTOR_SVC_SERVICE_HOST=10.109.68.197
VAULT_ACTIVE_PORT_8201_TCP_PROTO=tcp
VAULT_PORT_8200_TCP_ADDR=10.111.120.200
VAULT_AGENT_INJECTOR_SVC_SERVICE_PORT_HTTPS=443
VAULT_ACTIVE_SERVICE_PORT_HTTP=8200
VAULT_ACTIVE_PORT_8200_TCP=tcp://10.109.213.74:8200
VAULT_UI_SERVICE_PORT=8200
VAULT_ACTIVE_SERVICE_PORT=8200
VAULT_STANDBY_SERVICE_HOST=10.108.9.240
VAULT_STANDBY_PORT_8200_TCP_PORT=8200
VAULT_STANDBY_PORT_8200_TCP_ADDR=10.108.9.240
VAULT_PORT_8201_TCP_PORT=8201
VAULT_UI_PORT=tcp://10.104.133.234:8200
```


Рапечатываем поды:
```console
# kubectl exec -n vault -it vault-0 -- vault operator unseal '/rI2lB2cia++UGkQ0JF3P+rsNAJE6ekMqBoQU3vLKE4='
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.12.1
Build Date      2022-10-27T12:32:05Z
Storage Type    consul
Cluster Name    vault-cluster-7f7c0326
Cluster ID      ed7af884-bfa8-d0a0-af26-d6ca8ac87c62
HA Enabled      true
HA Cluster      https://vault-0.vault-internal:8201
HA Mode         active
Active Since    2022-12-26T12:20:22.194362848Z
# kubectl exec -n vault -it vault-1 -- vault operator unseal '/rI2lB2cia++UGkQ0JF3P+rsNAJE6ekMqBoQU3vLKE4='
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.12.1
Build Date             2022-10-27T12:32:05Z
Storage Type           consul
Cluster Name           vault-cluster-7f7c0326
Cluster ID             ed7af884-bfa8-d0a0-af26-d6ca8ac87c62
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.244.196.89:8200
# kubectl exec -n vault -it vault-2 -- vault operator unseal '/rI2lB2cia++UGkQ0JF3P+rsNAJE6ekMqBoQU3vLKE4='
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.12.1
Build Date             2022-10-27T12:32:05Z
Storage Type           consul
Cluster Name           vault-cluster-7f7c0326
Cluster ID             ed7af884-bfa8-d0a0-af26-d6ca8ac87c62
HA Enabled             true
HA Cluster             n/a
HA Mode                standby
Active Node Address    <none>
```


Проверяем текущий статус "vault status"
```console
# kubectl exec -n vault -it vault-0 -- vault status
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.12.1
Build Date             2022-10-27T12:32:05Z
Storage Type           consul
Cluster Name           vault-cluster-7f7c0326
Cluster ID             ed7af884-bfa8-d0a0-af26-d6ca8ac87c62
HA Enabled             true
HA Cluster             https://vault-1.vault-internal:8201
HA Mode                standby
Active Node Address    http://10.244.133.169:8200
```

Текущее состояние подов:
```console
# k get pods -n vault 
NAME                                  READY   STATUS    RESTARTS   AGE
consul-consul-7pdlp                   1/1     Running   0          34m
consul-consul-chz5x                   1/1     Running   0          34m
consul-consul-m95rt                   1/1     Running   0          34m
consul-consul-server-0                1/1     Running   0          34m
consul-consul-server-1                1/1     Running   0          34m
consul-consul-server-2                1/1     Running   0          34m
consul-consul-zr7m2                   1/1     Running   0          34m
vault-0                               1/1     Running   0          34m
vault-1                               1/1     Running   0          34m
vault-2                               1/1     Running   0          34m
vault-agent-injector-5775f68f-znh2d   1/1     Running   0          34m
```

3. Смотрим текущий список авторизаций:
```console
# kubectl exec -n vault -it vault-0 -- vault auth list
Error listing enabled authentications: Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/auth
Code: 403. Errors:

* permission denied
command terminated with exit code 2
```

Логинимся в под vault (используя token root):
```console
# kubectl exec -n vault -it vault-0 -- vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.YwfppIZj6MeG3RN9UiovgCAk
token_accessor       osidIgvh1XMZhvpykhyeGijT
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```

Повторно смотрим текущий список автоизаций:
```console
# kubectl exec -n vault -it vault-0 -- vault auth list
Path      Type     Accessor               Description                Version
----      ----     --------               -----------                -------
token/    token    auth_token_e7bb3b61    token based credentials    n/a
```


4. Создаем секреты:
```console
# kubectl exec -it vault-0 -- vault secrets enable --path=otus kv
Success! Enabled the kv secrets engine at: otus/
# 
# kubectl exec -it vault-0 -- vault secrets list --detailed
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options    Description                                                UUID                                    Version    Running Version          Running SHA256    Deprecation Status
----          ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------    -----------                                                ----                                    -------    ---------------          --------------    ------------------
cubbyhole/    cubbyhole    cubbyhole_643fe208    n/a            n/a        false             local          false        false                      map[]      per-token private secret storage                           2ed3f335-cbaa-8fe7-94ca-0f0e09e7bfb9    n/a        v1.12.1+builtin.vault    n/a               n/a
identity/     identity     identity_64e292c7     system         system     false             replicated     false        false                      map[]      identity store                                             df4fe5ac-2e4a-1076-a6eb-2288689d9af8    n/a        v1.12.1+builtin.vault    n/a               n/a
otus/         kv           kv_582a9d75           system         system     false             replicated     false        false                      map[]      n/a                                                        28478ee5-b12a-ea3b-8d6e-aa834d37489f    n/a        v0.13.0+builtin          n/a               supported
sys/          system       system_4f741b7b       n/a            n/a        false             replicated     true         false                      map[]      system endpoints used for control, policy and debugging    ca313b5b-ba98-8e16-9e9f-841bc54037ca    n/a        v1.12.1+builtin.vault    n/a               n/a
# 
# 
# kubectl exec -it vault-0 -- vault kv put otus/otus-ro/config username='otus' password='asajkjkahs'
Success! Data written to: otus/otus-ro/config
# 
# kubectl exec -it vault-0 -- vault kv put otus/otus-rw/config username='otus' password='asajkjkahs'
Success! Data written to: otus/otus-rw/config
```


Проверяем, что секреты созданы:
```console
# kubectl exec -it vault-0 -- vault read otus/otus-ro/config
Key                 Value
---                 -----
refresh_interval    768h
password            asajkjkahs
username            otus
# 
# kubectl exec -it vault-0 -- vault kv get otus/otus-rw/config
====== Data ======
Key         Value
---         -----
password    asajkjkahs
username    otus
```


5. Включаем авторизацию через k8s:
```console
# kubectl exec -it vault-0 -- vault auth enable kubernetes
Success! Enabled kubernetes auth method at: kubernetes/
# 
# kubectl exec -it vault-0 -- vault auth list
Path           Type          Accessor                    Description                Version
----           ----          --------                    -----------                -------
kubernetes/    kubernetes    auth_kubernetes_73dc200e    n/a                        n/a
token/         token         auth_token_e7bb3b61         token based credentials    n/a
```

Создаем манифесты: 
  - serviceaccount "vault-auth"
  - clusterrolebinding "role-tokenreview-binding"
  - secret "vault-auth-token" , т.к. "This means, in Kubernetes 1.24, you need to manually create the Secret; the token key in the data field will be automatically set for you."
    https://stackoverflow.com/questions/72256006/service-account-secret-is-not-listed-how-to-fix-it
    https://kubernetes.io/docs/concepts/configuration/secret/#service-account-token-secrets
в директории "kubernetes-vault/k8s-auth/" и применяем их:
```console
# k create -f ./k8s-auth/
clusterrolebinding.rbac.authorization.k8s.io/role-tokenreview-binding created
secret/vault-auth-token created
serviceaccount/vault-auth created
```

Подготавливаем переменные для записи в конфиг кубер авторизации:
```console
export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
export K8S_HOST=$(kubectl cluster-info | grep 'Kubernetes control plane' | awk '/https/ {print $NF}' | sed 's/\x1b\[[0-9;]*m//g')
```

Конструкция "sed 's/\x1b\[[0-9;]*m//g'" удаляет "псевдосимволы колоризации консоли"


Записываем конфиг в vault:
```console
# kubectl exec -it vault-0 -- vault write auth/kubernetes/config token_reviewer_jwt="$SA_JWT_TOKEN" kubernetes_host="$K8S_HOST" kubernetes_ca_cert="$SA_CA_CRT"
Success! Data written to: auth/kubernetes/config
```

Создаем файл политики: "kubernetes-vault/k8s-auth/otus-policy.hcl"
```console
path "otus/otus-ro/*" {
    capabilities = ["read", "list"]
}
path "otus/otus-rw/*" {
    capabilities = ["read", "create", "list", "update"]
}
```

Создаем политику и роль в vault:
```console
# kubectl cp k8s-auth/otus-policy.hcl vault-0:/tmp/
# kubectl exec -it vault-0 -- vault policy write otus-policy /tmp/otus-policy.hcl
Success! Uploaded policy: otus-policy
# kubectl exec -it vault-0 -- vault write auth/kubernetes/role/otus bound_service_account_names=vault-auth bound_service_account_namespaces=vault policies=otus-policy ttl=24h
Success! Data written to: auth/kubernetes/role/otus
```

Создаем тестовый манифест пода "pod-tmp-apline", в котором используется serviceacount "vault-auth"
Применяем его, и устанавливаем в нем пакеты "curl jq" 
```console
#kubectl apply -f k8s-auth/pod-tmp-apline.yaml
#kubectl exec -it pod-tmp-apline -- apk add curl jq
```

Логинимся в под и получаем клиентский токен:
( в ДЗ "ошибка" и имени роли 'test'--'otus' )

```console
# VAULT_ADDR=http://vault:8200
# KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
# curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq
{
  "request_id": "7e1e3654-a5ab-f10a-8d88-563f4c0ff598",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": null,
  "wrap_info": null,
  "warnings": null,
  "auth": {
    "client_token": "hvs.CAESIGhgOariBryjg_JsogKWFn9imPGWDefXb2WwpRkDt2i_Gh4KHGh2cy5xaDZIWkVhOFVJUjU2VUFCZENUTXZ0U00",
    "accessor": "LR99jcaEFF5eaJzJjwoc9wl1",
    "policies": [
      "default",
      "otus-policy"
    ],
    "token_policies": [
      "default",
      "otus-policy"
    ],
    "metadata": {
      "role": "otus",
      "service_account_name": "vault-auth",
      "service_account_namespace": "vault",
      "service_account_secret_name": "",
      "service_account_uid": "ce698cd0-072c-4b35-a397-d6f9048299ac"
    },
    "lease_duration": 86400,
    "renewable": true,
    "entity_id": "a2b17e36-8af9-11df-c28e-654f54298e3c",
    "token_type": "service",
    "orphan": true,
    "mfa_requirement": null,
    "num_uses": 0
  }
}
# 
# TOKEN=$(curl -k -s --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' $VAULT_ADDR/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')
# 
# echo $TOKEN
hvs.CAESIJdGqszKjboZVpal6gNhlp3R8UG0NEaka6SvF8u-4b1XGh4KHGh2cy5MMUZQWVFEQ05JUWJ5M0VtTlBLVkhDbjc
``` 

Проверяем чтение и запись секретов:
```console
# curl --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-ro/config
{"request_id":"d6531fd6-7903-d63c-dcbf-b691860922bc","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"asajkjkahs","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
# 
# curl --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-rw/config
{"request_id":"6b2aa764-3061-1ebd-8c14-bbae1b254fec","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"password":"asajkjkahs","username":"otus"},"wrap_info":null,"warnings":null,"auth":null}
# 
# curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-ro/
config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
# 
# curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-rw/
config
{"errors":["1 error occurred:\n\t* permission denied\n\n"]}
# 
# curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-rw/
config1
# 
```

Мы смогли прочитать секреты и смогли создать новый секрет, но не смогли обновить существуюший секрет, т.к. в политике не объявлен метод "update"
Изменяем политику:
```console
# diff -rNu ./k8s-auth/otus-policy.hcl.old ./k8s-auth/otus-policy.hcl
--- ./k8s-auth/otus-policy.hcl.old	2022-12-26 21:49:15.815239819 +0300
+++ ./k8s-auth/otus-policy.hcl	2022-12-26 21:49:36.059386391 +0300
@@ -2,5 +2,5 @@
     capabilities = ["read", "list"]
 }
 path "otus/otus-rw/*" {
-    capabilities = ["read", "create", "list"]
+    capabilities = ["read", "create", "list", "update"]
 }
```

Обновляем политику
```console
# kubectl cp k8s-auth/otus-policy.hcl vault-0:/tmp/
# kubectl exec -it vault-0 -- vault policy write otus-policy /tmp/otus-policy.hcl
Success! Uploaded policy: otus-policy
#
```

Проверяем доступность записи секретов "otus-rw/config1" и "otus-rw/config"
```console
# 
# curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-rw/config1
# curl --request POST --data '{"bar": "baz"}' --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-rw/config
#
# curl --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-rw/config
{"request_id":"dfd46a4b-70f2-d7a8-85d5-973a4852141c","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"bar":"baz"},"wrap_info":null,"warnings":null,"auth":null}
# 
# curl --header "X-Vault-Token: hvs.CAESIBh2GBlyf4kqM-RaT8II-YnxMfe4dIAXbLCuLIKDXLrcGh4KHGh2cy5jTTJmWFpHaTVwODVYalBGWFFDaWxmQjk" $VAULT_ADDR/v1/otus/otus-rw/config1
{"request_id":"b460f030-ba40-17bc-bc54-73d811d5ab61","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"bar":"baz"},"wrap_info":null,"warnings":null,"auth":null}
#
```

6 Use case использования авторизации через k8s:
  - авторизуемся через vault-agent и получим клиентский токен
  - через consul-template достанем секрет и положим его в nginx
  - в итоге nginx получит секрет, ничего не зная про vault

Забираем репозиторий с примером:
```console
git clone https://github.com/hashicorp/vault-guides.git
cd vault-guides/identity/vault-agent-k8s-demo
```

В директории "kubernetes-vault/configs-k8s" скорректируем и сохраним конфиги vault-agent и consul-template:
```console
# kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/ --dry-run=client -o yaml > example-vault-agent-config.yaml

# kubectl apply -f example-vault-agent-config.yaml
# kubectl apply -f example-k8s-spec.yaml
```

Итоговые манифесты сохранены в:
    "kubernetes-vault/example-vault-agent-config.yaml"
    "kubernetes-vault/example-k8s-spec.yaml"
```console
# cat example-vault-agent-config.yaml
apiVersion: v1
data:
  consul-template-config.hcl: |
    vault {
      renew_token = false
      vault_agent_token_file = "/home/vault/.vault-token"
      retry {
        backoff = "250ms"
        max_backoff = "5m"
      }
    }

    template {
      destination = "/etc/secrets/index.html"
      contents = <<EOT
    <html>
    <body>
    <p>Some secrets:</p>
    {{- with secret "otus/otus-ro/config" }}
    <ul>
    <li><pre>username: {{ .Data.username }}</pre></li>
    <li><pre>password: {{ .Data.password }}</pre></li>
    </ul>
    {{- end }}
    </body>
    </html>
    EOT
    }
  vault-agent-config.hcl: |
    # Comment this out if running as sidecar instead of initContainer
    exit_after_auth = true

    pid_file = "/home/vault/pidfile"

    auto_auth {
        method "kubernetes" {
            mount_path = "auth/kubernetes"
            config = {
                role = "otus"
            }
        }

        sink "file" {
            config = {
                path = "/home/vault/.vault-token"
            }
        }
    }
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: example-vault-agent-config
# 
# 
# cat example-k8s-spec.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: vault-agent-example
  namespace: vault
spec:
  serviceAccountName: vault-auth

  volumes:
  - configMap:
      items:
      - key: vault-agent-config.hcl
        path: vault-agent-config.hcl
      - key: consul-template-config.hcl
        path: consul-template-config.hcl
      name: example-vault-agent-config
    name: config
  - emptyDir: {}
    name: shared-data
  - emptyDir: {}
    name: token
  initContainers:
  - name: vault-agent
    image: vault
    args:
    - agent
    - -config=/etc/vault/vault-agent-config.hcl
    - -log-level=debug
    env:
    - name: SKIP_SETCAP
      value: "true"
    - name: VAULT_ADDR
      value: http://vault:8200
    volumeMounts:
    - mountPath: /etc/vault/vault-agent-config.hcl
      subPath: vault-agent-config.hcl
      name: config
    - mountPath: /home/vault
      name: token
  containers:
  - name: consul-template
    image: hashicorp/consul-template:alpine
    args:
    - -config=/etc/consul-template/consul-template-config.hcl
    env:
    - name: VAULT_ADDR
      value: http://vault:8200
    volumeMounts:
    - mountPath: /etc/consul-template/consul-template-config.hcl
      subPath: consul-template-config.hcl
      name: config
    - mountPath: /home/vault
      name: token
    - mountPath: /etc/secrets
      name: shared-data
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: shared-data
```


Проверяем доступность nginx и скачиваем index.html
```console
# k get pods | grep vault-agent-example
vault-agent-example                   2/2     Running   0              12m
 
# k port-forward pod/vault-agent-example 8080:80 &
[1] 12824
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80

# curl -s http://127.0.0.1:8080 -o index.html
Handling connection for 8080
 
# cat index.html
<html>
<body>
<p>Some secrets:</p>
<ul>
<li><pre>username: otus</pre></li>
<li><pre>password: asajkjkahs</pre></li>
</ul>
</body>
</html>
```


6. Создание CA на основе Vault

Включаем pki сервис и генерируем CA сертификат:
```console
# kubectl exec -it vault-0 -- vault secrets enable pki
Success! Enabled the pki secrets engine at: pki/
# 
# kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
Success! Tuned the secrets engine at: pki/
# 
# kubectl exec -it vault-0 -- vault write -field=certificate pki/root/generate/internal common_name="example.ru" ttl=87600h > CA_cert.crt
```

Прописываем url для CA и отозванных сертификатов:
```console
# kubectl exec -it vault-0 -- vault write pki/config/urls issuing_certificates="http://vault:8200/v1/pki/ca" crl_distribution_points="http://vault:8200/v1/pki/crl"
Success! Data written to: pki/config/urls
```

Создадим промежуточный сертификат:
```console
# kubectl exec -it vault-0 -- vault secrets enable --path=pki_int pki
Success! Enabled the pki secrets engine at: pki_int/
# kubectl exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki_int
Success! Tuned the secrets engine at: pki_int/
# kubectl exec -it vault-0 -- vault write -format=json pki_int/intermediate/generate/internal common_name="example.ru Intermediate Authority" | jq -r '.data.csr' > pki_intermediate.csr
```

Прописываем промежуточный сертификат в vault:
```console
# kubectl cp pki_intermediate.csr vault-0:/tmp/
# kubectl exec -it vault-0 -- vault write -format=json pki/root/sign-intermediate csr=@/tmp/pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > intermediate.cert.pem
# kubectl cp intermediate.cert.pem vault-0:/tmp/
# kubectl exec -it vault-0 -- vault write pki_int/intermediate/set-signed certificate=@/tmp/intermediate.cert.pem
WARNING! The following warnings were returned from Vault:

  * This mount hasn't configured any authority information access (AIA)
  fields; this may make it harder for systems to find missing certificates
  in the chain or to validate revocation status of certificates. Consider
  updating /config/urls or the newly generated issuer with this information.

Key                 Value
---                 -----
imported_issuers    [21a429c1-6eb9-61bd-a499-7cd0ddcdb882 735b7fa8-1880-9fea-ff92-633110a67f6d]
imported_keys       <nil>
mapping             map[21a429c1-6eb9-61bd-a499-7cd0ddcdb882:d1b1856e-f2ee-2d99-0132-e845b1750184 735b7fa8-1880-9fea-ff92-633110a67f6d:]
```

Создадим роль для выдачи сертификатов:
```console
# kubectl exec -it vault-0 -- vault write pki_int/roles/example-dot-ru allowed_domains="example.ru" allow_subdomains=true max_ttl="720h"
Success! Data written to: pki_int/roles/example-dot-ru
```

Создадим и отзовем сертификат
```console
# kubectl exec -it vault-0 -- vault write pki_int/issue/example-dot-ru common_name="gitlab.example.ru" ttl="24h"
Key                 Value
---                 -----
ca_chain            [-----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUPG5WBdarVNqh6x0UGCr0E9EV2ecwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhhbXBsZS5ydTAeFw0yMjEyMzAxMjE4NTBaFw0yNzEy
MjkxMjE5MjBaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKbGQoWppNot
0YgWX5vJATshn+7Ab710aVVcYrQA1PWD+AHHhjMNl8F1VO/iWRtRDq9uJAxJSHf6
0ZMVDKKSGWZVkTLbbuPmsPNQkTJcRTcTY91pN5m+dA6ifya3/U2cAvHdNCG7wejD
8Unsqm5y2oLcYcLJEE/rANRGk+1Dz9LBLBqfkP70mDxQ5/UmSmULMWAS3t1mEg0r
jpH3UgtwNcbpieaiINc3vYTnKse81VBmoQDFhpnTRtJZrgRQfapnau2i+dbGX9YZ
iyLvRgvt6K3hD62MFHwHoICP4gJWfAbESLFUZCA9A+qhYKyMXE4HJPSDpykUw5F0
W74QTd+hPrcCAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUigK7uCMbyQnJn8Ju8DCWTVtp8qowHwYDVR0jBBgwFoAU
YOljUtgVC5TY3O+THGQT/YHP24kwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
Y8nrk6Je2Yw+NTELekLZr/6VUkqihtI4Cch1WQrxMio8ZNZ0POy34zYVt1/g4Hzf
fFrYDEnOWKEKNg5CasMLa/rMkXnBM2o7uyYp2AfR/3x865X82TJb56aV/k8rNq7K
xIdd0UGU5PYjzD382FlEToxr9tqqd/eShrnR83zH3bPYYBckcmC8umsqqNVGL8xQ
QPi19EuGInZajN7dBvk/zUVzOrgwr4fQjpfccYGM02TKWMguFlwCOXmc/y9J9857
9qepiLsipWDzDvJHrQVfmn1LW1yiJ6IoKTa4Y8F0K1B7Pg4OJP8/f4nQFMM7kexO
LE4Yk22c8PNIY6eOb52Pmg==
-----END CERTIFICATE----- -----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIUZbxlhP0qOpb8cXEvlhTSKtGESfEwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhhbXBsZS5ydTAeFw0yMjEyMzAxMjEwMzlaFw0zMjEy
MjcxMjExMDlaMBUxEzARBgNVBAMTCmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQC5aliPWlUikr4SHFmNs6Gj1JDys9sxMkuqTVNh2msr
B5+lF+jv2ZSGwOXXuiCbihfE9tYu4Nm4xQWAZjQBhuErU06RGho1WJpfAbyvBRig
fRRbq4DUxNub4N8B/jH0wqPTlDyck47GGKA4PRL7SUNlrhdg0KGW9RuF/ACfjg+e
nd76LXqexY61yYdZ/A+H9J3JbLzsBU389vfATZpgM1crgean0t05rucCFPxLg780
FGeXGMgcs3SJgvzAIKd78QhRFyCU7Mhn6Stnm72ZncqsQgUxVHqUVWgTuBDAM0m5
t9WkEjUgI40klLRg6itCg6hB0xijgdqdAhVaFIn2oMwxAgMBAAGjejB4MA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRg6WNS2BULlNjc
75McZBP9gc/biTAfBgNVHSMEGDAWgBRg6WNS2BULlNjc75McZBP9gc/biTAVBgNV
HREEDjAMggpleGFtcGxlLnJ1MA0GCSqGSIb3DQEBCwUAA4IBAQA2tQrsoRewi2nb
Yd8yuF3w3rCCTOEdLwA+cPHAf04pkBoQvbRVI0eQzaDWEJNetYylrou612RykLJ7
kOhggbV7G4rIM41ADFJ6Lax8aHO5E2kMmsFUSvoOa+l+S/qpMYzLhVYU2JkjB2iw
M91e6ujvWKuP1W93qQlF9No/XzKr/JldVjDOiIgTPha2AHJT1QNgRMeJFmHPxFWb
GMs5xaLr++ISQJ3YM1Obd1sIFb4ysF67qUDFBneUP9HyEvrfHHYRisQKS3Dq71mH
8bnY1vZ7FeSqTAzwi43NiIiP74bEJMHTo+e7dOT3ORSnEYVsKZ08rKkPfcia0uvr
N58SMVyC
-----END CERTIFICATE-----]
certificate         -----BEGIN CERTIFICATE-----
MIIDZzCCAk+gAwIBAgIUcYFmlw3YtXkHCyPxkcknJLMrbYswDQYJKoZIhvcNAQEL
BQAwLDEqMCgGA1UEAxMhZXhhbXBsZS5ydSBJbnRlcm1lZGlhdGUgQXV0aG9yaXR5
MB4XDTIyMTIzMDEyMjcwNVoXDTIyMTIzMTEyMjczNFowHDEaMBgGA1UEAxMRZ2l0
bGFiLmV4YW1wbGUucnUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDC
63e3c28bjdTpxkB5RSSIjMF5sKELTNxmgQcFhRf36RuNyyve/6bIO6AsDwqZYI8K
WXGKetoK5N70mF8hhxoEaJTdzIRyvvOCIeS1iba9SYJtLHgnBrQ2gQvKfMg37qs5
K1KU5oap/3t7Ck9MgkoG7XiU/93zLzdhiorfF2P9ArFktoE9+mZwbMd0vimLGUeq
AesWhVVlINirMaf4TZukzVm6lXT5reakSG/VC1zJE7pmyoKg0aczwH4bsaSCLIvx
0tDajuTXX1BvcOq+AJYE8gKGPEmlQ56naStyyO555zL3ZLevpYw8rdPEJFJB/I4o
cgSFIJPANeTG8xtCKDAzAgMBAAGjgZAwgY0wDgYDVR0PAQH/BAQDAgOoMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUruzMed2a7ybQSTja
tJr7T7Oxh3gwHwYDVR0jBBgwFoAUigK7uCMbyQnJn8Ju8DCWTVtp8qowHAYDVR0R
BBUwE4IRZ2l0bGFiLmV4YW1wbGUucnUwDQYJKoZIhvcNAQELBQADggEBABfN0KYe
cgaUHFyubgmaFXlFoULUj41aY3nG/Ol4TtsynkauyVddY6znzAxUu3Oo89XabwPl
bDDxRf26HN+0Yvvxz01qkq+Tuvm1sHf5FlGhYORGMMkkJgS497H6OTCvi2SDa/YL
D5wl/N2HYk6MtDBCoBSWVzDSXKCqL21WK6f164jfY35ia/gQxZjG3jAnsu434tIr
34HjLO8h9ZeeL4ByOdeMeX6Wr98Li9MJOm4AqWDTNWykmdZE8t+ndWXfm+HaYdcn
nQbCLEODHjO+gba8RhwfqSmTs+hokIJZPfY+bnjZCMBddWXZqdWuf/KZLtLOHXib
B0UAO/KOXFscvCg=
-----END CERTIFICATE-----
expiration          1672489654
issuing_ca          -----BEGIN CERTIFICATE-----
MIIDnDCCAoSgAwIBAgIUPG5WBdarVNqh6x0UGCr0E9EV2ecwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAxMKZXhhbXBsZS5ydTAeFw0yMjEyMzAxMjE4NTBaFw0yNzEy
MjkxMjE5MjBaMCwxKjAoBgNVBAMTIWV4YW1wbGUucnUgSW50ZXJtZWRpYXRlIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKbGQoWppNot
0YgWX5vJATshn+7Ab710aVVcYrQA1PWD+AHHhjMNl8F1VO/iWRtRDq9uJAxJSHf6
0ZMVDKKSGWZVkTLbbuPmsPNQkTJcRTcTY91pN5m+dA6ifya3/U2cAvHdNCG7wejD
8Unsqm5y2oLcYcLJEE/rANRGk+1Dz9LBLBqfkP70mDxQ5/UmSmULMWAS3t1mEg0r
jpH3UgtwNcbpieaiINc3vYTnKse81VBmoQDFhpnTRtJZrgRQfapnau2i+dbGX9YZ
iyLvRgvt6K3hD62MFHwHoICP4gJWfAbESLFUZCA9A+qhYKyMXE4HJPSDpykUw5F0
W74QTd+hPrcCAwEAAaOBzDCByTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zAdBgNVHQ4EFgQUigK7uCMbyQnJn8Ju8DCWTVtp8qowHwYDVR0jBBgwFoAU
YOljUtgVC5TY3O+THGQT/YHP24kwNwYIKwYBBQUHAQEEKzApMCcGCCsGAQUFBzAC
hhtodHRwOi8vdmF1bHQ6ODIwMC92MS9wa2kvY2EwLQYDVR0fBCYwJDAioCCgHoYc
aHR0cDovL3ZhdWx0OjgyMDAvdjEvcGtpL2NybDANBgkqhkiG9w0BAQsFAAOCAQEA
Y8nrk6Je2Yw+NTELekLZr/6VUkqihtI4Cch1WQrxMio8ZNZ0POy34zYVt1/g4Hzf
fFrYDEnOWKEKNg5CasMLa/rMkXnBM2o7uyYp2AfR/3x865X82TJb56aV/k8rNq7K
xIdd0UGU5PYjzD382FlEToxr9tqqd/eShrnR83zH3bPYYBckcmC8umsqqNVGL8xQ
QPi19EuGInZajN7dBvk/zUVzOrgwr4fQjpfccYGM02TKWMguFlwCOXmc/y9J9857
9qepiLsipWDzDvJHrQVfmn1LW1yiJ6IoKTa4Y8F0K1B7Pg4OJP8/f4nQFMM7kexO
LE4Yk22c8PNIY6eOb52Pmg==
-----END CERTIFICATE-----
private_key         -----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAwut3t3NvG43U6cZAeUUkiIzBebChC0zcZoEHBYUX9+kbjcsr
3v+myDugLA8KmWCPCllxinraCuTe9JhfIYcaBGiU3cyEcr7zgiHktYm2vUmCbSx4
Jwa0NoELynzIN+6rOStSlOaGqf97ewpPTIJKBu14lP/d8y83YYqK3xdj/QKxZLaB
PfpmcGzHdL4pixlHqgHrFoVVZSDYqzGn+E2bpM1ZupV0+a3mpEhv1QtcyRO6ZsqC
oNGnM8B+G7GkgiyL8dLQ2o7k119Qb3DqvgCWBPIChjxJpUOep2krcsjueecy92S3
r6WMPK3TxCRSQfyOKHIEhSCTwDXkxvMbQigwMwIDAQABAoIBAD8S4QdtBBwfdjE7
pOtZE2xYV9cf78zvTzagM/x2R/5B4Vet0gF0Kq0KllcLevuMwlyv+sy72kjCLN9r
WwVHaYTZrqpjHszeu391pkOUT5zK57iaNjsysSgd9AnO/R8UTTXPrgZe3l6uPG/h
My3nzzqUp3tXnKOvuLUIls2ADSv2nHRkoz8B+w7PwwZR8/pY+f1NlQP+BsKqIAZD
slDXA4xR56necKPH7Oy0L7KaxKWv8v+HvHumgJY3p6JJ0irwmS+JQwm2Ojc+mLSt
/St6veadcQWMFOvDoGxKC/6LU6VpXatCpx7PncvGfuBU0IpP2zt4P9Z3If4FkW01
wD1q6DkCgYEAxYZgT0tIb1JdYFTFTr/c1ySnGiVibUki+gp9r8mrOFJM6Hjl1kJN
ZQK5cz1ReHEnnNv2rNEvE24HNyirXgOa2FfPH0coolkik6HHEnNsKtez94UR/6eN
YdmKmPGLsyAcI9XCPkmj9kflW55uU/yL2P/qtAVzEbmVfqZJ8D8wU50CgYEA/J+p
EfmV02yvFh/NqMcxVGcuY6bfP71v5pDqt/3ZdynsivKLSm43ig+70Lo4h+gVuseZ
Olyka9r3dYvCcK/oe2IR29BxFrdZh1LHh84Zg6dE1OBLFOP07z7zDd5IRmMi6hao
ZY81mC9HKe0ZcJADW4khf/SHtOGVoDGxCH9HUg8CgYEAoXgV5vw9vHLyTjs+CAAj
weP+jgsdiQUOiKRm1nrfcu0kXa3nBN2ycu5lN2Va4kBuB3ZxEhj2iMWbNGYUoIgF
3vD5KjJ7byu6bkEDgXvFYshuH9syOXF4zBKPkDN05ftLxaeKYGzGkh93yQucWR/M
Gpop/Puvcz/oi13Yd4LQOKkCgYEAjHTg9eOFEBY/iteH6y1FGh58Rl/DhJb5HoK4
XjA/tueSYvbTx0BclOCGlljTkYzSeBT99tsHeAg4yhw4sZq8cc1nDIZqOi0bFAhM
dA99VBuuQ4WpeSX9Sv/+91j9alU4VlreqgjjzYeL053GJTWNCFnITHJS+ZjrLjQy
r/zEVLUCgYBJAYvoMyQybe0AbbMO41uRczPqXN0NMcg1ZsbtmVuCottYbXeYTAuS
Jfz4WvDwfkhLj3k8aGZ0OkTwBVqdzPOwwixD2fgoxAoJRtaLBJhVhAHlhjhrEP8W
SyC2vWO6/2Ql+iqMx7Pi5RYcJEF7/zJUBqo7xIb2w+brU19ABCuDsw==
-----END RSA PRIVATE KEY-----
private_key_type    rsa
serial_number       71:81:66:97:0d:d8:b5:79:07:0b:23:f1:91:c9:27:24:b3:2b:6d:8b
# 
# kubectl exec -it vault-0 -- vault write pki_int/revoke serial_number="71:81:66:97:0d:d8:b5:79:07:0b:23:f1:91:c9:27:24:b3:2b:6d:8b"
Key                        Value
---                        -----
revocation_time            1672403294
revocation_time_rfc3339    2022-12-30T12:28:14.133227779Z
```



7. Конфигурирование доступа к vault по https.
   За основу возьмем документацию с: https://developer.hashicorp.com/vault/docs/platform/k8s/helm/examples/standalone-tls
   
   В директории "kubernetes-vault/vault-with-tls" создадим скрипт, в который сведем действия по генерации ssl ключей, сертификатов и секрета:
```console
# cd ./kubernetes-vault/vault-with-tls
# ./prepare-tls.sh
```

   В результате у нас появляется:
   - сертификат "vault-csr" в статусе "Approved,Issued"
   - секрет "vault-server-tls", которые мы будем монтировать в поды vault

```console
# k get csr -n vault 
NAME        AGE    SIGNERNAME                      REQUESTOR          REQUESTEDDURATION   CONDITION
vault-csr   107m   kubernetes.io/kubelet-serving   kubernetes-admin   <none>              Approved,Issued

# k get secret vault-server-tls  -n vault 
NAME               TYPE     DATA   AGE
vault-server-tls   Opaque   3      107m
```
  
   Затем мы подготавливаем helmfile + values:
   ( где учитываем что у нас используется consul в качестве storage )
   ./kubernetes-vault/vault-with-tls/helmfile-vault-tls.yaml
   ./kubernetes-vault/vault-with-tls/values-tls.yaml

   Применяем:
```console
# helmfile -f helmfile-vault-tls.yaml apply
```
   
   Затем рестартуем поды vault и в них делаем "unseal"
   Проверяем статус vault, видим что http сменилось на https: 
```console
# kubectl exec -n vault -it vault-2 -- vault status
Key                    Value
---                    -----
Seal Type              shamir
Initialized            true
Sealed                 false
Total Shares           1
Threshold              1
Version                1.12.1
Build Date             2022-10-27T12:32:05Z
Storage Type           consul
Cluster Name           vault-cluster-7f7c0326
Cluster ID             ed7af884-bfa8-d0a0-af26-d6ca8ac87c62
HA Enabled             true
HA Cluster             https://vault-0.vault-internal:8201
HA Mode                standby
Active Node Address    https://10.244.196.76:8200
```

   С помощью нашего тестового пода "pod-tmp-apline" проверяем работу по https: 
```console
# 
# KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
# CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
# 
# curl -s --cacert ${CACERT} --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' https://vault:8200/v1/auth/kubernetes/login | jq
{
  "request_id": "1286a9bc-bdd4-2cdf-c199-0c6bc8334075",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": null,
  "wrap_info": null,
  "warnings": null,
  "auth": {
    "client_token": "hvs.CAESIORUXMfvLCQgWHLAtfP4TY5kYa0oKuPf6kLdrDRD2dTEGh4KHGh2cy5HMG1WWkV4WXZ4OXFhbVJkcmpGQ3ZDbHo",
    "accessor": "gfSZSBQLutlwsxF1QJmghyDs",
    "policies": [
      "default",
      "otus-policy"
    ],
    "token_policies": [
      "default",
      "otus-policy"
    ],
    "metadata": {
      "role": "otus",
      "service_account_name": "vault-auth",
      "service_account_namespace": "vault",
      "service_account_secret_name": "",
      "service_account_uid": "ce698cd0-072c-4b35-a397-d6f9048299ac"
    },
    "lease_duration": 86400,
    "renewable": true,
    "entity_id": "a2b17e36-8af9-11df-c28e-654f54298e3c",
    "token_type": "service",
    "orphan": true,
    "mfa_requirement": null,
    "num_uses": 0
  }
}
# 
# TOKEN=$(curl -s --cacert ${CACERT} --request POST --data '{"jwt": "'$KUBE_TOKEN'", "role": "otus"}' https://vault:8200/v1/auth/kubernetes/login | jq '.auth.client_token' | awk -F\" '{print $2}')
# 
# echo ${TOKEN}
hvs.CAESIPWpRm0s8j5Bzo4RCVbnFbKTwW34K2DFRoxSYBprD0k4Gh4KHGh2cy5YZXB5MVZRemhZOFozV2FzTHhneEN2dUc
# 
# curl --cacert "${CACERT}" --header "X-Vault-Token: ${TOKEN}" https://vault:8200/v1/otus/otus-rw/config
{"request_id":"f6c5a76e-a83f-e74c-c744-fe38565aac0c","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"bar":"baz"},"wrap_info":null,"warnings":null,"auth":null}
# 
# curl --cacert "${CACERT}" --request POST --data '{"bar-beer": "baz-beer"}' --header "X-Vault-Token: ${TOKEN}" https://vault:8200/v1/otus/otus-rw/config
# 
# curl --cacert "${CACERT}" --header "X-Vault-Token: ${TOKEN}" https://vault:8200/v1/otus/otus-rw/config
{"request_id":"6fa4f97d-9104-b792-a45a-96ae4fb77c5e","lease_id":"","renewable":false,"lease_duration":2764800,"data":{"bar-beer":"baz-beer"},"wrap_info":null,"warnings":null,"auth":null}
```

  В итоге мы смогли по https прочитать секрет "otus/otus-rw/config" и изменить его.



8. Настройка autounseal
   Воспользуемся документацией: https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-transit
   и примером из: https://luafanti.medium.com/vault-auto-unseal-using-transit-secret-engine-on-kubernetes-8f38b60c04f6

   Для autounseal будем использовать второй vault поднятый в неймспейсе "vault-autounseal"

   Создадим директорию "kubernetes-vault/vault-autounseal".

   Аналогично предыдущему ДЗ (переход на https) подготовим скрипт "kubernetes-vault/vault-autounseal/prepare-tls-autounseal.sh".
   С помощью этого скрипта в неймспейсе "vault-autounseal" создадим secret "vault-server-tls" ( нужен для работы tls )

   Запускаем скрипт и проверяем созданные csr и secret:
```console
# ./prepare-tls-autounseal.sh 
Create a key for Kubernetes to sign
Create a file ./csr.conf
Create a CSR
Create a file ./csr.yaml
Send the CSR to Kubernetes
certificatesigningrequest.certificates.k8s.io/vault-csr-autounseal created
verify CSR has been received and stored
NAME                   AGE   SIGNERNAME                      REQUESTOR          REQUESTEDDURATION   CONDITION
vault-csr-autounseal   0s    kubernetes.io/kubelet-serving   kubernetes-admin   <none>              Pending
Approve the CSR in Kubernetes
certificatesigningrequest.certificates.k8s.io/vault-csr-autounseal approved
Verify that the certificate was approved and issued
kubectl get csr vault-csr-autounseal no approved, sleep 2s...
vault-csr-autounseal   2s    kubernetes.io/kubelet-serving   kubernetes-admin   <none>              Approved,Issued
Retrieve the certificate
Write the certificate out to a file
Retrieve Kubernetes CA
Create the namespace
namespace/vault-autounseal created
Store the key, cert, and Kubernetes CA into Kubernetes secrets
secret/vault-server-tls created
ALL OK

# k get csr vault-csr-autounseal
NAME                   AGE     SIGNERNAME                      REQUESTOR          REQUESTEDDURATION   CONDITION
vault-csr-autounseal   2m38s   kubernetes.io/kubelet-serving   kubernetes-admin   <none>              Approved,Issued
# 
# k get secret vault-server-tls -n vault-autounseal
NAME               TYPE     DATA   AGE
vault-server-tls   Opaque   3      2m47s
```   

   Подготавливаем helmfile и values ( storage type raft ):
   "kubernetes-vault/vault-autounseal/values-vault-autounseal.yaml"
   "kubernetes-vault/vault-autounseal/helmfile-vault-autounseal.yaml"

   Запускаем helmfile:
```console
# helmfile -f helmfile-vault-autounseal.yaml apply
```
   Проверяем статус подов:
```console
# k get pods -n vault-autounseal
NAME                                               READY   STATUS    RESTARTS   AGE
vault-autounseal-0                                 0/1     Running   0          7m27s
vault-autounseal-1                                 0/1     Running   0          7m27s
vault-autounseal-2                                 0/1     Running   0          7m27s
vault-autounseal-agent-injector-84bd5d8cf4-5ckft   1/1     Running   0          19m
```

   Инициализируем pod "vault-autounseal-0":
```console
# k exec -it vault-autounseal-0 -n vault-autounseal -- sh
/ $ vault operator init -key-shares=1 -key-threshold=1
Unseal Key 1: QBR2hZHpyorifkiJWwzOkeb+Qk4xe29senXVKF1q1YQ=

Initial Root Token: hvs.BHwE3iaV0FwGUh8Y5A75LcNk

Vault initialized with 1 key shares and a key threshold of 1. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 1 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 1 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

  Объединяем в кластер:
```console
# k exec -it vault-autounseal-0 -n vault-autounseal -- vault operator raft join -leader-ca-cert=@/vault/userconfig/vault-server-tls/vault.ca https://vault-autounseal-0.vault-autounseal-internal:8200
Key       Value
---       -----
Joined    true
# 
# k exec -it vault-autounseal-2 -n vault-autounseal -- vault operator raft join -leader-ca-cert=@/vault/userconfig/vault-server-tls/vault.ca https://vault-autounseal-0.vault-autounseal-internal:8200
Key       Value
---       -----
Joined    true
```

  Выполняем unseal для vault-autounseal-1 и vault-autounseal-2:
```console
#  kubectl exec vault-autounseal-1 -n vault-autounseal -- vault operator unseal QBR2hZHpyorifkiJWwzOkeb+Qk4xe29senXVKF1q1YQ=
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.12.1
Build Date         2022-10-27T12:32:05Z
Storage Type       raft
HA Enabled         true
#  kubectl exec vault-autounseal-2 -n vault-autounseal -- vault operator unseal QBR2hZHpyorifkiJWwzOkeb+Qk4xe29senXVKF1q1YQ=
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       1
Threshold          1
Unseal Progress    0/1
Unseal Nonce       n/a
Version            1.12.1
Build Date         2022-10-27T12:32:05Z
Storage Type       raft
HA Enabled         true
```

   Проверяем состояние подов и статус "raft list-peers"
```console
# k get pods 
NAME                                               READY   STATUS    RESTARTS   AGE
vault-autounseal-0                                 1/1     Running   0          42m
vault-autounseal-1                                 1/1     Running   0          42m
vault-autounseal-2                                 1/1     Running   0          12m
vault-autounseal-agent-injector-84bd5d8cf4-5ckft   1/1     Running   0          156m
# 
# kubectl exec -it vault-autounseal-0 -n vault-autounseal -- vault operator raft list-peers
Node                                    Address                                              State       Voter
----                                    -------                                              -----       -----
ed268110-a2cc-dbd4-db16-8b68ed6c72ad    vault-autounseal-0.vault-autounseal-internal:8201    leader      true
bfdf602f-7c9c-cf15-56d2-3e68e29f2c70    vault-autounseal-1.vault-autounseal-internal:8201    follower    true
770e3f0d-d50e-b31e-ce92-78a215f10024    vault-autounseal-2.vault-autounseal-internal:8201    follower    true
```

   Используя документацию https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-transit
   настраиваем кластер "vault-autounseal".
```console
# kubectl exec -it vault-autounseal-0 -n vault-autounseal -- sh
/ $ vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.BHwE3iaV0FwGUh8Y5A75LcNk
token_accessor       zcISBPJoSfEmw05EwQ8ACAhF
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
/ $ 
/ $ vault secrets enable transit
Success! Enabled the transit secrets engine at: transit/
/ $ 
/ $ vault auth list
Path      Type     Accessor               Description                Version
----      ----     --------               -----------                -------
token/    token    auth_token_49ad19ab    token based credentials    n/a
/ $ 
/ $ vault audit enable file file_path=stdout
Success! Enabled the file audit device at: file/
/ $ 
/ $ vault write -f transit/keys/autounseal
Success! Data written to: transit/keys/autounseal
/ $ 
/ $ ls -al /tmp/autounseal.hcl
-rw-r--r--    1 vault    vault          139 Jan  2 20:07 /tmp/autounseal.hcl
/ $ 
/ $ cat /tmp/autounseal.hcl
path "transit/encrypt/autounseal" {
   capabilities = [ "update" ]
}

path "transit/decrypt/autounseal" {
   capabilities = [ "update" ]
}
/ $ 
/ $ vault policy write autounseal /tmp/autounseal.hcl
Success! Uploaded policy: autounseal
/ $
/ $ vault token create -orphan -policy=autounseal -period=24h
Key                  Value
---                  -----
token                hvs.CAESIKCToJ_r9-P2IAMe_fx9V0LE2m4f-jEnEsz7PBkNBKppGh4KHGh2cy5RaFZ5cFlFRkc2QUZxb1A3WEFVTmpKVUE
token_accessor       MVtW8xAs9bK28H5EjvRNB93Q
token_duration       24h
token_renewable      true
token_policies       ["autounseal" "default"]
identity_policies    []
policies             ["autounseal" "default" 
```

   В итоге мы получили "token" c policies "autounseal" который мы будем использовать в целевом "vault".

   Переходим к настройке целевого "vault", для этого подготовим helmfile и values:
   "kubernetes-vault/vault-autounseal/helmfile-vault-cluster.yaml"
   "kubernetes-vault/vault-autounseal/values-vault-cluster.yaml"

   , где в values добавим секцию seal "transit" и укажем адрес для поключения к "vault-autounseal" и token полученный на предыдущем шаге:
```console
      seal "transit" {
        address = "https://vault-autounseal.vault-autounseal.svc:8200"
        token = "hvs.CAESIKCToJ_r9-P2IAMe_fx9V0LE2m4f-jEnEsz7PBkNBKppGh4KHGh2cy5RaFZ5cFlFRkc2QUZxb1A3WEFVTmpKVUE"
        disable_renewal = "false"
        key_name = "autounseal"
        mount_path = "transit/"
        tls_skip_verify = "false"
      }
```

   применяем изменения и рестартуем поды vault:
```console
# helmfile -f helmfile-vault-cluster.yaml apply
...
# k delete pod vault-0 vault-1 vault-2
pod "vault-0" deleted
pod "vault-1" deleted
pod "vault-2" deleted

# k get pods | grep vault 
vault-0                                 0/1     Running   0          8s
vault-1                                 0/1     Running   0          14s
vault-2                                 0/1     Running   0          13s
vault-agent-example                     2/2     Running   0          3d9h
vault-agent-injector-6df99c75d4-6kk7q   1/1     Running   0          11h
# 
# k logs vault-0
==> Vault server configuration:

             Api Address: https://10.244.133.147:8200
                     Cgo: disabled
         Cluster Address: https://vault-0.vault-internal:8201
              Go Version: go1.19.2
              Listener 1: tcp (addr: "[::]:8200", cluster address: "[::]:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "enabled")
               Log Level: info
                   Mlock: supported: true, enabled: false
           Recovery Mode: false
                 Storage: consul (HA available)
                 Version: Vault v1.12.1, built 2022-10-27T12:32:05Z
             Version Sha: e34f8a14fb7a88af4640b09f3ddbb5646b946d9c

==> Vault server started! Log data will stream in below:

2023-01-02T21:18:42.647Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2023-01-02T21:18:42.647Z [WARN]  storage.consul: appending trailing forward slash to path
2023-01-02T21:18:43.008Z [WARN]  core: entering seal migration mode; Vault will not automatically unseal even if using an autoseal: from_barrier_type=shamir to_barrier_type=transit
2023-01-02T21:18:43.008Z [INFO]  core: Initializing version history cache for core
```

   Произведем unseal vault-0 использую ключ "-migrate" ( для того чтобы мигрировать на autounseal ), для подов vault-1 и vault-2 ключ "-migrate" использовать не будем:
```console
# k exec -it vault-0 -- vault operator unseal -migrate '/rI2lB2cia++UGkQ0JF3P+rsNAJE6ekMqBoQU3vLKE4='
Key                           Value
---                           -----
Recovery Seal Type            shamir
Initialized                   true
Sealed                        false
Total Recovery Shares         1
Threshold                     1
Seal Migration in Progress    true
Version                       1.12.1
Build Date                    2022-10-27T12:32:05Z
Storage Type                  consul
Cluster Name                  vault-cluster-7f7c0326
Cluster ID                    ed7af884-bfa8-d0a0-af26-d6ca8ac87c62
HA Enabled                    true
HA Cluster                    n/a
HA Mode                       standby
Active Node Address           <none>

# k exec -it vault-1 -- vault operator unseal '/rI2lB2cia++UGkQ0JF3P+rsNAJE6ekMqBoQU3vLKE4='
Key                      Value
---                      -----
Recovery Seal Type       shamir
Initialized              true
Sealed                   true
Total Recovery Shares    1
Threshold                1
Unseal Progress          1/1
Unseal Nonce             c25d070f-87f9-52c6-1724-9e5bd8eb8366
Version                  1.12.1
Build Date               2022-10-27T12:32:05Z
Storage Type             consul
HA Enabled               true

# k exec -it vault-2 -- vault operator unseal '/rI2lB2cia++UGkQ0JF3P+rsNAJE6ekMqBoQU3vLKE4='
Key                      Value
---                      -----
Recovery Seal Type       shamir
Initialized              true
Sealed                   true
Total Recovery Shares    1
Threshold                1
Unseal Progress          1/1
Unseal Nonce             8f6601b5-8474-c620-26e8-07f1ace7e8d1
Version                  1.12.1
Build Date               2022-10-27T12:32:05Z
Storage Type             consul
HA Enabled               true
```

    Удаляем поды vault и проверяем что через некоторое время они успешно произвели "autounseal"
```console
# k delete pod vault-0 vault-1 vault-2
pod "vault-0" deleted
pod "vault-1" deleted
pod "vault-2" deleted

# k get pods | grep vault 
vault-0                                 1/1     Running   0          14m
vault-1                                 1/1     Running   0          14m
vault-2                                 1/1     Running   0          14m
vault-agent-example                     2/2     Running   0          3d19h
vault-agent-injector-6df99c75d4-6kk7q   1/1     Running   0          20h
```

   Лог успешного auto-unseal
```console
# k logs vault-1
==> Vault server configuration:

             Api Address: https://10.244.61.237:8200
                     Cgo: disabled
         Cluster Address: https://vault-1.vault-internal:8201
              Go Version: go1.19.2
              Listener 1: tcp (addr: "[::]:8200", cluster address: "[::]:8201", max_request_duration: "1m30s", max_request_size: "33554432", tls: "enabled")
               Log Level: info
                   Mlock: supported: true, enabled: false
           Recovery Mode: false
                 Storage: consul (HA available)
                 Version: Vault v1.12.1, built 2022-10-27T12:32:05Z
             Version Sha: e34f8a14fb7a88af4640b09f3ddbb5646b946d9c

==> Vault server started! Log data will stream in below:

2023-01-03T06:44:05.890Z [INFO]  proxy environment: http_proxy="" https_proxy="" no_proxy=""
2023-01-03T06:44:05.890Z [WARN]  storage.consul: appending trailing forward slash to path
2023-01-03T06:44:05.962Z [INFO]  core: Initializing version history cache for core
2023-01-03T06:44:05.964Z [INFO]  core: stored unseal keys supported, attempting fetch
2023-01-03T06:44:06.010Z [INFO]  core.cluster-listener.tcp: starting listener: listener_address=[::]:8201
2023-01-03T06:44:06.010Z [INFO]  core.cluster-listener: serving cluster requests: cluster_listen_address=[::]:8201
2023-01-03T06:44:06.010Z [INFO]  core: vault is unsealed
2023-01-03T06:44:06.010Z [INFO]  core: entering standby mode
2023-01-03T06:44:06.208Z [INFO]  core: acquired lock, enabling active operation
2023-01-03T06:44:06.244Z [INFO]  core: unsealed with stored key
2023-01-03T06:44:06.713Z [INFO]  core: post-unseal setup starting
2023-01-03T06:44:06.911Z [INFO]  core: loaded wrapping token key
2023-01-03T06:44:06.920Z [INFO]  core: successfully setup plugin catalog: plugin-directory=""
2023-01-03T06:44:06.929Z [INFO]  core: successfully mounted backend: type=system version="" path=sys/
2023-01-03T06:44:06.931Z [INFO]  core: successfully mounted backend: type=identity version="" path=identity/
2023-01-03T06:44:06.931Z [INFO]  core: successfully mounted backend: type=kv version="" path=otus/
2023-01-03T06:44:06.932Z [INFO]  core: successfully mounted backend: type=pki version="" path=pki/
2023-01-03T06:44:06.933Z [INFO]  core: successfully mounted backend: type=pki version="" path=pki_int/
2023-01-03T06:44:06.943Z [INFO]  core: successfully mounted backend: type=transit version="" path=transit/
2023-01-03T06:44:06.944Z [INFO]  core: successfully mounted backend: type=cubbyhole version="" path=cubbyhole/
2023-01-03T06:44:07.114Z [INFO]  core: successfully enabled credential backend: type=token version="" path=token/ namespace="ID: root. Path: "
2023-01-03T06:44:07.115Z [INFO]  core: successfully enabled credential backend: type=kubernetes version="" path=kubernetes/ namespace="ID: root. Path: "
2023-01-03T06:44:07.211Z [INFO]  rollback: starting rollback manager
2023-01-03T06:44:07.212Z [INFO]  core: restoring leases
2023-01-03T06:44:07.315Z [INFO]  identity: entities restored
2023-01-03T06:44:07.406Z [INFO]  identity: groups restored
2023-01-03T06:44:07.806Z [INFO]  expiration: lease restore complete
2023-01-03T06:44:08.106Z [INFO]  core: usage gauge collection is disabled
2023-01-03T06:44:08.234Z [INFO]  core: post-unseal setup complete
```


9. Настройка lease временных секретов для доступа к БД postgres.
   Будем использовать документацию:
   https://habr.com/ru/company/quadcode/blog/565690/
   https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets


   Подготовим helmfile для установки postgres:
   "kubernetes-vault/vault-lease-secret-db/helmfile-postgresql.yaml"
```console
# helmfile -f helmfile-postgresql.yaml apply
```

   Проверяем статус пода с постргес и выясняем имена сервисов:
```console
# k get pods -n db
NAME           READY   STATUS    RESTARTS   AGE
postgresql-0   1/1     Running   0          14m
# 
# k get svc -n db
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
postgresql      ClusterIP   10.101.124.174   <none>        5432/TCP   15m
postgresql-hl   ClusterIP   None             <none>        5432/TCP   15m
```
   Для донастройки postgres пробрасываем порт:
```console
# k port-forward svc/postgresql 5432:5432 -n db &
[1] 3122479
[root@test2 vault-autounseal]# Forwarding from 127.0.0.1:5432 -> 5432
Forwarding from [::1]:5432 -> 543
```

   Подключаемся с postgres и создаем:
   - роль "app", которой мы будем ограничивать доступ для "динамических" пользователей
   - роль "vault-root-app", с помощью которой мы будем создавать "динамических" пользователей в postgres
```console
# psql -h 127.0.0.1 -p 5432 -U postgres -W testdb
Password: 
Handling connection for 5432
psql (15.1)
Type "help" for help.

testdb=# CREATE ROLE app NOINHERIT; GRANT SELECT ON ALL TABLES IN SCHEMA public TO "app";
CREATE ROLE
GRANT

testdb=# CREATE ROLE "vault-root-app" WITH CREATEROLE NOINHERIT LOGIN PASSWORD 'superpasswordforvault';
CREATE ROLE
```

   Настраиваем vault:
```console
# k exec -it vault-0 -- sh
/ $ vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.YwfppIZj6MeG3RN9UiovgCAk
token_accessor       osidIgvh1XMZhvpykhyeGijT
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
/ $ 
/ $ vault secrets enable -path=psql database
Success! Enabled the database secrets engine at: psql/
/ $ 
/ $ vault write psql/config/app-db \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@postgresql.db.svc:5432/testdb?sslmode=disable" \
    allowed_roles=app \
    username="vault-root-app" \
    password="superpasswordforvault"
Success! Data written to: psql/config/app-db
/ $ 
/ $ vault write psql/roles/app \
    db_name=app-db \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT; GRANT app TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
Success! Data written to: psql/roles/app
/ $ 
/ $ vault read psql/creds/app
Key                Value
---                -----
lease_id           psql/creds/app/jwWBkFf5plYsTcEfM1R0zBFk
lease_duration     1h
lease_renewable    true
password           6sUbQRAlAQI-gcJt0Sit
username           v-root-app-VMuTkARf6rmKMa1B1t0u-1672758026
/ $
```

   В итоге мы создали роль "psql/roles/app" использующее подключение с бд "psql/config/app-db",
   и запросили динамические креды.

   Проверка подключения:
```console
# psql -h 127.0.0.1 -p 5432 -U v-root-app-VMuTkARf6rmKMa1B1t0u-1672758026 -W testdb
Password: 
Handling connection for 5432
psql (15.1)
Type "help" for help.

testdb=> \du+
                                                             List of roles
                    Role name                    |                         Attributes                         | Member of | Description 
-------------------------------------------------+------------------------------------------------------------+-----------+-------------
 app                                             | No inheritance, Cannot login                               | {}        | 
 pguser                                          | Create DB                                                  | {}        | 
 postgres                                        | Superuser, Create role, Create DB, Replication, Bypass RLS | {}        | 
 v-root-app-VMuTkARf6rmKMa1B1t0u-1672758026      | Password valid until 2023-01-03 16:00:31+00                | {app}     | 
 vault-root-app                                  | No inheritance, Create role                                | {}        | 
```

   Подключение успешно и наш пользователь "v-root-app-VMuTkARf6rmKMa1B1t0u-1672758026" имеет права согласно роли "app"
