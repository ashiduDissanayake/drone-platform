# Terraform variables for Drone Platform infrastructure

variable "aws_region" {
  description = "AWS region to deploy SITL instance"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for SITL (needs enough CPU for real-time simulation)"
  type        = string
  default     = "c7i-flex.large"  # Good balance of cost and performance for SITL
  
  validation {
    condition     = can(regex("^[ct][3-7][ig]?\\.(nano|micro|small|medium|large|xlarge)", var.instance_type))
    error_message = "Instance type should be a valid compute-optimized type (t3, c5, c6i, c7i, etc.)"
  }
}
