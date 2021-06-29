module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  enable_nat_gateway = true
  single_nat_gateway = true
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  cidr = "10.0.0.0/16"
  azs             = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  tags = {
    Name = "PodDemo"
  }
}

output "private_subnet" { 
    value = module.vpc.private_subnets[0]
}

data "aws_subnet" "selected" {
  id = module.vpc.private_subnets[0]
}

resource "aws_security_group" "alb_access" {
  name_prefix        = "lb-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "alb_access"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.testGroup.arn
  }
}

resource "aws_lb" "test" {
  name_prefix               = "demo"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_access.id]
  subnets            = module.vpc.public_subnets
}

module "server" { 
  wait_conditions = module.vpc.natgw_ids
  source = "./modules/app-cluster"
  target_group_arn = aws_lb_target_group.testGroup.arn
  env_number = "1"
  private_subnet = data.aws_subnet.selected.id
  vpc_id = module.vpc.vpc_id
  albSg = aws_security_group.alb_access.id
}

resource "aws_lb_target_group" "testGroup" {
  name_prefix     = "lb-tg-"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

module "pod2-d" {
  wait_conditions = module.vpc.natgw_ids
  source = "./modules/app-cluster"
  target_group_arn = aws_lb_target_group.testGroup.arn
  env_number = "2"
  private_subnet = data.aws_subnet.selected.id
  vpc_id = module.vpc.vpc_id
  albSg = aws_security_group.alb_access.id
}

output "hostname" {
  value = aws_lb.test.dns_name
}