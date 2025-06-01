#!/bin/bash

# AWS Remote Desktop User Data Script
# This script sets up Ubuntu with desktop environment and remote access

set -e

# Configuration from Terraform variables
VNC_PASSWORD="${vnc_password}"
DESKTOP_ENV="${desktop_environment}"
VNC_PORT="${vnc_port}"
RDP_PORT="${rdp_port}"
AUTO_SHUTDOWN_ENABLED="${auto_shutdown_enabled}"
AUTO_SHUTDOWN_IDLE_MINUTES="${auto_shutdown_idle_minutes}"
INSTALL_NVIDIA_DRIVERS="${install_nvidia_drivers}"
INSTALL_DOCKER="${install_docker}"
INSTALL_VSCODE="${install_vscode}"
INSTALL_CHROME="${install_chrome}"
CUSTOM_PACKAGES="${custom_packages}"
LOG_GROUP_NAME="${log_group_name}"

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting AWS Remote Desktop Setup ==="
echo "Timestamp: $(date)"
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"

# Update system
echo "=== Updating system packages ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install basic packages
echo "=== Installing basic packages ==="
apt-get install -y \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    curl \
    wget \
    unzip \
    zip \
    git \
    vim \
    nano \
    htop \
    tree \
    net-tools \
    dbus-x11 \
    $CUSTOM_PACKAGES

# Install CloudWatch agent
echo "=== Installing CloudWatch agent ==="
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/user-data.log",
                        "log_group_name": "$LOG_GROUP_NAME",
                        "log_stream_name": "{instance_id}/user-data"
                    },
                    {
                        "file_path": "/var/log/syslog",
                        "log_group_name": "$LOG_GROUP_NAME",
                        "log_stream_name": "{instance_id}/syslog"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Install desktop environment
echo "=== Installing desktop environment: $DESKTOP_ENV ==="
case $DESKTOP_ENV in
    "xfce4")
        apt-get install -y xfce4 xfce4-goodies
        ;;
    "gnome")
        apt-get install -y ubuntu-desktop-minimal
        ;;
    "kde")
        apt-get install -y kubuntu-desktop
        ;;
    *)
        echo "Unknown desktop environment: $DESKTOP_ENV, defaulting to XFCE4"
        apt-get install -y xfce4 xfce4-goodies
        ;;
esac

# Install VNC server
echo "=== Installing VNC server ==="
apt-get install -y tightvncserver

# Install xRDP
echo "=== Installing xRDP ==="
apt-get install -y xrdp
systemctl enable xrdp

# Configure xRDP for XFCE
if [ "$DESKTOP_ENV" == "xfce4" ]; then
    echo "xfce4-session" > /etc/xrdp/startwm.sh
    chmod +x /etc/xrdp/startwm.sh
fi

# Create ubuntu user desktop setup
echo "=== Setting up VNC for ubuntu user ==="
sudo -u ubuntu mkdir -p /home/ubuntu/.vnc

# Set VNC password for ubuntu user
sudo -u ubuntu bash << EOF
echo "$VNC_PASSWORD" | vncpasswd -f > /home/ubuntu/.vnc/passwd
chmod 600 /home/ubuntu/.vnc/passwd
EOF

# Create VNC startup script for ubuntu user
sudo -u ubuntu cat > /home/ubuntu/.vnc/xstartup << 'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
xsetroot -solid grey
export XKL_XMODMAP_DISABLE=1
if [ "$DESKTOP_ENV" == "gnome" ]; then
    gnome-session &
elif [ "$DESKTOP_ENV" == "kde" ]; then
    startkde &
else
    startxfce4 &
fi
EOF

chmod +x /home/ubuntu/.vnc/xstartup

# Create systemd service for VNC
cat > /etc/systemd/system/vncserver@.service << EOF
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu

PIDFile=/home/ubuntu/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1920x1080 :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

# Enable and start VNC server
systemctl daemon-reload
systemctl enable vncserver@1.service
systemctl start vncserver@1.service

# Install NVIDIA drivers if needed
if [ "$INSTALL_NVIDIA_DRIVERS" == "true" ]; then
    echo "=== Installing NVIDIA drivers ==="
    apt-get install -y nvidia-driver-470 nvidia-utils-470
    
    # Install CUDA if GPU instance
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
    mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.0.0/local_installers/cuda-repo-ubuntu2204-12-0-local_12.0.0-525.60.13-1_amd64.deb
    dpkg -i cuda-repo-ubuntu2204-12-0-local_12.0.0-525.60.13-1_amd64.deb
    cp /var/cuda-repo-ubuntu2204-12-0-local/cuda-*-keyring.gpg /usr/share/keyrings/
    apt-get update
    apt-get -y install cuda
fi

# Install Docker if enabled
if [ "$INSTALL_DOCKER" == "true" ]; then
    echo "=== Installing Docker ==="
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    usermod -aG docker ubuntu
    systemctl enable docker
    systemctl start docker
