

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

resource "aws_ecs_service" "prometheus" {
  name            = "prometheus"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
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
