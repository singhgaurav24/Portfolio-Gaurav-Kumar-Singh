resource "aws_ecs_cluster" "app_cluster" {
 name = "${var.app_name}-cluster"
}
resource "aws_iam_role" "ecs_task_execution_role" {
 name = "${var.app_name}-execution-role"
 assume_role_policy = jsonencode({
   Version = "2012-10-17"
   Statement = [{
     Effect = "Allow"
     Principal = {
       Service = "ecs-tasks.amazonaws.com"
     }
     Action = "sts:AssumeRole"
   }]
 })
}
resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
 role       = aws_iam_role.ecs_task_execution_role.name
 policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_ecs_task_definition" "app_task" {
 family                   = "${var.app_name}-task"
 requires_compatibilities = ["FARGATE"]
 network_mode            = "awsvpc"
 cpu                     = "256"
 memory                  = "512"
 execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn
 container_definitions = jsonencode([
   {
     name      = var.app_name
     image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
     essential = true
     portMappings = [
       {
         containerPort = var.container_port
         hostPort      = var.container_port
         protocol      = "tcp"
       }
     ]
   }
 ])
}
resource "aws_security_group" "ecs_service_sg" {
 name        = "${var.app_name}-ecs-sg"
 description = "Allow traffic from ALB"
 vpc_id      = aws_vpc.main.id
 ingress {
   from_port       = var.container_port
   to_port         = var.container_port
   protocol        = "tcp"
   security_groups = [aws_security_group.alb_sg.id]
 }
 egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}
resource "aws_ecs_service" "app_service" {
 name            = "${var.app_name}-service"
 cluster         = aws_ecs_cluster.app_cluster.id
 launch_type     = "FARGATE"
 desired_count   = 1
 task_definition = aws_ecs_task_definition.app_task.arn
 network_configuration {
   subnets          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
   security_groups  = [aws_security_group.ecs_service_sg.id]
   assign_public_ip = true
 }
 load_balancer {
   target_group_arn = aws_lb_target_group.tg.arn
   container_name   = var.app_name
   container_port   = var.container_port
 }
 depends_on = [aws_lb_listener.listener]
}