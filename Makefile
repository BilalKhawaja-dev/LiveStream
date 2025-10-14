# Makefile for Terraform Streaming Platform Infrastructure

.PHONY: help init plan apply destroy validate format clean test

# Default environment
ENV ?= dev

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Streaming Platform Infrastructure$(NC)"
	@echo "$(YELLOW)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	terraform init

plan: ## Generate and show an execution plan
	@echo "$(BLUE)Planning deployment for $(ENV) environment...$(NC)"
	@if [ ! -f "environments/$(ENV)/terraform.tfvars" ]; then \
		echo "$(RED)Error: environments/$(ENV)/terraform.tfvars not found$(NC)"; \
		exit 1; \
	fi
	terraform plan -var-file="environments/$(ENV)/terraform.tfvars"

apply: ## Build or change infrastructure
	@echo "$(BLUE)Applying changes for $(ENV) environment...$(NC)"
	@if [ ! -f "environments/$(ENV)/terraform.tfvars" ]; then \
		echo "$(RED)Error: environments/$(ENV)/terraform.tfvars not found$(NC)"; \
		exit 1; \
	fi
	terraform apply -var-file="environments/$(ENV)/terraform.tfvars"

destroy: ## Destroy Terraform-managed infrastructure
	@echo "$(RED)Destroying infrastructure for $(ENV) environment...$(NC)"
	@read -p "Are you sure you want to destroy the $(ENV) environment? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		terraform destroy -var-file="environments/$(ENV)/terraform.tfvars"; \
	else \
		echo "$(YELLOW)Destroy cancelled$(NC)"; \
	fi

validate: ## Validate the Terraform files
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	terraform validate
	@echo "$(GREEN)✓ Configuration is valid$(NC)"

format: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive
	@echo "$(GREEN)✓ Files formatted$(NC)"

clean: ## Clean up temporary files
	@echo "$(BLUE)Cleaning up temporary files...$(NC)"
	rm -rf .terraform/
	rm -f terraform.tfstate.backup
	rm -f .terraform.lock.hcl
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

test: ## Run validation and tests
	@echo "$(BLUE)Running tests...$(NC)"
	@if [ -f "scripts/validate-terraform.sh" ]; then \
		chmod +x scripts/validate-terraform.sh; \
		./scripts/validate-terraform.sh; \
	fi
	@if [ -f "tests/integration_test.sh" ]; then \
		chmod +x tests/integration_test.sh; \
		./tests/integration_test.sh; \
	fi
	@echo "$(GREEN)✓ Tests completed$(NC)"

frontend-install: ## Install frontend dependencies
	@echo "$(BLUE)Installing frontend dependencies...$(NC)"
	@cd streaming-platform-frontend && \
	chmod +x install-dependencies.sh && \
	./install-dependencies.sh
	@echo "$(GREEN)✓ Frontend dependencies installed$(NC)"

frontend-dev: ## Start frontend development servers
	@echo "$(BLUE)Starting frontend development servers...$(NC)"
	@cd streaming-platform-frontend && npm run dev

frontend-build: ## Build frontend applications
	@echo "$(BLUE)Building frontend applications...$(NC)"
	@cd streaming-platform-frontend && npm run build

frontend-test: ## Run frontend tests
	@echo "$(BLUE)Running frontend tests...$(NC)"
	@cd streaming-platform-frontend && npm run test

# Environment-specific shortcuts
dev: ENV=dev
dev: plan ## Plan for development environment

staging: ENV=staging  
staging: plan ## Plan for staging environment

prod: ENV=prod
prod: plan ## Plan for production environment

# Quick deployment shortcuts
deploy-dev: ENV=dev
deploy-dev: apply ## Deploy to development environment

deploy-staging: ENV=staging
deploy-staging: apply ## Deploy to staging environment

deploy-prod: ENV=prod
deploy-prod: apply ## Deploy to production environment

# Complete setup
setup: init validate format ## Complete setup (init, validate, format)
	@echo "$(GREEN)✓ Setup complete! Run 'make plan ENV=dev' to see deployment plan$(NC)"

# Docker and ECS commands
docker-build: ## Build Docker images for all applications
	@echo "$(BLUE)Building Docker images...$(NC)"
	@chmod +x scripts/build-and-push.sh
	@./scripts/build-and-push.sh $(ENV) all latest

