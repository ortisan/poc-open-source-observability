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
              "s3:*",
              "dynamodb:*",
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

resource "aws_security_group" "ecs" {
  name        = "ecs-apps"
  description = "ECS service"
  vpc_id      = var.vpc_id

  ingress {
    description = "Security group to govern who can access the endpoints"
    from_port   = 0
    to_port     = 65535
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
    from_port   = 0
    to_port     = 65535
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

output "dns_name" {
  description = "The DNS name of the load balancer."
  value       = aws_lb.poc_open_source_observability.dns_name
}

output "url" {
  description = "Url for loadbalancer"
  value       = "http://${aws_lb.poc_open_source_observability.dns_name}"
}
