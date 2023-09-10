# Cloud Computing Project

# TODOs

1 - Headless services for PostgresQL and MiniIO (one of the target instances set as primary)
=> temporary used the version of yolo to v0.4, can be changed again to latest if needed
=> changed service names for minio and postgres (=> different hostname in config maps, check if errors occure)

# Notes

Under MacOS minio struggles to run (3-5 fallbacks in average), but it works eventually. In linux systems there's no such a problem.

# Testing Set-up:

For testing locally, run `minikube tunnel`and configure your DNS in /etc/hosts to point your hostname (e.g. `kubernetes.docker.internal`) to `127.0.0.1`

# Dependencies

Fixed dependency versions on 11.08.2023 for preventing regressions due to compatibility breaking changes.

# DDD

File naming for a Domain Driven Design (e.g. postgres-persistent-volume-claim instead of persistent-volume-claim-postgres)

### Set local namespace configs

```
kubectl create namespace face-blurring

kubectl config set-context face-blurring --namespace face-blurring --cluster=minikube --user minikube

kubectl config use-context face-blurring
```

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
kubectl label pod postgres-0 role=primary, labels a pod so the headless svc can find the primary pod 

```

```
kubectl delete pods --all
kubectl delete services --all
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
- Service: OSI Layer 4 router and - if multiple endpoints are available - load balancer.

```

```

### Docker Hub

```
docker login
```

In file: `~/.docker/config.json`

```
{
    "credsStore": "osxkeychain"
}

```

Replace "osxkeychain" with the appropriate credential helper for your OS.

```
docker build -t germaingirndt/irmgard:0.4 .

docker push germaingirndt/irmgard:0.4

```

For supporting different architectures:

```
docker buildx build --platform linux/amd64,linux/arm64/v8 -t germaingirndt/irmgard:latest . --push
docker buildx build --platform linux/amd64,linux/arm64/v8 -t germaingirndt/facerecognition-yolo:latest . --push
```

### Presentation

# Topics

- Project structure (monorepo + DDD)

# Challenges

- Since in the log was not clear where the error was, it took us time to understand, that the error was caused by Golang's variable scope (a variable was defined in the main method and we tried to reference it in another method; the error message didn't say that the variable wasn't defined, just the "Bucket name cannot be empty")
- Since we use two difference architectures (amd x64 for ubuntu and arm for MacOS), we faced problems running the containers. We solved it by build for both architectures, but that took a lot of time (in the worst case 8h for building the yolo project)
- Minio works locally and has the same API as AWS. Because of that with kubernetes we have the flexibility to switch to AWS very easily by creating another config map with specifications for AWS
- debate over pvc template or pvc itself in sfs through a yaml file, synchronisation, minio and 
postgres vs rabbitmq
- setting up probes (finding out which ports to use for tcp probe), finding fitting combinations of probes and waiting times 
- Communication with the cluster from outside. Irmgard with LoadBalancer seems to be the most straight forward way. Other approaches (e.g. NodePort) requires configuring ingress
