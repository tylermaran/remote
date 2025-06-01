#!/bin/bash

# Script to load environment variables and output as JSON for Terraform

# Default values in case .env doesn't exist
export AWS_REGION="${AWS_REGION:-us-east-1}"
export INSTANCE_TYPE="${INSTANCE_TYPE:-t3.large}"
export EBS_VOLUME_SIZE="${EBS_VOLUME_SIZE:-100}"
export VNC_PASSWORD="${VNC_PASSWORD:-SecurePassword123!}"
export PROJECT_NAME="${PROJECT_NAME:-remote-desktop}"
export ENVIRONMENT="${ENVIRONMENT:-development}"
export OWNER="${OWNER:-your-name}"

# Load .env file if it exists
if [ -f ".env" ]; then
    # Source the .env file, but only export lines that start with known variables
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi
        
        # Extract variable name and value
        if [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then
            var_name="${BASH_REMATCH[1]}"
            var_value="${BASH_REMATCH[2]}"
            
            # Remove quotes if present
            var_value=$(echo "$var_value" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
            
            # Export the variable
            export "$var_name"="$var_value"
        fi
    done < .env
fi

# Output as JSON for Terraform
cat << EOF
{
  "AWS_REGION": "$AWS_REGION",
  "INSTANCE_TYPE": "$INSTANCE_TYPE",
  "EBS_VOLUME_SIZE": "$EBS_VOLUME_SIZE",
  "VNC_PASSWORD": "$VNC_PASSWORD",
  "PROJECT_NAME": "$PROJECT_NAME",
  "ENVIRONMENT": "$ENVIRONMENT",
  "OWNER": "$OWNER",
  "USE_SPOT_INSTANCE": "${USE_SPOT_INSTANCE:-false}",
  "EBS_VOLUME_TYPE": "${EBS_VOLUME_TYPE:-gp3}",
  "DESKTOP_ENVIRONMENT": "${DESKTOP_ENVIRONMENT:-xfce4}",
  "VNC_PORT": "${VNC_PORT:-5901}",
  "RDP_PORT": "${RDP_PORT:-3389}",
  "AUTO_SHUTDOWN_ENABLED": "${AUTO_SHUTDOWN_ENABLED:-true}",
  "AUTO_SHUTDOWN_IDLE_MINUTES": "${AUTO_SHUTDOWN_IDLE_MINUTES:-60}",
  "INSTALL_NVIDIA_DRIVERS": "${INSTALL_NVIDIA_DRIVERS:-auto}",
  "INSTALL_DOCKER": "${INSTALL_DOCKER:-true}",
  "INSTALL_VSCODE": "${INSTALL_VSCODE:-true}",
  "INSTALL_CHROME": "${INSTALL_CHROME:-true}",
  "KEY_PAIR_NAME": "${KEY_PAIR_NAME:-remote-desktop-key}",
  "LOG_GROUP_NAME": "${LOG_GROUP_NAME:-/aws/ec2/remote-desktop}"
}
EOF 