fi

# Install Visual Studio Code if enabled
if [ "$INSTALL_VSCODE" == "true" ]; then
    echo "=== Installing Visual Studio Code ==="
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    apt-get update
    apt-get install -y code
fi

# Install Google Chrome if enabled
if [ "$INSTALL_CHROME" == "true" ]; then
    echo "=== Installing Google Chrome ==="
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
    apt-get update
    apt-get install -y google-chrome-stable
fi

# Install Python development tools
echo "=== Installing Python development tools ==="
apt-get install -y python3 python3-pip python3-venv python3-dev
pip3 install --upgrade pip setuptools wheel
pip3 install jupyter notebook pandas numpy matplotlib seaborn scikit-learn

# Install Node.js
echo "=== Installing Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Mount persistent volume
echo "=== Setting up persistent volume ==="
# Wait for the volume to be attached
while [ ! -e /dev/xvdf ]; do
    echo "Waiting for volume to be attached..."
    sleep 5
done

# Check if the volume has a filesystem
if ! blkid /dev/xvdf; then
    echo "Creating filesystem on /dev/xvdf"
    mkfs.ext4 /dev/xvdf
fi

# Create mount point and mount
mkdir -p /data
mount /dev/xvdf /data

# Add to fstab for persistent mounting
echo "/dev/xvdf /data ext4 defaults,nofail 0 2" >> /etc/fstab

# Set ownership to ubuntu user
chown -R ubuntu:ubuntu /data

# Create symbolic link in ubuntu home
sudo -u ubuntu ln -sf /data /home/ubuntu/data

# Set up auto-shutdown if enabled
if [ "$AUTO_SHUTDOWN_ENABLED" == "true" ]; then
    echo "=== Setting up auto-shutdown ==="
    cat > /usr/local/bin/auto-shutdown.sh << EOF
#!/bin/bash

# Auto-shutdown script
IDLE_MINUTES=$AUTO_SHUTDOWN_IDLE_MINUTES
LOAD_THRESHOLD=0.1

# Get load average (1 minute)
LOAD=\$(uptime | awk -F'load average:' '{ print \$2 }' | awk -F',' '{ print \$1 }' | xargs)

# Check if load is below threshold
if (( \$(echo "\$LOAD < \$LOAD_THRESHOLD" | bc -l) )); then
    # Check if any users are logged in via VNC/RDP
    VNC_USERS=\$(netstat -tnl | grep ":$VNC_PORT " | wc -l)
    RDP_USERS=\$(netstat -tnl | grep ":$RDP_PORT " | wc -l)
    
    if [ \$VNC_USERS -eq 0 ] && [ \$RDP_USERS -eq 0 ]; then
        logger "Auto-shutdown: No active connections and low load, shutting down in 5 minutes"
        wall "System will shutdown in 5 minutes due to inactivity"
        shutdown -h +5 "Auto-shutdown due to inactivity"
    fi
fi
EOF

    chmod +x /usr/local/bin/auto-shutdown.sh
    
    # Add cron job to check every X minutes
    echo "*/$AUTO_SHUTDOWN_IDLE_MINUTES * * * * root /usr/local/bin/auto-shutdown.sh" >> /etc/crontab
fi

# Create desktop shortcuts
echo "=== Creating desktop shortcuts ==="
sudo -u ubuntu mkdir -p /home/ubuntu/Desktop

# Terminal shortcut
sudo -u ubuntu cat > /home/ubuntu/Desktop/Terminal.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Comment=Use the command line
Categories=System;TerminalEmulator;
EOF

# File Manager shortcut
sudo -u ubuntu cat > /home/ubuntu/Desktop/Files.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Files
Exec=thunar
Icon=system-file-manager
Comment=Browse the file system
Categories=System;FileManager;
EOF

# Make shortcuts executable
chmod +x /home/ubuntu/Desktop/*.desktop

# Set up firewall
echo "=== Configuring firewall ==="
ufw --force enable
ufw allow ssh
ufw allow $VNC_PORT
ufw allow $RDP_PORT

# Clean up
echo "=== Cleaning up ==="
apt-get autoremove -y
apt-get autoclean
rm -f /tmp/*.deb

# Set timezone
timedatectl set-timezone UTC

# Restart services
systemctl restart xrdp
systemctl restart vncserver@1

echo "=== Setup completed successfully ==="
echo "VNC Server: localhost:$VNC_PORT"
echo "RDP Server: localhost:$RDP_PORT"
echo "Data volume mounted at: /data"
echo "Desktop environment: $DESKTOP_ENV"
echo "Auto-shutdown enabled: $AUTO_SHUTDOWN_ENABLED"

# Log completion
logger "AWS Remote Desktop setup completed successfully"

# Create a completion marker
touch /var/log/user-data-completed 