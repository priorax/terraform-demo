module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  single_nat_gateway  = true
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  cidr = "10.0.0.0/16"
  azs             = ["ap-southeast-2a", "ap-southeast-2b"]
  tags = {
    Name = "PodDemo"
  }
}

output "privatesubnet" {
    value = module.vpc.private_subnets[0]
}

data "aws_subnet" "selected" {
  id = module.vpc.private_subnets[0]
}

module "server" {
  source = "./modules/app-cluster"
  podnumber = "1"
  privatesubnet = data.aws_subnet.selected.id
}



module "pod2" {
  source = "./modules/app-cluster"
  podnumber = "2"
  privatesubnet = data.aws_subnet.selected.id
}