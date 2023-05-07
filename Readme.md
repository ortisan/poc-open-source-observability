# POC Open Source Observability Tools

Testing open source observability tools on AWS.

| Service    | Port  | Url                    |
|------------|-------|------------------------|
| Jaeger     | 16686 | http://localhost:16686 |
| Prometheus | 9090  | http://localhost:9090  |
| Grafana    | 3000  | http://localhost:3000  |


## Poc

1. Use fluentbit to fanout the logs and telemetry from ecs
2. Use fluentbit into lambda runtime to fanout the logs and telemetry

## Commands

Testing fluent-bit-local
```sh
docker-compose up --build
curl localhost:8080/stocks
```
Uploading golang app image

```sh
aws ecr get-login-password \
        --region us-east-1 | docker login \
        --username AWS \
        --password-stdin 779882487479.dkr.ecr.us-east-1.amazonaws.com

export VERSION=latest
docker build -t golang-app .
docker tag golang-app:latest 779882487479.dkr.ecr.us-east-1.amazonaws.com/golang-app:$VERSION
docker push 779882487479.dkr.ecr.us-east-1.amazonaws.com/golang-app:$VERSION
```

Uploading fluent-bit image

```sh
export VERSION=latest
docker build -t fluent-bit -f Dockerfile-fluent-bit .
docker tag fluent-bit:latest 779882487479.dkr.ecr.us-east-1.amazonaws.com/fluent-bit:$VERSION
docker push 779882487479.dkr.ecr.us-east-1.amazonaws.com/fluent-bit:$VERSION
```

Building

```sh
terraform init
terraform apply --auto-approve
curl http://poc-fluent-bit-1129898247.us-east-1.elb.amazonaws.com/stocks
```


