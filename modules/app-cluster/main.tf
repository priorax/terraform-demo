

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] 
}

data "aws_subnet" "selected" {
  id = var.private_subnet
}

resource "aws_security_group" "alb_access" {
  name_prefix        = "ing_${var.env_number}"
  description = "Allows inbound VPC access"
  vpc_id      = var.vpc_id

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

}

data "template_file" "user_data" {  template = file("${path.module}/nginx.sh")}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.nano"
  associate_public_ip_address = false
  subnet_id = data.aws_subnet.selected.id
  iam_instance_profile = aws_iam_instance_profile.test_profile.id
	user_data = data.template_file.user_data.rendered
  security_groups = [aws_security_group.alb_access.id]
  tags = {
    Name = "Pod-${var.env_number}"
  } 
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.web.id
  port             = 80
}

output "instance" {
    value = aws_instance.web.id
}
