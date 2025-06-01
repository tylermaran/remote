# =============================================================================
# Instance Information Outputs
# =============================================================================

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.remote_desktop.id
}

output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.remote_desktop.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_instance.remote_desktop.public_dns
}

output "instance_type" {
  description = "Instance type"
  value       = aws_instance.remote_desktop.instance_type
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_instance.remote_desktop.availability_zone
}

# =============================================================================
# Connection Information Outputs
# =============================================================================

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.key_pair_name}.pem ubuntu@${aws_instance.remote_desktop.public_ip}"
}

output "vnc_tunnel_command" {
  description = "SSH tunnel command for VNC access"
  value       = "ssh -L ${var.vnc_port}:localhost:${var.vnc_port} -i ${var.key_pair_name}.pem ubuntu@${aws_instance.remote_desktop.public_ip}"
}

output "rdp_tunnel_command" {
  description = "SSH tunnel command for RDP access"
  value       = "ssh -L ${var.rdp_port}:localhost:${var.rdp_port} -i ${var.key_pair_name}.pem ubuntu@${aws_instance.remote_desktop.public_ip}"
}

output "vnc_connection_info" {
  description = "VNC connection information"
  value = {
    server   = "localhost:${var.vnc_port}"
    password = "Set in your .env file"
    note     = "Connect after establishing SSH tunnel"
  }
}

output "rdp_connection_info" {
  description = "RDP connection information"
  value = {
    server = "localhost:${var.rdp_port}"
    note   = "Connect after establishing SSH tunnel"
  }
}

# =============================================================================
# Storage Information Outputs
# =============================================================================

output "data_volume_id" {
  description = "ID of the persistent data volume"
  value       = aws_ebs_volume.data.id
}

output "data_volume_size" {
  description = "Size of the persistent data volume"
  value       = "${aws_ebs_volume.data.size}GB"
}

output "data_volume_mount_point" {
  description = "Mount point for the persistent data volume"
  value       = "/data"
}

# =============================================================================
# Security Information Outputs
# =============================================================================

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.remote_desktop.id
}

output "key_pair_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.main.key_name
}

output "private_key_file" {
  description = "Location of the private key file"
  value       = "${var.key_pair_name}.pem"
}

# =============================================================================
# Network Information Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "allowed_ip" {
  description = "IP address allowed to access the instance"
  value       = local.my_ip
}

# =============================================================================
# Monitoring Information Outputs
# =============================================================================

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.main.name
}

output "cloudwatch_logs_url" {
  description = "URL to view CloudWatch logs"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.main.name, "/", "$252F")}"
}

# =============================================================================
# Quick Start Information
# =============================================================================

output "quick_start_instructions" {
  description = "Quick start instructions"
  value = <<-EOT
    
    🚀 Remote Desktop Environment Ready!
    
    1. Connect via SSH:
       ${chomp("ssh -i ${var.key_pair_name}.pem ubuntu@${aws_instance.remote_desktop.public_ip}")}
    
    2. Set up VNC tunnel:
       ${chomp("ssh -L ${var.vnc_port}:localhost:${var.vnc_port} -i ${var.key_pair_name}.pem ubuntu@${aws_instance.remote_desktop.public_ip}")}
    
    3. Connect VNC viewer to: localhost:${var.vnc_port}
       Password: (set in your .env file)
    
    4. Or use the helper scripts:
       ./scripts/connect.sh    # Establish VNC tunnel
       ./scripts/status.sh     # Check instance status
       ./scripts/stop.sh       # Stop instance (preserves data)
       ./scripts/start.sh      # Start stopped instance
    
    📊 Instance Details:
    - Type: ${aws_instance.remote_desktop.instance_type}
    - Public IP: ${aws_instance.remote_desktop.public_ip}
    - Data Volume: ${aws_ebs_volume.data.size}GB (${aws_ebs_volume.data.type})
    - Region: ${var.aws_region}
    
    💡 Next Steps:
    - Install additional software via SSH or desktop
    - Create an AMI snapshot once configured
    - Set up automated backups if needed
    
    EOT
}

# =============================================================================
# Cost Information Outputs
# =============================================================================

output "estimated_hourly_cost" {
  description = "Estimated hourly cost information"
  value = {
    note = "Costs vary by region and usage"
    components = [
      "EC2 instance (${aws_instance.remote_desktop.instance_type})",
      "EBS storage (${aws_ebs_volume.data.size}GB ${aws_ebs_volume.data.type})",
      "Data transfer (minimal for VNC/SSH)"
    ]
    cost_optimization_tips = [
      "Stop instance when not in use",
      "Use spot instances for non-critical workloads",
      "Monitor CloudWatch for unused resources"
    ]
  }
} 