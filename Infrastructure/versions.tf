# versions.tf

# This block tells Terraform which providers are needed to build this infrastructure.
# It's a best practice to lock the provider to a specific version range to ensure
# that future provider updates don't accidentally break your code.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# This configures the AWS provider itself, primarily setting the region
# where all the resources will be created.
provider "aws" {
  region = var.aws_region
}
