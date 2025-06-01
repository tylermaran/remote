# AWS Remote Desktop Environment

A Terraform-based solution for spinning up remote desktop environments on AWS with GPU support, persistent storage, and GUI access.

## Features

- 🖥️ **GUI Desktop Environment**: Ubuntu with XFCE desktop accessible via VNC/RDP
- 🚀 **Flexible Instance Types**: Easy configuration for CPU/GPU instances (including p3, g4dn, etc.)
- 💾 **Persistent Storage**: EBS volume that persists across instance restarts
- 🔒 **Secure Access**: VPN/SSH tunnel setup with security groups
- 📊 **Cost Optimization**: Easy spin up/down with preserved data
- 🎛️ **Configurable**: Environment variables for easy customization

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Your MacBook  │────│  AWS EC2 Instance │────│ Persistent EBS  │
│                 │    │                  │    │     Volume      │
│  VNC/RDP Client │    │  Ubuntu + XFCE   │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Quick Start

### 1. Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (`brew install terraform`)
- VNC viewer (recommend RealVNC Viewer)

### 2. Setup

```bash
# Clone and setup
git clone <your-repo>
cd remote

# Copy and configure environment
cp .env.example .env
# Edit .env with your preferences

# Initialize Terraform
terraform init

# Plan and apply
terraform plan
terraform apply
```

### 3. Connect

After deployment, you'll get connection details:

```bash
# SSH tunnel for VNC (recommended)
ssh -L 5901:localhost:5901 ubuntu@<instance-ip> -i <key-path>

# Then connect VNC viewer to: localhost:5901
# Password: (set in .env file)
```

## Configuration

### Instance Types

Configure in `.env`:

```bash
# For CPU-intensive tasks
INSTANCE_TYPE=c5.4xlarge

# For GPU workloads
INSTANCE_TYPE=g4dn.xlarge    # NVIDIA T4
INSTANCE_TYPE=g4dn.2xlarge   # NVIDIA T4 (more memory)
INSTANCE_TYPE=p3.2xlarge     # NVIDIA V100

# For development
INSTANCE_TYPE=t3.large       # Cost-effective for light work
```

### Storage

```bash
# Persistent volume size (GB)
EBS_VOLUME_SIZE=100

# Volume type (gp3 recommended for cost/performance)
EBS_VOLUME_TYPE=gp3
```

## Management Scripts

### Start Environment

```bash
./scripts/start.sh
```

### Stop Environment (preserves data)

```bash
./scripts/stop.sh
```

### Connect via VNC

```bash
./scripts/connect.sh
```

### Get Instance Info

```bash
./scripts/status.sh
```

### Destroy Everything

```bash
./scripts/destroy.sh
```

## Installed Software

The base image includes:

- **Desktop**: XFCE4 (lightweight, fast)
- **Remote Access**: VNC Server, xRDP
- **Development**:
  - Python 3.x with pip
  - Node.js & npm
  - Git
  - VS Code
  - Docker
- **Utilities**:
  - Firefox
  - File manager
  - Terminal
  - System monitoring tools

## Cost Optimization

- **Automatic shutdown**: Instance stops automatically if idle (configurable)
- **Spot instances**: Option to use spot instances for cost savings
- **Right-sizing**: Easy instance type changes
- **Storage optimization**: Separate OS and data volumes

## Security

- Security groups restrict access to your IP only
- SSH key-based authentication
- VNC/RDP access via SSH tunnel (no direct internet exposure)
- Optional: VPN setup for team access

## Troubleshooting

### Can't connect to VNC

1. Check security group allows your IP
2. Verify SSH tunnel is active
3. Check VNC server is running: `sudo systemctl status vncserver@:1`

### Instance won't start

1. Check AWS limits for instance type
2. Verify availability in your region
3. Check spot instance availability (if using spot)

### Performance issues

1. Consider larger instance type
2. Check EBS volume performance (gp3 with provisioned IOPS)
3. Monitor CloudWatch metrics

## Customization

### Adding Software

Edit `user-data.sh` to install additional packages during instance launch.

### Custom AMI

After setting up your environment, create a custom AMI:

```bash
./scripts/create-ami.sh
```

### Multiple Environments

Copy and modify terraform configuration for different setups (dev/staging/prod).

## Costs

Typical costs (us-east-1):

| Instance Type | vCPUs | RAM  | GPU  | $/hour | $/month (8hrs/day) |
| ------------- | ----- | ---- | ---- | ------ | ------------------ |
| t3.large      | 2     | 8GB  | -    | $0.08  | ~$20               |
| c5.2xlarge    | 8     | 16GB | -    | $0.34  | ~$85               |
| g4dn.xlarge   | 4     | 16GB | T4   | $0.526 | ~$130              |
| p3.2xlarge    | 8     | 61GB | V100 | $3.06  | ~$760              |

_Plus EBS storage: ~$10/month per 100GB_

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## License

MIT License - see LICENSE file for details.
