terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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
  engine_version = "17"

  availability_zones = data.aws_availability_zones.current.names
  subnet_ids         = data.aws_subnets.private_subnets.ids
  vpc_id             = data.aws_vpc.this.id

  tags = {
    application = "simple-postgres"
  }

  manage_master_user_password              = true
  password_rotation_automatically_after_days = 30

  # Optionally encrypt the secret with a custom KMS key:
  # master_user_secret_kms_key_id = "alias/my-key"

  # Uncomment to enable the RDS Data API (requires Aurora PostgreSQL >= 17.7):
  # enable_data_api = true
}