docker-build-app: ## Build Docker image for specific app (usage: make docker-build-app APP=viewer-portal)
	@echo "$(BLUE)Building Docker image for $(APP)...$(NC)"
	@chmod +x scripts/build-and-push.sh
	@./scripts/build-and-push.sh $(ENV) $(APP) latest

docker-push: ## Build and push Docker images to ECR
	@echo "$(BLUE)Building and pushing Docker images to ECR...$(NC)"
	@chmod +x scripts/build-and-push.sh
	@./scripts/build-and-push.sh $(ENV) all latest

docker-push-app: ## Build and push specific app to ECR (usage: make docker-push-app APP=viewer-portal)
	@echo "$(BLUE)Building and pushing $(APP) to ECR...$(NC)"
	@chmod +x scripts/build-and-push.sh
	@./scripts/build-and-push.sh $(ENV) $(APP) latest

# ECS deployment
deploy-ecs: ## Deploy ECS infrastructure and applications
	@echo "$(BLUE)Deploying ECS infrastructure...$(NC)"
	@terraform apply -var-file="environments/$(ENV)/terraform.tfvars" -var="enable_ecs=true" -auto-approve
	@echo "$(GREEN)✓ ECS deployment complete$(NC)"

ecs-status: ## Show ECS cluster status
	@echo "$(BLUE)ECS Cluster Status:$(NC)"
	@aws ecs describe-clusters --clusters streaming-logs-$(ENV) --region eu-west-2 2>/dev/null || echo "$(YELLOW)ECS cluster not found$(NC)"

ecs-services: ## List ECS services
	@echo "$(BLUE)ECS Services:$(NC)"
	@aws ecs list-services --cluster streaming-logs-$(ENV) --region eu-west-2 2>/dev/null || echo "$(YELLOW)ECS cluster not found$(NC)"

# Streaming control
streaming-start: ## Start MediaLive channel for streaming
	@echo "$(BLUE)Starting MediaLive channel...$(NC)"
	@chmod +x scripts/streaming-control.sh
	@./scripts/streaming-control.sh start $(ENV)
	@echo "$(YELLOW)Channel started - costs ~$10/day while running$(NC)"

streaming-stop: ## Stop MediaLive channel to save costs
	@echo "$(BLUE)Stopping MediaLive channel...$(NC)"
	@chmod +x scripts/streaming-control.sh
	@./scripts/streaming-control.sh stop $(ENV)
	@echo "$(GREEN)Channel stopped - no streaming costs$(NC)"

streaming-status: ## Check MediaLive channel status
	@echo "$(BLUE)MediaLive Channel Status:$(NC)"
	@aws medialive list-channels --region eu-west-2 --query "Channels[?Name=='streaming-logs-$(ENV)-channel'].[Name,State]" --output table 2>/dev/null || echo "$(YELLOW)No channels found$(NC)"

# Complete deployment workflow
deploy-full: ## Complete deployment (infrastructure + containers)
	@echo "$(BLUE)Starting full deployment...$(NC)"
	@make apply ENV=$(ENV)
	@make docker-push ENV=$(ENV)
	@make deploy-ecs ENV=$(ENV)
	@echo "$(GREEN)✓ Full deployment complete$(NC)"

# Show current status
status: ## Show Terraform status
	@echo "$(BLUE)Terraform Status:$(NC)"
	@terraform version
	@echo ""
	@if [ -f ".terraform/terraform.tfstate" ]; then \
		echo "$(GREEN)✓ Terraform initialized$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Terraform not initialized - run 'make init'$(NC)"; \
	fi
	@echo ""
	@echo "$(BLUE)Available environments:$(NC)"
	@ls -1 environments/ 2>/dev/null || echo "$(RED)No environment configurations found$(NC)"
	@echo ""
	@echo "$(BLUE)Docker Status:$(NC)"
	@docker --version 2>/dev/null || echo "$(RED)Docker not installed$(NC)"
	@echo ""
	@echo "$(BLUE)AWS CLI Status:$(NC)"
	@aws --version 2>/dev/null || echo "$(RED)AWS CLI not installed$(NC)"