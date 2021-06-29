terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
    default_tags {
    tags = {
      Environment = "PodTest"
      UUID        = "ABCD1234"
    }
  }
  region = "ap-southeast-2"
}

