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
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}

# Load environment variables
data "external" "env" {
  program = ["${path.module}/scripts/load-env.sh"]
}

locals {
  # Use environment variables with fallbacks to defaults
  aws_region                 = data.external.env.result["AWS_REGION"]
  instance_type             = data.external.env.result["INSTANCE_TYPE"]
  ebs_volume_size           = tonumber(data.external.env.result["EBS_VOLUME_SIZE"])
  ebs_volume_type           = data.external.env.result["EBS_VOLUME_TYPE"]
  vnc_password              = data.external.env.result["VNC_PASSWORD"]
  project_name              = data.external.env.result["PROJECT_NAME"]
  environment               = data.external.env.result["ENVIRONMENT"]
  owner                     = data.external.env.result["OWNER"]
  use_spot_instance         = data.external.env.result["USE_SPOT_INSTANCE"] == "true"
  desktop_environment       = data.external.env.result["DESKTOP_ENVIRONMENT"]
  vnc_port                  = tonumber(data.external.env.result["VNC_PORT"])
  rdp_port                  = tonumber(data.external.env.result["RDP_PORT"])
  auto_shutdown_enabled     = data.external.env.result["AUTO_SHUTDOWN_ENABLED"] == "true"
  auto_shutdown_idle_minutes = tonumber(data.external.env.result["AUTO_SHUTDOWN_IDLE_MINUTES"])
  install_nvidia_drivers    = data.external.env.result["INSTALL_NVIDIA_DRIVERS"]
  install_docker            = data.external.env.result["INSTALL_DOCKER"] == "true"
  install_vscode            = data.external.env.result["INSTALL_VSCODE"] == "true"
  install_chrome            = data.external.env.result["INSTALL_CHROME"] == "true"
  key_pair_name             = data.external.env.result["KEY_PAIR_NAME"]
  log_group_name            = data.external.env.result["LOG_GROUP_NAME"]
}

# Configure the AWS Provider
provider "aws" {
  region = local.aws_region

  default_tags {
    tags = {
      Project     = local.project_name
      Environment = local.environment
      Owner       = local.owner
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Get current public IP if not provided
data "http" "current_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip = trimspace(data.http.current_ip.response_body)
  
  # Determine if instance type supports GPU
  is_gpu_instance = can(regex("^(p[2-4]|g[3-5]|inf)", local.instance_type))
  
  common_tags = {
    Name        = "${local.project_name}-${local.environment}"
    Project     = local.project_name
    Environment = local.environment
    Owner       = local.owner
  }
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc"
  })
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw"
  })
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-subnet"
    Type = "Public"
  })
}

# Create route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-rt"
  })
}

# Associate route table with subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "remote_desktop" {
  name_prefix = "${local.project_name}-sg"
  vpc_id      = aws_vpc.main.id
  description = "Security group for remote desktop instance"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip}/32"]
    description = "SSH access from your IP"
  }

  # VNC
  ingress {
    from_port   = local.vnc_port
    to_port     = local.vnc_port
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip}/32"]
    description = "VNC access from your IP"
  }

  # RDP
  ingress {
    from_port   = local.rdp_port
    to_port     = local.rdp_port
    protocol    = "tcp"
    cidr_blocks = ["${local.my_ip}/32"]
    description = "RDP access from your IP"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-sg"
  })
}

# Generate SSH key pair
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = local.key_pair_name
  public_key = tls_private_key.main.public_key_openssh

  tags = local.common_tags
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${local.key_pair_name}.pem"
  file_permission = "0600"
}

# Persistent EBS volume
resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = local.ebs_volume_size
  type              = local.ebs_volume_type
  encrypted         = true

  # Optional: Configure IOPS and throughput for gp3
  dynamic "throughput" {
    for_each = local.ebs_volume_type == "gp3" ? [1] : []
    content {
      throughput = var.ebs_throughput
    }
  }

  dynamic "iops" {
    for_each = contains(["gp3", "io1", "io2"], local.ebs_volume_type) ? [1] : []
    content {
      iops = local.ebs_volume_type == "gp3" ? min(var.ebs_iops, local.ebs_volume_size * 3) : var.ebs_iops
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-data-volume"
  })
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-lts-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "remote_desktop" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.remote_desktop.id]
  subnet_id              = aws_subnet.public.id
  
  # Use spot instance if configured
  dynamic "spot_price" {
    for_each = local.use_spot_instance ? [1] : []
    content {
      spot_price = var.spot_price
    }
  }

  # Enable detailed monitoring if configured
  monitoring = var.enable_detailed_monitoring

  # User data script to set up the desktop environment
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    vnc_password               = local.vnc_password
    desktop_environment        = local.desktop_environment
    vnc_port                   = local.vnc_port
    rdp_port                   = local.rdp_port
    auto_shutdown_enabled      = local.auto_shutdown_enabled
    auto_shutdown_idle_minutes = local.auto_shutdown_idle_minutes
    install_nvidia_drivers     = local.is_gpu_instance && local.install_nvidia_drivers == "auto" ? "true" : local.install_nvidia_drivers
    install_docker             = local.install_docker
    install_vscode             = local.install_vscode
    install_chrome             = local.install_chrome
    custom_packages            = "htop tree curl wget git"
    log_group_name             = local.log_group_name
  }))

  # Root volume configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true

    tags = merge(local.common_tags, {
      Name = "${local.project_name}-root-volume"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-instance"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Attach persistent volume
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.remote_desktop.id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = local.log_group_name
  retention_in_days = 30

  tags = local.common_tags
} 