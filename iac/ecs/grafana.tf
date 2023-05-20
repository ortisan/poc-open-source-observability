
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

resource "aws_ecs_service" "grafana" {
  name            = "grafana"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
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
