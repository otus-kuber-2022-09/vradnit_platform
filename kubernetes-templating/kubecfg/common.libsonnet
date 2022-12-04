
{

local kube = import "https://raw.githubusercontent.com/bitnami-labs/kube-libsonnet/master/kube.libsonnet";


local common_probes = {
  exec: {
    command: [
      "/bin/grpc_health_probe",
      "-addr=:50051",
    ],
 },
};

local common_resources = {
  requests: { cpu: "100m", memory: "64Mi" },
  limits: { cpu: "200m", memory: "128Mi" }
};

common(name) = {

  service: kube.Service(name) {
    target_pod:: $.deployment.spec.template,
  },

  deployment: kube.Deployment(name) {
    spec+: {
      local deployment = self,
      replicas: 1,
      template+: {
        spec+: {
          containers_+: {
            common: kube.Container("common") {
              resources: common_resources,
              env_+: {
                PORT: "50051"
              },
              ports_+: { http: { containerPort: 50051 } },
              readinessProbe: common_probes,
              livenessProbe: common_probes,
  }}}}}}
};

}
