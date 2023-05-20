resource "aws_ecs_task_definition" "alert_manager" {
  family                   = "alert-manager"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "alert-manager"
      image     = var.alert_manager_image
      essential = true
      portMappings = [
        {
          containerPort = 9093
          hostPort      = 9093
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "alert_manager" {
  name            = "alert-manager"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.alert_manager.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.alert_manager.arn
    container_name   = "alert-manager"
    container_port   = 9093
  }
}

resource "aws_lb_target_group" "alert_manager" {
  name        = "alert-manager"
  port        = 9093
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path     = "/"
    port     = 9093
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "alert_manager" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = 9093
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.alert_manager.id
    type             = "forward"
  }
}
