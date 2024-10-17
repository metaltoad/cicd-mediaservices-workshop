# Main Terraform configuration file

terraform {
  //required_providers {
  //  aws = {
  //    source  = "hashicorp/aws"
  //    version = "~> 5.0"
  //  }
  //}

  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

# AWS region is defined in variables.tf

module "media_services" {
  source = "./modules/media_services"
}

module "pipeline" {
  source = "./modules/pipeline"
}

module "lambda_functions" {
  source = "./modules/lambdaFunction"
}

output "cloudfront_domain_name" {
  value = module.media_services.cloudfront_domain_name
}

output "hls_endpoint_url" {
  value = module.media_services.hls_endpoint_url
}

output "lambda_api_url" {
  value = module.lambda_functions.api_invoke_url
}
