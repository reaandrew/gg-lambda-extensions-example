.PHONY: build deploy clean terraform-init terraform-apply terraform-destroy test

build: clean
	@echo "Building Lambda function..."
	@cd function && zip -r ../function.zip .
	@echo "Building extension layer..."
	@mkdir -p layer-build/nodejs-example-lambda-runtime-api-proxy-extension
	@mkdir -p layer-build/extensions
	@cp -r extension/* layer-build/nodejs-example-lambda-runtime-api-proxy-extension/
	@cd layer-build/nodejs-example-lambda-runtime-api-proxy-extension && npm install --production
	@chmod +x layer-build/nodejs-example-lambda-runtime-api-proxy-extension/index.mjs
	@cp wrapper-script.sh layer-build/
	@chmod +x layer-build/wrapper-script.sh
	@cp extensions/nodejs-example-lambda-runtime-api-proxy-extension layer-build/extensions/
	@chmod +x layer-build/extensions/nodejs-example-lambda-runtime-api-proxy-extension
	@cd layer-build && zip -r ../extension-layer.zip .
	@echo "Building GitGuardian example Lambda (without extension)..."
	@cd gitguardian/examples/without_extension && zip -r ../../../gitguardian-without-extension.zip .
	@echo "Building GitGuardian extension layer..."
	@rm -rf gitguardian-layer-build
	@mkdir -p gitguardian-layer-build/gitguardian-extension
	@mkdir -p gitguardian-layer-build/extensions
	@cp -r gitguardian-extension/* gitguardian-layer-build/gitguardian-extension/
	@cd gitguardian-layer-build/gitguardian-extension && npm install --production
	@chmod +x gitguardian-layer-build/gitguardian-extension/index.mjs
	@cp extensions/gitguardian-extension gitguardian-layer-build/extensions/
	@chmod +x gitguardian-layer-build/extensions/gitguardian-extension
	@cd gitguardian-layer-build && zip -r ../gitguardian-extension-layer.zip .
	@echo "Build complete!"
	@echo "Generated files:"
	@echo "  - function.zip"
	@echo "  - extension-layer.zip"
	@echo "  - gitguardian-without-extension.zip"
	@echo "  - gitguardian-extension-layer.zip"

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf layer-build gitguardian-layer-build
	@rm -f function.zip extension-layer.zip gitguardian-without-extension.zip gitguardian-extension-layer.zip

terraform-init:
	@cd terraform && terraform init

terraform-apply: build
	@cd terraform && terraform apply

terraform-destroy:
	@cd terraform && terraform destroy

deploy: terraform-init terraform-apply
	@echo "Deployment complete!"
	@echo ""
	@echo "Test your Lambda function with:"
	@cd terraform && terraform output curl_command

test:
	@echo "Testing Lambda function..."
	@cd terraform && curl $$(terraform output -raw alb_dns_name) | jq '.'

permissions:
	@chmod +x wrapper-script.sh
	@chmod +x extensions/nodejs-example-lambda-runtime-api-proxy-extension