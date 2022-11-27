local p = import '../params.libsonnet';
local params = p.components.recommendationservice;

[
 {
  "apiVersion": "apps/v1",
  "kind": "Deployment",
  "metadata": {
    "name": params.name
  },
  "spec": {
    "selector": {
      "matchLabels": {
        "app": params.name
      }
    },
    "template": {
      "metadata": {
        "labels": {
          "app": params.name
        }
      },
      "spec": {
        "containers": [
          {
            "env": params.env,
            "image": params.image,
            "livenessProbe": params.readinessProbe,
            "name": "server",
            "ports": [
              {
                "containerPort": params.containerPort
              }
            ],
            "readinessProbe": params.readinessProbe,
            "resources": params.resources
          }
        ],
        "terminationGracePeriodSeconds": 5
      }
    }
  }
 },
 {
  "apiVersion": "v1",
  "kind": "Service",
  "metadata": {
    "name": params.name
  },
  "spec": {
    "ports": [
      {
        "name": "grpc",
        "port": params.servicePort,
        "targetPort": params.containerPort
      }
    ],
    "selector": {
      "app": params.name
    },
    "type": "ClusterIP"
  }
 }
]
