#!/bin/bash

# AWS Remote Desktop - Status Script
# This script shows the current status of the environment

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please copy env.example to .env and configure it."
    exit 1
fi

echo "📊 AWS Remote Desktop Environment Status"
echo "========================================"

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ No Terraform state found. Environment not created yet."
    echo "💡 Run: ./scripts/start.sh to create the environment"
    exit 1
fi

# Get basic info from Terraform
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
INSTANCE_TYPE=$(terraform output -raw instance_type 2>/dev/null || echo "")
DATA_VOLUME_ID=$(terraform output -raw data_volume_id 2>/dev/null || echo "")
KEY_FILE=$(terraform output -raw private_key_file 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ Cannot get instance information from Terraform state."
    exit 1
fi

echo "🔍 Instance Information:"
echo "   Instance ID: $INSTANCE_ID"
echo "   Instance Type: $INSTANCE_TYPE"
echo "   Public IP: $PUBLIC_IP"
echo "   Data Volume: $DATA_VOLUME_ID"
echo ""

# Get detailed instance status from AWS
echo "📡 AWS Instance Status:"
INSTANCE_INFO=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].[State.Name,StateReason.Message,LaunchTime,Placement.AvailabilityZone]' \
    --output text \
    --region "${AWS_REGION:-us-east-1}" 2>/dev/null || echo "ERROR getting instance info")

if [ "$INSTANCE_INFO" = "ERROR getting instance info" ]; then
    echo "   ❌ Cannot get instance status from AWS"
else
    INSTANCE_STATE=$(echo "$INSTANCE_INFO" | cut -f1)
    STATE_REASON=$(echo "$INSTANCE_INFO" | cut -f2)
    LAUNCH_TIME=$(echo "$INSTANCE_INFO" | cut -f3)
    AZ=$(echo "$INSTANCE_INFO" | cut -f4)
    
    # Status emoji based on state
    case $INSTANCE_STATE in
        "running") STATUS_EMOJI="✅" ;;
        "stopped") STATUS_EMOJI="⏹️" ;;
        "stopping") STATUS_EMOJI="⏸️" ;;
        "starting") STATUS_EMOJI="▶️" ;;
        "pending") STATUS_EMOJI="⏳" ;;
        "terminated") STATUS_EMOJI="❌" ;;
        *) STATUS_EMOJI="❓" ;;
    esac
    
    echo "   State: $STATUS_EMOJI $INSTANCE_STATE"
    echo "   Reason: $STATE_REASON"
    echo "   Launch Time: $LAUNCH_TIME"
    echo "   Availability Zone: $AZ"
fi

echo ""

# If instance is running, get more detailed status
if [ "$INSTANCE_STATE" = "running" ]; then
    echo "🔍 Connection Status:"
    
    # Test SSH connectivity
    if [ -f "$KEY_FILE" ] && [ -n "$PUBLIC_IP" ]; then
        echo -n "   SSH Connection: "
        if ssh -i "$KEY_FILE" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "echo 'OK'" >/dev/null 2>&1; then
            echo "✅ Connected"
            
            # Check system status
            echo ""
            echo "🖥️ System Status:"
            
            # Get system info via SSH
            SYSTEM_INFO=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "
                echo \"Uptime: \$(uptime -p)\"
                echo \"Load: \$(uptime | awk -F'load average:' '{print \$2}' | xargs)\"
                echo \"Memory: \$(free -h | awk '/^Mem:/ {print \$3\"/\"\$2}')\"
                echo \"Disk /: \$(df -h / | awk 'NR==2 {print \$3\"/\"\$2\" (\"\$5\" used)\"}')\"
                echo \"Disk /data: \$(df -h /data 2>/dev/null | awk 'NR==2 {print \$3\"/\"\$2\" (\"\$5\" used)\"}' || echo 'Not mounted')\"
            " 2>/dev/null || echo "   ❌ Cannot get system info")
            
            echo "$SYSTEM_INFO" | sed 's/^/   /'
            
            echo ""
            echo "🖥️ Desktop Services:"
            
            # Check VNC and RDP status
            VNC_STATUS=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "systemctl is-active vncserver@1.service" 2>/dev/null || echo "inactive")
            RDP_STATUS=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "systemctl is-active xrdp.service" 2>/dev/null || echo "inactive")
            
            VNC_EMOJI=$([ "$VNC_STATUS" = "active" ] && echo "✅" || echo "❌")
            RDP_EMOJI=$([ "$RDP_STATUS" = "active" ] && echo "✅" || echo "❌")
            
            echo "   VNC Server: $VNC_EMOJI $VNC_STATUS"
            echo "   RDP Server: $RDP_EMOJI $RDP_STATUS"
            
            # Check if setup is complete
            SETUP_COMPLETE=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "test -f /var/log/user-data-completed && echo 'true' || echo 'false'" 2>/dev/null || echo "false")
            
            echo ""
            if [ "$SETUP_COMPLETE" = "true" ]; then
                echo "🎉 Setup Status: ✅ Complete"
            else
                echo "⏳ Setup Status: 🔄 In Progress"
                echo "   Monitor with: ssh -i $KEY_FILE ubuntu@$PUBLIC_IP 'tail -f /var/log/user-data.log'"
            fi
            
            # Check for active VNC connections
            VNC_CONNECTIONS=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "netstat -tn | grep ':${VNC_PORT:-5901} ' | wc -l" 2>/dev/null || echo "0")
            if [ "$VNC_CONNECTIONS" -gt 0 ]; then
                echo ""
                echo "🔗 Active Connections: $VNC_CONNECTIONS VNC client(s) connected"
            fi
            
        else
            echo "❌ Failed (timeout or connection refused)"
        fi
    else
        echo "   SSH Connection: ❌ Missing key file or public IP"
    fi
    
