terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  backend "s3" {
    bucket = "ugt-tf-state-reporting-incidents"
    key    = "tf-state"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}
