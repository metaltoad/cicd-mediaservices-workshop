# Main Terraform configuration file

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-west-2"
}

module "media_services" {
  source = "./modules/media_services"
  aws_region = var.aws_region
}

module "pipeline" {
  source = "./modules/pipeline"
  aws_region = var.aws_region
}

output "cloudfront_domain_name" {
  value = module.media_services.cloudfront_domain_name
}

output "hls_endpoint_url" {
  value = module.media_services.hls_endpoint_url
}

output "codecommit_repo_url" {
  value = module.pipeline.codecommit_repo_url
}

output "pipeline_name" {
  value = module.pipeline.pipeline_name
}