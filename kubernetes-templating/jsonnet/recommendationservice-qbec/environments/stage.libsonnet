
// this file has the param overrides for the default environment
local base = import './base.libsonnet';


base {
  components +: {
    recommendationservice +: {
      name: "recommendationservice-stage",
      env : [
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
          "value": "1"
        }
      ],
      resources: {
        "limits": {
          "cpu": "100m",
          "memory": "300Mi"
        },
        "requests": {
          "cpu": "100m",
          "memory": "100Mi"
        }
      }
    }
  }
}
