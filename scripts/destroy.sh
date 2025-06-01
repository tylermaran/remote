#!/bin/bash

# AWS Remote Desktop - Destroy Script
# This script completely destroys the environment including data volume

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please copy env.example to .env and configure it."
    exit 1
fi

echo "🗑️ AWS Remote Desktop Environment Destruction"
echo "============================================="

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ No Terraform state found. Nothing to destroy."
    exit 0
fi

# Get instance and volume info
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
DATA_VOLUME_ID=$(terraform output -raw data_volume_id 2>/dev/null || echo "")

if [ -n "$INSTANCE_ID" ]; then
    echo "📋 Found resources to destroy:"
    echo "   Instance ID: $INSTANCE_ID"
    echo "   Data Volume: $DATA_VOLUME_ID"
    echo ""
fi

# Warning message
echo "⚠️  WARNING: This will PERMANENTLY delete:"
echo "   ❌ EC2 instance and all its data"
echo "   ❌ Persistent data volume and ALL YOUR DATA"
echo "   ❌ Security groups and networking"
echo "   ❌ SSH key pair"
echo ""
echo "💾 DATA LOSS WARNING:"
echo "   All files stored on the instance and data volume will be lost!"
echo "   This action cannot be undone!"
echo ""

# First confirmation
read -p "❓ Are you sure you want to destroy everything? (type 'yes' to continue): " CONFIRM1
if [ "$CONFIRM1" != "yes" ]; then
    echo "❌ Destruction cancelled."
    exit 0
fi

echo ""
echo "🚨 FINAL WARNING:"
echo "   This is your last chance to back up any important data!"
echo "   Once you continue, ALL DATA will be permanently lost."
echo ""

# Second confirmation with instance ID
if [ -n "$INSTANCE_ID" ]; then
    read -p "❓ Type the instance ID ($INSTANCE_ID) to confirm: " CONFIRM2
    if [ "$CONFIRM2" != "$INSTANCE_ID" ]; then
        echo "❌ Instance ID mismatch. Destruction cancelled."
        exit 0
    fi
fi

echo ""
echo "🔄 Starting destruction process..."

# Check if instance is running and offer to create backup
if [ -n "$INSTANCE_ID" ]; then
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text \
        --region "${AWS_REGION:-us-east-1}" 2>/dev/null || echo "terminated")
    
    if [ "$INSTANCE_STATE" = "running" ]; then
        echo "📋 Instance is currently running."
        read -p "❓ Would you like to create an AMI backup before destroying? (y/N): " CREATE_AMI
        
        if [[ "$CREATE_AMI" =~ ^[Yy]$ ]]; then
            echo "📸 Creating AMI backup..."
            AMI_NAME="remote-desktop-backup-$(date +%Y%m%d-%H%M%S)"
            AMI_ID=$(aws ec2 create-image \
                --instance-id "$INSTANCE_ID" \
                --name "$AMI_NAME" \
                --description "Backup before destruction" \
                --no-reboot \
                --output text \
                --region "${AWS_REGION:-us-east-1}")
            
            echo "✅ AMI backup created: $AMI_ID ($AMI_NAME)"
            echo "💡 You can launch a new instance from this AMI later if needed."
        fi
    fi
fi

# Create EBS snapshot if data volume exists
if [ -n "$DATA_VOLUME_ID" ]; then
    echo ""
    read -p "❓ Would you like to create a snapshot of the data volume before destroying? (y/N): " CREATE_SNAPSHOT
    
    if [[ "$CREATE_SNAPSHOT" =~ ^[Yy]$ ]]; then
        echo "📸 Creating EBS snapshot..."
        SNAPSHOT_ID=$(aws ec2 create-snapshot \
            --volume-id "$DATA_VOLUME_ID" \
            --description "Data backup before destruction - $(date)" \
            --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=remote-desktop-data-backup-$(date +%Y%m%d-%H%M%S)}]" \
            --output text \
            --query 'SnapshotId' \
            --region "${AWS_REGION:-us-east-1}")
        
        echo "✅ EBS snapshot created: $SNAPSHOT_ID"
        echo "💡 You can restore data from this snapshot later if needed."
    fi
fi

echo ""
echo "🗑️ Running Terraform destroy..."

# Run terraform destroy
if terraform destroy -auto-approve; then
    echo "✅ Terraform destroy completed successfully!"
else
    echo "❌ Terraform destroy failed. Some resources may still exist."
    echo "💡 Check AWS console and clean up manually if needed."
    exit 1
fi

# Clean up local files
echo ""
echo "🧹 Cleaning up local files..."

# Remove SSH key files
if [ -f "${KEY_PAIR_NAME:-remote-desktop-key}.pem" ]; then
    rm -f "${KEY_PAIR_NAME:-remote-desktop-key}.pem"
    echo "   ✅ Removed SSH private key"
fi

# Remove Terraform state files
if [ -f "terraform.tfstate" ]; then
    rm -f terraform.tfstate
    echo "   ✅ Removed Terraform state"
fi

if [ -f "terraform.tfstate.backup" ]; then
    rm -f terraform.tfstate.backup
    echo "   ✅ Removed Terraform state backup"
fi

# Remove .terraform directory
if [ -d ".terraform" ]; then
    rm -rf .terraform
    echo "   ✅ Removed Terraform working directory"
fi

echo ""
echo "🎉 Destruction completed successfully!"
echo ""
echo "📋 Summary:"
echo "   ✅ All AWS resources destroyed"
echo "   ✅ Local files cleaned up"
echo "   💰 No more charges will be incurred"

if [ -n "$AMI_ID" ]; then
    echo "   📸 AMI backup available: $AMI_ID"
fi

if [ -n "$SNAPSHOT_ID" ]; then
    echo "   📸 Data snapshot available: $SNAPSHOT_ID"
fi

echo ""
echo "💡 To recreate the environment:"
echo "   1. Configure .env file"
echo "   2. Run: ./scripts/start.sh"
echo ""
echo "🔍 To restore from backup:"
echo "   1. Launch instance from AMI: $AMI_ID (if created)"
echo "   2. Create volume from snapshot: $SNAPSHOT_ID (if created)" 