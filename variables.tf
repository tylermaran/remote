# =============================================================================
# AWS Configuration Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use (optional)"
  type        = string
  default     = ""
}

# =============================================================================
# Instance Configuration Variables
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
  
  validation {
    condition = can(regex("^[a-z][0-9][a-z]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be valid EC2 instance type format."
  }
}

variable "use_spot_instance" {
  description = "Whether to use spot instances for cost savings"
  type        = bool
  default     = false
}

variable "spot_price" {
  description = "Maximum spot price (only used if use_spot_instance is true)"
  type        = string
  default     = "0.50"
}

# =============================================================================
# Storage Configuration Variables
# =============================================================================

variable "ebs_volume_size" {
  description = "Size of the persistent EBS volume in GB"
  type        = number
  default     = 100
  
  validation {
    condition     = var.ebs_volume_size >= 8 && var.ebs_volume_size <= 16384
    error_message = "EBS volume size must be between 8 and 16384 GB."
  }
}

variable "ebs_volume_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.ebs_volume_type)
    error_message = "EBS volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "ebs_iops" {
  description = "Provisioned IOPS for EBS volume (only for io1/io2/gp3)"
  type        = number
  default     = 3000
}

variable "ebs_throughput" {
  description = "Throughput in MB/s for gp3 volumes"
  type        = number
  default     = 125
}

# =============================================================================
# Network Configuration Variables
# =============================================================================

variable "my_ip" {
  description = "Your public IP address for security group access (leave empty to auto-detect)"
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "Name of the AWS key pair"
  type        = string
  default     = "remote-desktop-key"
}

variable "vnc_password" {
  description = "Password for VNC access"
  type        = string
  default     = "SecurePassword123!"
  sensitive   = true
  
  validation {
    condition     = length(var.vnc_password) >= 8
    error_message = "VNC password must be at least 8 characters long."
  }
}

# =============================================================================
# Desktop Environment Variables
# =============================================================================

variable "desktop_environment" {
  description = "Desktop environment to install"
  type        = string
  default     = "xfce4"
  
  validation {
    condition     = contains(["xfce4", "gnome", "kde"], var.desktop_environment)
    error_message = "Desktop environment must be one of: xfce4, gnome, kde."
  }
}

variable "vnc_port" {
  description = "VNC port"
  type        = number
  default     = 5901
}

variable "rdp_port" {
  description = "RDP port"
  type        = number
  default     = 3389
}

# =============================================================================
# Auto-shutdown Configuration Variables
# =============================================================================

variable "auto_shutdown_enabled" {
  description = "Enable automatic shutdown when idle"
  type        = bool
  default     = true
}

variable "auto_shutdown_idle_minutes" {
  description = "Minutes of idle time before automatic shutdown"
  type        = number
  default     = 60
}

# =============================================================================
# Monitoring and Logging Variables
# =============================================================================

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
  default     = "/aws/ec2/remote-desktop"
}

# =============================================================================
# Tag Variables
# =============================================================================

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "remote-desktop"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "your-name"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = ""
}

# =============================================================================
# Optional Feature Variables
# =============================================================================

variable "install_nvidia_drivers" {
  description = "Install NVIDIA drivers (auto, true, false)"
  type        = string
  default     = "auto"
  
  validation {
    condition     = contains(["auto", "true", "false"], var.install_nvidia_drivers)
    error_message = "install_nvidia_drivers must be one of: auto, true, false."
  }
}

variable "install_docker" {
  description = "Install Docker"
  type        = bool
  default     = true
}

variable "install_vscode" {
  description = "Install Visual Studio Code"
  type        = bool
  default     = true
}

variable "install_chrome" {
  description = "Install Google Chrome"
  type        = bool
  default     = true
}

variable "custom_packages" {
  description = "Space-separated list of custom packages to install"
  type        = string
  default     = "htop tree curl wget git"
} 