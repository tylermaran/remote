# Load environment variables from .env file
data "external" "env" {
  program = ["${path.module}/scripts/load-env.sh"]
}

locals {
  env = data.external.env.result
}

# Override variables with environment values if provided
variable "env_aws_region" {
  description = "AWS region from environment"
  type        = string
  default     = ""
}

variable "env_instance_type" {
  description = "Instance type from environment"
  type        = string
  default     = ""
}

variable "env_ebs_volume_size" {
  description = "EBS volume size from environment"
  type        = string
  default     = ""
}

variable "env_vnc_password" {
  description = "VNC password from environment"
  type        = string
  default     = ""
  sensitive   = true
}

# Use environment values if provided, otherwise use defaults
locals {
  actual_aws_region = coalesce(
    local.env["AWS_REGION"],
    var.env_aws_region,
    var.aws_region
  )
  
  actual_instance_type = coalesce(
    local.env["INSTANCE_TYPE"],
    var.env_instance_type,
    var.instance_type
  )
  
  actual_ebs_volume_size = tonumber(coalesce(
    local.env["EBS_VOLUME_SIZE"],
    var.env_ebs_volume_size,
    tostring(var.ebs_volume_size)
  ))
  
  actual_vnc_password = coalesce(
    local.env["VNC_PASSWORD"],
    var.env_vnc_password,
    var.vnc_password
  )
} 