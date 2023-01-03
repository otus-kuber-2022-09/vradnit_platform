#!/bin/bash

set -e

# SERVICE is the name of the Vault service in Kubernetes.
# It does not have to match the actual running service, though it may help for consistency.
export SERVICE=vault

# NAMESPACE where the Vault service is running.
export NAMESPACE=vault

# SECRET_NAME to create in the Kubernetes secrets store.
export SECRET_NAME=vault-server-tls

# TMPDIR is a temporary working directory.
export TMPDIR=.

# CSR_NAME will be the name of our certificate signing request as seen by Kubernetes.
export CSR_NAME=vault-csr

echo "Create a key for Kubernetes to sign"
openssl genrsa -out ${TMPDIR}/vault.key 2048

#Create a Certificate Signing Request (CSR).
echo "Create a file ${TMPDIR}/csr.conf"
cat <<EOF >${TMPDIR}/csr.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${SERVICE}
DNS.2 = ${SERVICE}.${NAMESPACE}
DNS.3 = ${SERVICE}.${NAMESPACE}.svc
DNS.4 = ${SERVICE}.${NAMESPACE}.svc.cluster.local
IP.1 = 127.0.0.1
EOF

echo "Create a CSR"
openssl req -new -key ${TMPDIR}/vault.key \
    -subj "/O=system:nodes/CN=system:node:${SERVICE}.${NAMESPACE}.svc" \
    -out ${TMPDIR}/server.csr \
    -config ${TMPDIR}/csr.conf

echo "Create a file ${TMPDIR}/csr.yaml"
cat <<EOF >${TMPDIR}/csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  groups:
  - system:authenticated
  request: $(cat ${TMPDIR}/server.csr | base64 | tr -d '\r\n')
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

echo "Send the CSR to Kubernetes"
kubectl create -f ${TMPDIR}/csr.yaml

echo "verify CSR has been received and stored"
until kubectl get csr ${CSR_NAME} ; do
    echo "kubectl get csr ${CSR_NAME} exit fail, sleep 2s..."
    sleep 2
done

echo "Approve the CSR in Kubernetes"
kubectl certificate approve ${CSR_NAME}

echo "Verify that the certificate was approved and issued"
until kubectl get csr ${CSR_NAME} | grep 'Approved,Issued' ; do
    echo "kubectl get csr ${CSR_NAME} no approved, sleep 2s..."
    sleep 2
done

#2. Store key, cert, and Kubernetes CA into Kubernetes secrets store
echo "Retrieve the certificate"
serverCert=$(kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}')

echo "Write the certificate out to a file"
echo "${serverCert}" | openssl base64 -d -A -out ${TMPDIR}/vault.crt

echo "Retrieve Kubernetes CA"
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d > ${TMPDIR}/vault.ca

echo "Create the namespace"
kubectl create namespace ${NAMESPACE} || true

echo "Store the key, cert, and Kubernetes CA into Kubernetes secrets"
kubectl create secret generic ${SECRET_NAME} \
    --namespace ${NAMESPACE} \
    --from-file=vault.key=${TMPDIR}/vault.key \
    --from-file=vault.crt=${TMPDIR}/vault.crt \
    --from-file=vault.ca=${TMPDIR}/vault.ca

echo "ALL OK"
