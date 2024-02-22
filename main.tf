# Declaración del proveedor AWS
provider "aws" {
  region = "us-west-2" # Cambia a tu región preferida
}

# Creación de la VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Creación de las subredes públicas
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a" # Cambia a la zona de disponibilidad deseada
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b" # Cambia a la zona de disponibilidad deseada
  map_public_ip_on_launch = true
}

# Creación del Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Asociación del Internet Gateway a la VPC
resource "aws_vpc_attachment" "my_vpc_attachment" {
  vpc_id       = aws_vpc.my_vpc.id
  internet_gateway_id = aws_internet_gateway.my_igw.id
}

# Creación del Network Load Balancer (NLB)
resource "aws_lb" "my_nlb" {
  name               = "my-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
}

# Creación del Elastic Container Registry (ECR)
resource "aws_ecr_repository" "my_ecr_repo" {
  name = "my-ecr-repo"
}

# Creación del Cluster de ECS
resource "aws_ecs_cluster" "my_ecs_cluster" {
  name = "my-ecs-cluster"
}

# Creación de las tareas de ECS
resource "aws_ecs_task_definition" "task_a" {
  family                   = "task-a"
  container_definitions    = <<DEFINITION
[
  {
    "name": "my-container-a",
    "image": "${aws_ecr_repository.my_ecr_repo.repository_url}:latest",
    "cpu": 256,
    "memory": "512",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp"
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_task_definition" "task_b" {
  family                   = "task-b"
  container_definitions    = <<DEFINITION
[
  {
    "name": "my-container-b",
    "image": "${aws_ecr_repository.my_ecr_repo.repository_url}:latest",
    "cpu": 256,
    "memory": "512",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp"
      }
    ]
  }
]
DEFINITION
}

# Creación de los servicios de ECS
resource "aws_ecs_service" "service_a" {
  name            = "service-a"
  cluster         = aws_ecs_cluster.my_ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_a.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_a.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.allow_all.id]
  }
}

resource "aws_ecs_service" "service_b" {
  name            = "service-b"
  cluster         = aws_ecs_cluster.my_ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_b.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_b.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.allow_all.id]
  }
}

# Se asocian las subredes a los servicios de ECS
resource "aws_ecs_service_network_configuration" "service_network_config_a" {
  service        = aws_ecs_service.service_a.name
  security_groups = [aws_security_group.allow_all.id]

  subnets = [
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_b.id
  ]
}

resource "aws_ecs_service_network_configuration" "service_network_config_b" {
  service        = aws_ecs_service.service_b.name
  security_groups = [aws_security_group.allow_all.id]

  subnets = [
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_b.id
  ]
}

# Regla de seguridad para permitir todo el tráfico
resource "aws_security_group" "allow_all" {
  vpc_id = aws_vpc.my_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
