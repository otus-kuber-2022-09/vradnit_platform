#!/bin/bash


NAMESPACE="default"
POD_NAME="app"

curl  http://127.0.0.1:8001/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME}/ephemeralcontainers \
  -XPATCH \
  -H "Content-Type: application/strategic-merge-patch+json" \
  -d '
{
    "spec":
    {
        "ephemeralContainers":
        [
            {
                "name": "debugger2",
                "image": "nicolaka/netshoot",
                "targetContainerName": "app",
                "stdin": true,
                "tty": true,
		"securityContext": {"capabilities": {"add": ["SYS_PTRACE"]}}
            }
        ]
    }
}'
