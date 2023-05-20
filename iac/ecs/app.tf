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

resource "aws_cloudwatch_log_group" "golang_app" {
  name = "/ecs/app/golang"
  tags = {
    Environment = "dev"
  }
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

resource "aws_ecs_service" "golang_app" {
  name            = "golang-app"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.golang_app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.golang_app.arn
    container_name   = "golang"
    container_port   = 8080
  }
}

resource "aws_lb_target_group" "golang_app" {
  name        = "golang-target-group"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path     = "/healthcheck"
    port     = 8080
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "golang_app" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = "8080"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.golang_app.id
    type             = "forward"
  }
}
