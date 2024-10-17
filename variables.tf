# Variables for Terraform configuration

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "mediatailor_configuration_name" {
  description = "Name of the MediaTailor configuration for the Lambda function"
  type        = string
}
