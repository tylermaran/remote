#!/bin/bash

# AWS Remote Desktop - Stop Script
# This script stops the instance while preserving data

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please copy env.example to .env and configure it."
    exit 1
fi

echo "⏹️ Stopping AWS Remote Desktop Environment..."

# Get instance ID from Terraform state
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ No instance found in Terraform state."
    exit 1
fi

echo "📋 Instance ID: $INSTANCE_ID"

# Check instance state
INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text \
    --region "${AWS_REGION:-us-east-1}" 2>/dev/null || echo "terminated")

echo "📊 Current state: $INSTANCE_STATE"

case $INSTANCE_STATE in
    "running")
        echo "⏸️ Stopping instance..."
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "${AWS_REGION:-us-east-1}"
        
        echo "⏳ Waiting for instance to stop..."
        aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "${AWS_REGION:-us-east-1}"
        
        echo "✅ Instance stopped successfully!"
        echo ""
        echo "💾 Your data is preserved on the persistent volume."
        echo "💡 To restart: ./scripts/start.sh"
        ;;
    "stopped")
        echo "✅ Instance is already stopped."
        ;;
    "stopping")
        echo "⏳ Instance is already stopping..."
        aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "${AWS_REGION:-us-east-1}"
        echo "✅ Instance stopped successfully!"
        ;;
    "terminated")
        echo "⚠️ Instance is terminated. No action needed."
        ;;
    *)
        echo "⚠️ Instance is in state: $INSTANCE_STATE"
        echo "Cannot stop instance in this state."
        exit 1
        ;;
esac

# Show cost savings info
echo ""
echo "💰 Cost Savings:"
echo "   - EC2 instance charges: ⏹️ STOPPED"
echo "   - EBS volume charges: 💾 CONTINUING (preserves your data)"
echo "   - Data transfer charges: ⏹️ STOPPED"
echo ""
echo "🔄 To restart your environment with all data intact:"
echo "   ./scripts/start.sh" 