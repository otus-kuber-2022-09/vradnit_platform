local kube = import "https://raw.githubusercontent.com/bitnami-labs/kube-libsonnet/master/kube.libsonnet";


local common(name) = {
  local labels = { app: name },

  local common_probes = {
    exec: {
      command: [ "/bin/grpc_health_probe", "-addr=:50051" ],
    },
  },

  local common_resources = {
    requests: { cpu: "100m", memory: "64Mi" },
    limits: { cpu: "200m", memory: "128Mi" }
  },

  service: kube.Service(name) {
    metadata+: {
      labels: labels
    },
    target_pod:: $.deployment.spec.template,
  },

  deployment: kube.Deployment(name) {
    metadata+: {
      labels: labels
    },
    spec+: {
      local deployment = self,
      replicas: 1,
      strategy: {},
      template+: {
        spec+: {
          containers_+: {
            common: kube.Container("common") {
              resources: common_resources,
              env_+: {
                PORT: "50051"
              },
              ports_+: { grpc: { containerPort: 50051 } },
              readinessProbe: common_probes,
              livenessProbe: common_probes,
  }}}}}}
};

{
  paymentservice: common("paymentservice") {
    deployment+: {
    spec+: {
      template+: {
        spec+: {
          containers_+: {
            common+: {
              name: "server",
              image: "gcr.io/google-samples/microservices-demo/paymentservice:v0.1.3"

  }}}}}}},
 
  shippingservice: common("shippingservice") {
    deployment+: {
    spec+: {
      template+: {
        spec+: {
          containers_+: {
            common+: {
              name: "server",
              image: "gcr.io/google-samples/microservices-demo/shippingservice:v0.1.3",
              readinessProbe+: {
                periodSeconds: 5
              }
  }}}}}}},
}
