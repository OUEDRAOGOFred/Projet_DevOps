variable "region" {
  description = "Region Huawei Cloud (ex: eu-west-101)"
  type        = string
  default     = "eu-west-101"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cce_subnet_cidr" {
  description = "CIDR block for CCE Nodes subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "rds_subnet_cidr" {
  description = "CIDR block for RDS Database subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "db_password" {
  description = "Password for the RDS master user (Must be injected via secure CI/CD variable or Key Management Service)"
  type        = string
  sensitive   = true # Masque la valeur dans les logs Terraform
}
