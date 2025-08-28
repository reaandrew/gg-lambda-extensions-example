.PHONY: build deploy clean terraform-init terraform-apply terraform-destroy test permissions

# Install dependencies and build packages
build:
	@echo "Building extension layer..."
	rm -rf layer-build
	mkdir -p layer-build/runtime-api-proxy-extension
	mkdir -p layer-build/extensions
	# Copy extension code
	cp -r extension/* layer-build/runtime-api-proxy-extension/
	# Install dependencies
	cd layer-build/runtime-api-proxy-extension && npm install --production
	# Make index.mjs executable
	chmod +x layer-build/runtime-api-proxy-extension/index.mjs
	# Copy wrapper script to layer root
	cp wrapper-script.sh layer-build/wrapper-script.sh
	chmod +x layer-build/wrapper-script.sh
	# Copy extension launcher
	cp extension-launcher.sh layer-build/extensions/runtime-api-proxy-extension
	chmod +x layer-build/extensions/runtime-api-proxy-extension
	@echo "Build complete"

# Deploy infrastructure
deploy: terraform-init terraform-apply

# Initialize Terraform
terraform-init:
	cd terraform && terraform init

# Apply Terraform configuration (builds first)
terraform-apply: build
	cd terraform && terraform apply -auto-approve

# Destroy all AWS resources
terraform-destroy:
	cd terraform && terraform destroy -auto-approve

# Test deployed Lambda functions
test:
	@echo "Testing Lambda without extension:"
	@curl -s $$(cd terraform && terraform output -raw without_extension_url) | jq .
	@echo ""
	@echo "Testing Lambda with extension:"
	@curl -s $$(cd terraform && terraform output -raw with_extension_url) | jq .

# Set executable permissions
permissions:
	chmod +x wrapper-script.sh

# Clean build artifacts
clean:
	rm -f terraform/*.zip
	rm -rf extension/node_modules