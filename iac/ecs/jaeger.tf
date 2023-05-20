resource "aws_ecs_task_definition" "jaeger" {
  family                   = "jaeger"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "jaeger"
      image     = var.jaeger_image
      essential = true
      portMappings = [
        {
          containerPort = 5775
          hostPort      = 5775
          protocol      = "udp"
        },
        {
          containerPort = 6831
          hostPort      = 6831
          protocol      = "udp"
        },
        {
          containerPort = 6832
          hostPort      = 6832
          protocol      = "udp"
        },
        {
          containerPort = 5778
          hostPort      = 5778
        },
        {
          containerPort = 16686
          hostPort      = 16686
        },
        {
          containerPort = 14268
          hostPort      = 14268
        },
        {
          containerPort = 9411
          hostPort      = 9411
        }
      ]
    }
  ])
}


resource "aws_ecs_service" "jaeger" {
  name            = "jaeger"
  cluster         = aws_ecs_cluster.poc_open_source_observability.id
  task_definition = aws_ecs_task_definition.jaeger.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jaeger.arn
    container_name   = "jaeger"
    container_port   = 6831
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jaeger_ui.arn
    container_name   = "jaeger"
    container_port   = 16686
  }

}

resource "aws_lb_target_group" "jaeger" {
  name        = "jaeger-target-group"
  port        = 6831
  protocol    = "TCP_UDP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path     = "/"
    port     = 16686
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "jaeger" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = "6831"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.jaeger.id
    type             = "forward"
  }
}


resource "aws_lb_target_group" "jaeger_ui" {
  name        = "jaeger-ui-target-group"
  port        = 16686
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/"
    port = 16686
  }
}

resource "aws_lb_listener" "jaeger_ui" {
  load_balancer_arn = aws_lb.poc_open_source_observability.id
  port              = "16686"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.jaeger_ui.id
    type             = "forward"
  }
}
