# Terraform configuration for Drone Platform Cloud SITL Infrastructure
# Creates EC2 instance with security groups for ArduPilot SITL

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region
}

# Get current IP for security group
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Security group for SITL instance
resource "aws_security_group" "sitl" {
  name_prefix = "drone-platform-sitl-"
  description = "Security group for ArduPilot SITL"

  # MAVLink TCP port (from your IP only)
  ingress {
    from_port   = 5760
    to_port     = 5760
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    description = "MAVLink TCP from my IP"
  }

  # MAVLink UDP port (optional, for QGC)
  ingress {
    from_port   = 14550
    to_port     = 14550
    protocol    = "udp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    description = "MAVLink UDP from my IP"
  }

  # SSH access (from your IP only)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    description = "SSH from my IP"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "drone-platform-sitl-sg"
    Project = "drone-platform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Find latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate SSH key pair
resource "tls_private_key" "sitl_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "sitl_key" {
  key_name   = "drone-platform-sitl-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  public_key = tls_private_key.sitl_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.sitl_key.private_key_pem
  filename        = "${path.module}/sitl-key.pem"
  file_permission = "0400"
}

# EC2 instance for SITL
resource "aws_instance" "sitl" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.sitl_key.key_name
  vpc_security_group_ids = [aws_security_group.sitl.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name    = "drone-platform-sitl"
    Project = "drone-platform"
    Role    = "simulator"
  }
}

# Output connection details
output "sitl_public_ip" {
  description = "Public IP of the SITL instance"
  value       = aws_instance.sitl.public_ip
}

output "sitl_connection_string" {
  description = "MAVLink connection string for vehicle adapter"
  value       = "tcp:${aws_instance.sitl.public_ip}:5760"
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i sitl-key.pem ubuntu@${aws_instance.sitl.public_ip}"
}

output "ansible_command" {
  description = "Command to run Ansible configuration"
  value       = "cd ../ansible && ansible-playbook -i inventory/aws.yml site.yml"
}