elif [ "$INSTANCE_STATE" = "stopped" ]; then
    echo "💡 Instance is stopped. Start with: ./scripts/start.sh"
    
elif [ "$INSTANCE_STATE" = "stopping" ]; then
    echo "⏳ Instance is stopping..."
    
elif [ "$INSTANCE_STATE" = "starting" ]; then
    echo "⏳ Instance is starting..."
    echo "💡 Connect when ready: ./scripts/connect.sh"
    
elif [ "$INSTANCE_STATE" = "terminated" ]; then
    echo "❌ Instance is terminated. Create new with: ./scripts/start.sh"
fi

# Volume information
echo ""
echo "💾 Storage Status:"
if [ -n "$DATA_VOLUME_ID" ]; then
    VOLUME_INFO=$(aws ec2 describe-volumes \
        --volume-ids "$DATA_VOLUME_ID" \
        --query 'Volumes[0].[State,Size,VolumeType,Encrypted]' \
        --output text \
        --region "${AWS_REGION:-us-east-1}" 2>/dev/null || echo "ERROR")
    
    if [ "$VOLUME_INFO" != "ERROR" ]; then
        VOLUME_STATE=$(echo "$VOLUME_INFO" | cut -f1)
        VOLUME_SIZE=$(echo "$VOLUME_INFO" | cut -f2)
        VOLUME_TYPE=$(echo "$VOLUME_INFO" | cut -f3)
        VOLUME_ENCRYPTED=$(echo "$VOLUME_INFO" | cut -f4)
        
        VOLUME_EMOJI=$([ "$VOLUME_STATE" = "available" ] && echo "✅" || echo "🔄")
        ENCRYPT_EMOJI=$([ "$VOLUME_ENCRYPTED" = "True" ] && echo "🔒" || echo "🔓")
        
        echo "   Data Volume: $VOLUME_EMOJI $VOLUME_STATE"
        echo "   Size: ${VOLUME_SIZE}GB ($VOLUME_TYPE)"
        echo "   Encryption: $ENCRYPT_EMOJI $VOLUME_ENCRYPTED"
    else
        echo "   ❌ Cannot get volume status"
    fi
fi

# Cost estimation
echo ""
echo "💰 Cost Information:"
REGION="${AWS_REGION:-us-east-1}"
if [ "$INSTANCE_STATE" = "running" ]; then
    echo "   Current Status: 💸 Charging (instance running)"
elif [ "$INSTANCE_STATE" = "stopped" ]; then
    echo "   Current Status: 💰 Minimal cost (only storage)"
else
    echo "   Current Status: ❓ Variable"
fi

echo "   Region: $REGION"
echo "   💡 Stop instance to save costs: ./scripts/stop.sh"

echo ""
echo "🔧 Management Commands:"
echo "   Start:    ./scripts/start.sh"
echo "   Stop:     ./scripts/stop.sh"
echo "   Connect:  ./scripts/connect.sh"
echo "   Destroy:  ./scripts/destroy.sh" 