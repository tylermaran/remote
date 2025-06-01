#!/bin/bash

# AWS Remote Desktop - Connect Script
# This script establishes VNC tunnel for desktop access

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please copy env.example to .env and configure it."
    exit 1
fi

echo "🔗 Connecting to AWS Remote Desktop..."

# Get connection details from Terraform
PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
KEY_FILE=$(terraform output -raw private_key_file 2>/dev/null || echo "")
VNC_PORT="${VNC_PORT:-5901}"

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Cannot get instance public IP. Is the instance running?"
    echo "💡 Try: ./scripts/start.sh"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "❌ SSH key file not found: $KEY_FILE"
    echo "💡 Try running: terraform apply"
    exit 1
fi

echo "📋 Connection Details:"
echo "   Public IP: $PUBLIC_IP"
echo "   VNC Port: $VNC_PORT"
echo "   SSH Key: $KEY_FILE"

# Test SSH connectivity first
echo ""
echo "🔍 Testing SSH connectivity..."
if ! ssh -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "❌ Cannot connect via SSH. Instance might still be starting up."
    echo "⏳ Waiting for instance to be ready..."
    
    # Wait up to 5 minutes for SSH
    for i in {1..30}; do
        echo "   Attempt $i/30..."
        if ssh -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "echo 'SSH ready'" >/dev/null 2>&1; then
            echo "✅ SSH connection established!"
            break
        fi
        sleep 10
        
        if [ $i -eq 30 ]; then
            echo "❌ SSH connection failed after 5 minutes."
            echo "💡 Check instance status: ./scripts/status.sh"
            exit 1
        fi
    done
fi

# Check if VNC server is running
echo ""
echo "🔍 Checking VNC server status..."
VNC_STATUS=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "systemctl is-active vncserver@1.service" 2>/dev/null || echo "inactive")

if [ "$VNC_STATUS" != "active" ]; then
    echo "⚠️ VNC server is not running. Starting it..."
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "sudo systemctl start vncserver@1.service"
    sleep 3
fi

# Check if setup is complete
echo "🔍 Checking if setup is complete..."
SETUP_COMPLETE=$(ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$PUBLIC_IP" "test -f /var/log/user-data-completed && echo 'true' || echo 'false'" 2>/dev/null || echo "false")

if [ "$SETUP_COMPLETE" != "true" ]; then
    echo "⏳ Instance setup is still in progress..."
    echo "📋 You can monitor the setup process:"
    echo "   ssh -i $KEY_FILE ubuntu@$PUBLIC_IP 'tail -f /var/log/user-data.log'"
    echo ""
    echo "⏰ Setup typically takes 3-5 minutes. Please wait and try again."
    exit 1
fi

echo "✅ VNC server is ready!"

# Create SSH tunnel
echo ""
echo "🔗 Establishing VNC tunnel..."
echo "📡 Creating SSH tunnel: localhost:$VNC_PORT -> $PUBLIC_IP:$VNC_PORT"

# Kill any existing tunnel on the same port
if lsof -ti:$VNC_PORT >/dev/null 2>&1; then
    echo "🔄 Closing existing tunnel on port $VNC_PORT..."
    lsof -ti:$VNC_PORT | xargs kill -9 2>/dev/null || true
    sleep 1
fi

# Start tunnel in background
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -L $VNC_PORT:localhost:$VNC_PORT -N ubuntu@"$PUBLIC_IP" &
TUNNEL_PID=$!

# Give tunnel time to establish
sleep 3

# Check if tunnel is working
if ! kill -0 $TUNNEL_PID 2>/dev/null; then
    echo "❌ Failed to establish VNC tunnel."
    exit 1
fi

echo "✅ VNC tunnel established! (PID: $TUNNEL_PID)"
echo ""
echo "🖥️ Remote Desktop Connection Ready!"
echo ""
echo "📋 VNC Connection Details:"
echo "   Server: localhost:$VNC_PORT"
echo "   Password: [Set in your .env file]"
echo ""
echo "💡 Connect using a VNC client:"
echo "   - macOS: Built-in Screen Sharing or RealVNC Viewer"
echo "   - Windows: RealVNC Viewer, TightVNC, or UltraVNC"
echo "   - Linux: Remmina, TigerVNC, or vncviewer"
echo ""
echo "🔗 Quick connect (macOS):"
echo "   open vnc://localhost:$VNC_PORT"
echo ""
echo "⏹️ To close the tunnel: kill $TUNNEL_PID"
echo "📱 To keep tunnel running: Leave this terminal open"

# Keep script running to maintain tunnel
echo ""
echo "🔄 Tunnel is active. Press Ctrl+C to close..."
trap "echo ''; echo '🔗 Closing VNC tunnel...'; kill $TUNNEL_PID 2>/dev/null; echo '✅ Tunnel closed.'; exit 0" INT

# Wait for tunnel process
wait $TUNNEL_PID 2>/dev/null || echo "🔗 Tunnel disconnected." 