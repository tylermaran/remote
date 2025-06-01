# AWS Remote Desktop Environment Makefile
# Convenient commands for managing your remote desktop

.PHONY: help init start stop connect status destroy clean

# Default target
help:
	@echo "AWS Remote Desktop Environment"
	@echo "=============================="
	@echo ""
	@echo "Available commands:"
	@echo "  make setup     - Initial setup (copy env file, init terraform)"
	@echo "  make start     - Start/create the remote desktop environment"
	@echo "  make stop      - Stop the instance (preserves data)"
	@echo "  make connect   - Connect via VNC tunnel"
	@echo "  make status    - Show environment status"
	@echo "  make destroy   - Completely destroy environment (with confirmation)"
	@echo "  make clean     - Clean up local files"
	@echo "  make ssh       - SSH into the instance"
	@echo "  make logs      - View instance setup logs"
	@echo ""
	@echo "Cost-saving tips:"
	@echo "  - Use 'make stop' when not using the desktop"
	@echo "  - Use 'make start' to resume with all data intact"
	@echo "  - Monitor costs with 'make status'"

# Initial setup
setup:
	@echo "🔧 Setting up AWS Remote Desktop Environment..."
	@if [ ! -f .env ]; then \
		echo "📋 Copying environment configuration..."; \
		cp env.example .env; \
		echo "✅ Environment file created!"; \
		echo ""; \
		echo "📝 Please edit .env and configure:"; \
		echo "   - AWS_REGION (default: us-east-1)"; \
		echo "   - INSTANCE_TYPE (e.g., t3.large, g4dn.xlarge)"; \
		echo "   - VNC_PASSWORD (for desktop access)"; \
		echo "   - OWNER (your name)"; \
		echo ""; \
		echo "💡 Then run: make start"; \
	else \
		echo "✅ Environment file already exists"; \
	fi

# Initialize Terraform
init:
	@echo "🔧 Initializing Terraform..."
	terraform init

# Start environment
start:
	@./scripts/start.sh

# Stop environment
stop:
	@./scripts/stop.sh

# Connect to environment
connect:
	@./scripts/connect.sh

# Show status
status:
	@./scripts/status.sh

# Destroy environment
destroy:
	@./scripts/destroy.sh

# SSH into instance
ssh:
	@echo "🔗 Connecting via SSH..."
	@if [ -f terraform.tfstate ]; then \
		PUBLIC_IP=$$(terraform output -raw instance_public_ip 2>/dev/null); \
		KEY_FILE=$$(terraform output -raw private_key_file 2>/dev/null); \
		if [ -n "$$PUBLIC_IP" ] && [ -f "$$KEY_FILE" ]; then \
			ssh -i $$KEY_FILE ubuntu@$$PUBLIC_IP; \
		else \
			echo "❌ Cannot get connection details. Is the instance running?"; \
		fi \
	else \
		echo "❌ No Terraform state found. Run 'make start' first."; \
	fi

# View logs
logs:
	@echo "📋 Viewing instance setup logs..."
	@if [ -f terraform.tfstate ]; then \
		PUBLIC_IP=$$(terraform output -raw instance_public_ip 2>/dev/null); \
		KEY_FILE=$$(terraform output -raw private_key_file 2>/dev/null); \
		if [ -n "$$PUBLIC_IP" ] && [ -f "$$KEY_FILE" ]; then \
			ssh -i $$KEY_FILE ubuntu@$$PUBLIC_IP 'tail -f /var/log/user-data.log'; \
		else \
			echo "❌ Cannot get connection details. Is the instance running?"; \
		fi \
	else \
		echo "❌ No Terraform state found. Run 'make start' first."; \
	fi

# Clean up local files
clean:
	@echo "🧹 Cleaning up local files..."
	@rm -f *.pem *.key
	@rm -rf .terraform
	@rm -f terraform.tfstate terraform.tfstate.backup
	@rm -f *.log
	@echo "✅ Local files cleaned up"

# Show current costs (requires AWS CLI)
costs:
	@echo "💰 Estimating current costs..."
	@if [ -f terraform.tfstate ]; then \
		INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null); \
		REGION=$$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1"); \
		if [ -n "$$INSTANCE_ID" ]; then \
			echo "📋 Getting cost information for instance: $$INSTANCE_ID"; \
			aws ce get-cost-and-usage \
				--time-period Start=2024-01-01,End=2024-12-31 \
				--granularity MONTHLY \
				--metrics BlendedCost \
				--group-by Type=DIMENSION,Key=SERVICE \
				--filter file://cost-filter.json \
				--region $$REGION 2>/dev/null || echo "❌ Cost data unavailable"; \
		else \
			echo "❌ No instance found"; \
		fi \
	else \
		echo "❌ No Terraform state found"; \
	fi

# Quick development cycle
dev: stop start connect

# Production deployment with monitoring
prod:
	@echo "🚀 Production deployment..."
	@make start
	@sleep 30
	@make status

# Backup current environment
backup:
	@echo "📸 Creating backup..."
	@if [ -f terraform.tfstate ]; then \
		INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null); \
		DATA_VOLUME_ID=$$(terraform output -raw data_volume_id 2>/dev/null); \
		if [ -n "$$INSTANCE_ID" ]; then \
			echo "Creating AMI backup..."; \
			aws ec2 create-image --instance-id $$INSTANCE_ID --name "remote-desktop-backup-$$(date +%Y%m%d-%H%M%S)" --description "Manual backup"; \
		fi; \
		if [ -n "$$DATA_VOLUME_ID" ]; then \
			echo "Creating EBS snapshot..."; \
			aws ec2 create-snapshot --volume-id $$DATA_VOLUME_ID --description "Manual data backup - $$(date)"; \
		fi \
	else \
		echo "❌ No Terraform state found"; \
	fi 