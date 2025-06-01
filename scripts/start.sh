#!/bin/bash

# AWS Remote Desktop - Start Script
# This script starts the remote desktop environment

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please copy env.example to .env and configure it."
    exit 1
fi

echo "🚀 Starting AWS Remote Desktop Environment..."

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..."
    terraform init
fi

# Check if we have existing state
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")

if [ -n "$INSTANCE_ID" ]; then
    echo "📋 Found existing instance: $INSTANCE_ID"
    
    # Check instance state
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text \
        --region "${AWS_REGION:-us-east-1}" 2>/dev/null || echo "terminated")
    
    echo "📊 Instance state: $INSTANCE_STATE"
    
    case $INSTANCE_STATE in
        "running")
            echo "✅ Instance is already running!"
            PUBLIC_IP=$(terraform output -raw instance_public_ip)
            echo "🌐 Public IP: $PUBLIC_IP"
            ;;
        "stopped")
            echo "▶️ Starting stopped instance..."
            aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "${AWS_REGION:-us-east-1}"
            
            echo "⏳ Waiting for instance to be running..."
            aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "${AWS_REGION:-us-east-1}"
            
            # Update state to get new public IP
            terraform refresh
            PUBLIC_IP=$(terraform output -raw instance_public_ip)
            echo "✅ Instance started! Public IP: $PUBLIC_IP"
            ;;
        "terminated"|"")
            echo "🏗️ No running instance found. Creating new environment..."
            terraform plan
            terraform apply -auto-approve
            ;;
        *)
            echo "⏳ Instance is in state: $INSTANCE_STATE. Waiting..."
            aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "${AWS_REGION:-us-east-1}"
            PUBLIC_IP=$(terraform output -raw instance_public_ip)
            echo "✅ Instance ready! Public IP: $PUBLIC_IP"
            ;;
    esac
else
    echo "🏗️ No existing infrastructure found. Creating new environment..."
    terraform plan
    terraform apply -auto-approve
fi

echo ""
echo "🎉 Remote Desktop Environment is ready!"
echo ""
echo "📋 Connection Information:"
terraform output quick_start_instructions

echo ""
echo "💡 Next steps:"
echo "   1. Wait 2-3 minutes for setup to complete"
echo "   2. Run: ./scripts/connect.sh"
echo "   3. Or check status: ./scripts/status.sh" 