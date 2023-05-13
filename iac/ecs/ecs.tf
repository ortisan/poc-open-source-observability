resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_task_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "ecs_task_policy"
  path        = "/"
  description = "Policies for ecs task"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "secretsmanager:DescribeSecret",
              "secretsmanager:*",
              "s3:GetObject",
              "s3:GetBucketLocation",
              "s3:PutObject",
              "logs:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
POLICY
}


resource "aws_iam_role_policy_attachment" "ecs_task_role" {
  policy_arn = aws_iam_policy.ecs_task_policy.arn
  role       = aws_iam_role.ecs_task_role.name
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_ecs_cluster" "poc_open_source_observability" {
  name = "poc-opensource-observability"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "poc_open_source_observability" {
  cluster_name = aws_ecs_cluster.poc_open_source_observability.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_cloudwatch_log_group" "golang_app" {
  name = "/ecs/app/golang"
  tags = {
    Environment = "dev"
  }
}


data "aws_s3_bucket" "fluent_bit_bucket" {
  bucket = var.fluent_bit_bucket
}

resource "aws_s3_object" "fluent_bit_conf" {
  bucket = data.aws_s3_bucket.fluent_bit_bucket.id
  key    = "fluent-bit.conf"
  acl    = "private"
  source = "fluent-bit.conf"
  etag   = filemd5("fluent-bit.conf")
}

resource "aws_ecs_task_definition" "golang_app" {
  family                   = "golang-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "fluent-bit-log-router"
      image     = var.fluent_bit_image
      essential = true
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          config-file-type  = "file",
          config-file-value = "/fluent-bit.conf"
        }
      },
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-stream-prefix = "ecs"
          awslogs-group         = "fluent-bit-log-router"
          awslogs-create-group  = "true"
          awslogs-region        = var.region
        }
      }
    },
    {
      name      = "golang"
      image     = var.golang_image
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
      }
      dependsOn = [
        {
          containerName = "fluent-bit-log-router"
          condition     = "START"
        }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = var.prometheus_image
      essential = true
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
        }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "loki" {
  family                   = "loki"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "loki"
      image     = var.loki_image
      essential = true
      portMappings = [
        {
          containerPort = 3100
          hostPort      = 3100
        }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = var.grafana_image
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

resource "aws_security_group" "ecs_apps" {
  name        = "ecs-apps"
  description = "ECS service"
  vpc_id      = var.vpc_id

  ingress {
    description = "Security group to govern who can access the endpoints"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb" {
  name   = "loadbalancer-poc-opensource-observability"
  vpc_id = var.vpc_id
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "poc_open_source_observability" {
  name            = "poc-opensource-observability"
  subnets         = var.subnets
  security_groups = [aws_security_group.lb.id]
}

resource "aws_lb_target_group" "golang_app" {
  name        = "golang-target-group"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/healthcheck"
    port = 8080
  }
}

resource "aws_lb_listener" "golang_app" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.golang_app.id
    type             = "forward"
  }
}

resource "aws_lb_target_group" "prometheus" {
  name        = "prometheus-target-group"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/-/healthy"
    port = 9090
  }

}

resource "aws_lb_listener" "prometheus" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = "9090"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.prometheus.id
    type             = "forward"
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "grafana-target-group"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/api/health"
    port = 3000
  }
}


resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.grafana.id
    type             = "forward"
  }
}

resource "aws_lb_target_group" "loki" {
  name        = "loki-target-group"
  port        = 3100
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}


resource "aws_lb_listener" "loki" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = "3100"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.loki.id
    type             = "forward"
  }
}

resource "aws_ecs_service" "golang_app" {
  name            = "golang-app"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.golang_app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_apps.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.golang_app.arn
    container_name   = "golang"
    container_port   = 8080
  }
}


resource "aws_ecs_service" "prometheus" {
  name            = "prometheus"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_apps.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }
}

resource "aws_ecs_service" "grafana" {
  name            = "grafana"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_apps.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }
}

resource "aws_ecs_service" "loki" {
  name            = "loki"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.loki.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_apps.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.loki.arn
    container_name   = "loki"
    container_port   = 3100
  }
}
