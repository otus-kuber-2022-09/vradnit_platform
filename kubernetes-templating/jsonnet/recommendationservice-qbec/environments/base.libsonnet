{
  components: {
    recommendationservice: {
      name: "recommendationservice",
      image: "gcr.io/google-samples/microservices-demo/recommendationservice:v0.1.3",
      containerPort: 8080,
      servicePort: 8080,
      resources: {
        "limits": {
          "cpu": "200m",
          "memory": "450Mi"
        },
        "requests": {
          "cpu": "100m",
          "memory": "220Mi"
        }
      },
      env: [
       {
         "name": "PORT",
         "value": "8080"
       },
       {
         "name": "PRODUCT_CATALOG_SERVICE_ADDR",
         "value": "productcatalogservice:3550"
       },
       {
         "name": "ENABLE_PROFILER",
         "value": "0"
       }
      ],
      readinessProbe: {
        "exec": {
          "command": [
            "/bin/grpc_health_probe",
            "-addr=:8080"
          ]
        },
        "periodSeconds": 5
      },
      livenessProbe: {
        "exec": {
          "command": [
            "/bin/grpc_health_probe",
            "-addr=:8080"
           ]
         },
         "periodSeconds": 5
      },
    }
  }
}
