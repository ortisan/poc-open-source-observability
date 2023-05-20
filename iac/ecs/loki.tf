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

resource "aws_ecs_service" "loki" {
  name            = "loki"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.loki.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.loki.arn
    container_name   = "loki"
    container_port   = 3100
  }
}

resource "aws_lb_target_group" "loki" {
  name        = "loki-target-group"
  port        = 3100
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path     = "/ready"
    port     = 3100
    protocol = "HTTP"
  }
}


resource "aws_lb_listener" "loki" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = 3100
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.loki.id
    type             = "forward"
  }
}
