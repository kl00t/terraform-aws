variable "subnet-prefix" {
  description = "cidr block for the subnet"
}

variable "access-key" {
  description = "AWS Access Key"
  type        = string
}

variable "secret-key" {
  description = "AWS Secret Key"
  type        = string
}

variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
  type        = string
}