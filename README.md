# Cloud Computing Project

# TODOs

- Create services files for MiniIO and RabbitMQ
- Find out why facerecognition yolo deployment doesn't work. We can't see the logs (?)
- Do the 'TODOs' in the files
- Headless services for PostgresQL and MiniIO (one of the target instances set as primary)

# Notes

Under MacOS minio struggles to run (3-5 fallbacks in average), but it works eventually. In linux systems there's no such a problem.

# Dependencies

Fixed dependency versions on 11.08.2023 for preventing regressions due to compatibility breaking changes.

# DDD

File naming for a Domain Driven Design (e.g. postgres-persistent-volume-claim instead of persistent-volume-claim-postgres)

# Helpful commands

## Helm

- To add specific environment variable using Helm, use the flag `--set postgresqlPassword=mysecretpassword`

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-release bitnami/postgresql
helm install my-release -f values.yaml bitnami/postgresql

helm install my-release -f values.yaml bitnami/postgresql

helm install my-release bitnami/rabbitmq

helm install my-release-3 bitnami/minio --set root-password=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY --set root-user=AKIAIOSFODNN7EXAMPLE

```

### Useful Deployment Commands

```
kubectl rollout restart deployment/irmgard-deployment

```

### Useful Pods Commands

```

kubectl describe pods POD_NAME [-n namespace]
kubectl delete pods irmgard-deployment-69cdf8bd5d-k8zn7
kubectl logs irmgard-deployment-67f4c78cfb-sp9mk -n default -c irmgard --previous
kubectl describe pod irmgard-deployment-67f4c78cfb-sp9mk -n default

```

```
kubectl delete pods --all

kubectl delete statefulsets --all
kubectl delete deployments --all
kubectl delete persistentvolumeclaims --all
kubectl delete configmap --all
```

### Fresh start

```
kubectl delete statefulsets --all && kubectl delete deployments --all && kubectl delete persistentvolumeclaims --all

```

```

kubectl get services

```

- Secrets Table

```

kubectl get secret my-release-postgresql

```

- Secrets Table Data

```

kubectl get secret my-release-postgresql -o json

```

- Specific secrets data in table

```

kubectl get secret my-release-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode

```

### Concepts

- Backoff: Delay for retrying an operation

```

```
