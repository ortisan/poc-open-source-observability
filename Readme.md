# POC Open Source Observability Tools

Testing open source observability tools on AWS.


## Poc

1. Use fluentbit to fanout the logs and telemetry from ecs
2. Use fluentbit into lambda runtime to fanout the logs and telemetry

### Running locally

```sh
docker-compose up --build
curl localhost:8080/stocks
```

Endpoints:

| Service    | Port  | Url                    |
|------------|-------|------------------------|
| Jaeger     | 16686 | http://localhost:16686 |
| Prometheus | 9090  | http://localhost:9090  |
| Grafana    | 3000  | http://localhost:3000  |

### Building lambda base image


```sh
docker build -t lambda-base-image -f Dockerfile.fluent-bit-lambda .
```

### Building AWS environment


```sh
terraform init
terraform apply --auto-approve
curl http://poc-fluent-bit-1129898247.us-east-1.elb.amazonaws.com/stocks
```