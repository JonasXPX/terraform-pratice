terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "core" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name : "Main-VPC"
  }
}

resource "aws_internet_gateway" "ig_core" {
  vpc_id = aws_vpc.core.id
  tags = {
    Name = "ig-core"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "jonas-nat-eip"
  }
}
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.sn_main_public_a.id

  depends_on = [ aws_internet_gateway.ig_core ]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.core.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id = aws_subnet.sn_main_a.id
  route_table_id = aws_route_table.private.id
}


resource "aws_route_table_association" "private_b" {
  subnet_id = aws_subnet.sn_main_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.core.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig_core.id
  }

  tags = {
    Name = "Nginx-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.sn_main_public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.sn_main_public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "sn_main_a" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.core.id
  availability_zone = "us-east-1a"

  tags = {
    "Name" : "sn_main-A"
  }
}

resource "aws_subnet" "sn_main_b" {
  cidr_block        = "10.0.2.0/24"
  vpc_id            = aws_vpc.core.id
  availability_zone = "us-east-1b"

  tags = {
    "Name" : "sn_main-B"
  }
}

resource "aws_subnet" "sn_main_public_a" {
  cidr_block              = "10.0.3.0/24"
  vpc_id                  = aws_vpc.core.id
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true
  tags = {
    "Name" : "sn_main_public-A"
  }
}

resource "aws_subnet" "sn_main_public_b" {
  cidr_block              = "10.0.4.0/24"
  vpc_id                  = aws_vpc.core.id
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = true
  tags = {
    "Name" : "sn_main_public-B"
  }
}

resource "aws_security_group" "lb_sg" {
  name        = "allow http"
  description = "allow http traffic"
  vpc_id      = aws_vpc.core.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv4         = aws_vpc.core.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


resource "aws_security_group" "ecs_sg" {
  name        = "nginx-ecs-sg"
  vpc_id      = aws_vpc.core.id
  description = "ECS Fargate Security Group"
  tags = { Name = "nginx-ecs-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ecs_tls_ipv4" {
  security_group_id = aws_security_group.ecs_sg.id
  cidr_ipv4         = aws_vpc.core.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_ecs_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}



resource "aws_alb" "lb-nginx" {
  name               = "lb-nginx"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.sn_main_public_a.id, aws_subnet.sn_main_public_b.id]

}
resource "aws_lb_target_group" "lb-nginx" {
  name     = "tg-nginx"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.core.id
  target_type = "ip"
}

resource "aws_alb_listener" "lbl" {
  load_balancer_arn = aws_alb.lb-nginx.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-nginx.arn
  }
}

resource "aws_ecs_cluster" "ecs-fenix-jonas" {
  name = "ecs-fenix-jonas"
}

resource "aws_ecs_task_definition" "nginx" {
  family             = "nginx"
  network_mode = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  cpu                = 256
  memory             = 512

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:stable-alpine3.23-perl"
      essential = true
      portMappings = [{
          containerPort = 80
          hostPort      = 80
      }]

      logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/jonas-nginx"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "nginx"
      }
    }
    }
  ])

}

resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = aws_ecs_cluster.ecs-fenix-jonas.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 3
  launch_type = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.sn_main_a.id, aws_subnet.sn_main_b.id]
    security_groups  = [aws_security_group.lb_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lb-nginx.arn
    container_name   = "nginx"
    container_port   = "80"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_instance_role_policy,
    aws_alb_listener.lbl
  ]
}
