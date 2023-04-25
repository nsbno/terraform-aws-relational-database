terraform {
  required_version = "1.4.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0, <4.0.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

data "aws_availability_zones" "current" {}

data "aws_vpc" "this" {
  tags = {
    Name = "shared"
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  tags = {
    Tier = "Private"
  }
}

module "database" {
  source = "../../"

  application_name = "tut-tut-tog"

  engine         = "postgresql"
  engine_version = "13"

  availability_zones = data.aws_availability_zones.current.names
  subnet_ids         = data.aws_subnets.private_subnets.ids
  vpc_id             = data.aws_vpc.this.id

  tags = {
    application = "simple-postgres"
  }
}
