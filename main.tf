locals {
  name        = "complete-ecs"
  environment = "dev"

  # This is the convention we use to know what belongs to each other
  ec2_resources_name = "${local.name}-${local.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}


#module "vpc" {
#  source  = "terraform-aws-modules/vpc/aws"
#  version = "~> 3.0"
#
#  name = local.name
#  cidr = "10.1.0.0/16"
#
#  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
#  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
#  public_subnets  = ["10.1.11.0/24", "10.1.12.0/24"]
#
#  enable_nat_gateway = true
#
#  tags = {
#    Environment = local.environment
#    Name        = local.name
#  }
#}

#----- ECS --------

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true
  enable_dns_hostnames = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "ecs" {
#  source = "../../"
  source = "terraform-aws-modules/ecs/aws"

  name               = local.name
  container_insights = true

  capacity_providers = ["FARGATE", aws_ecs_capacity_provider.prov1.name]

  default_capacity_provider_strategy = [{
    capacity_provider = aws_ecs_capacity_provider.prov1.name
    weight            = "1"
  }]

  tags = {
    Environment = local.environment
  }
}

#module "ec2_profile" {
#  source = "../../modules/ecs-instance-profile"
#
#  name = local.name
#
#  tags = {
#    Environment = local.environment
#  }
#}

resource "aws_ecs_capacity_provider" "prov1" {
  name = "prov1"

  auto_scaling_group_provider {
    auto_scaling_group_arn = module.asg.autoscaling_group_arn
  }

}

#----- ECS  Services--------
#module "hello_world" {
#  source = "./service-hello-world"
#
#  cluster_id = module.ecs.ecs_cluster_id
#}

#----- ECS  Resources--------

data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 4.0"

  name = local.ec2_resources_name

  # Launch configuration
  lc_name   = local.ec2_resources_name
  use_lc    = true
  create_lc = true

  image_id                  = data.aws_ami.amazon_linux_ecs.id
  instance_type             = "t2.micro"
  security_groups           = [module.vpc.default_security_group_id]
#  iam_instance_profile_name = module.ec2_profile.iam_instance_profile_id
#  user_data = templatefile("${path.module}/templates/user-data.sh", {
#    cluster_name = local.name
#  })

  # Auto scaling group
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1 # we don't need them for the example
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = local.environment
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = local.name
      propagate_at_launch = true
    },
  ]
}

###################
# Disabled cluster
###################

#module "disabled_ecs" {
#  source = "../../"
#
#  create_ecs = false
#}

resource "aws_ecs_task_definition" "Frontend-app" {
  family = "app-dev"
  container_definitions = <<EOF
[
  {
    "name": "nginx",
    "image": "nginx:1.13-alpine",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80
      }
    ],

   "environment": [
      {"name": "BACKEND_URL", "value": "some_value"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "app-dev-nginx",
        "awslogs-region": "us-east-1"
      }
    },
    "memory": 128,
    "cpu": 100
  }
]
EOF
}

resource "aws_ecs_task_definition" "Backend-app" {
  family = "app-dev"
  container_definitions = <<EOF
[
  {
    "name": "nginx",
    "image": "nginx:1.13-alpine",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "app-dev-nginx",
        "awslogs-region": "us-east-1"
      }
    },
    "memory": 128,
    "cpu": 100
  }
]
EOF
}

module "alb" {
  source = "anrim/ecs/aws//modules/alb"

  name            = "app-dev"
  host_name       = "app"
  domain_name     = "example.com"
  certificate_arn = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
  #backend_sg_id   = "${module.ecs_cluster.instance_sg_id}"
  backend_sg_id   = "${module.ecs.ecs_cluster_id}"
  tags            = {
    Environment = "dev"
    Owner = "me"
  }
  vpc_id      = "${module.vpc.vpc_id}"
  vpc_subnets = ["${module.vpc.public_subnets}"]
}


module "ecs_service_app" {
  source = "anrim/ecs/aws//modules/service"

  name = "app-dev"
  alb_target_group_arn = "${module.alb.target_group_arn}"
  cluster              = "${module.ecs.ecs_cluster_id}"
  container_name       = "nginx"
  container_port       = "80"
  log_groups           = ["app-dev-nginx"]
  #task_definition_arn  = "${aws_ecs_task_definition.app.arn}"
  task_definition_arn  = [aws_ecs_task_definition.Backend-app , aws_ecs_task_definition.Frontend-app]
  tags                 = {
    Environment = "dev"
    Owner = "Boma"
  }
}



resource "aws_dynamodb_table" "UserCheckin" {
  name           = "UserCheckin"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "HASH"

  attribute {
    name = "HASH"
    type = "S"
  }
}