# Terraform configuration for testing

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Mock AWS provider for testing (no actual resources will be created)
provider "aws" {
  region                      = "eu-west-2"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = false

  default_tags {
    tags = {
      Environment = "test"
      ManagedBy   = "terraform-test"
    }
  }
}