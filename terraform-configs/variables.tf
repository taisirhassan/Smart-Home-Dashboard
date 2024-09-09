# terraform/variables.tf

variable "aws_region" {
  description = "The AWS region to create resources in"
  default     = "us-east-1"
}

variable "db_username" {
  description = "Username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
}

# You can add more variables here as needed