# Makefile for Terraform Infrastructure Management
# Centralized Logging Infrastructure

.PHONY: help init plan apply destroy validate test clean format security lint

# Default environment
ENV ?= dev
REGION ?= eu-west-2

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Terraform Infrastructure Management$(NC)"
	@echo "$(BLUE)====================================$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Environment variables:$(NC)"
	@echo "  $(YELLOW)ENV$(NC)     Environment (dev, staging, prod) [default: dev]"
	@echo "  $(YELLOW)REGION$(NC)  AWS region [default: eu-west-2]"
	@echo ""
	@echo "$(GREEN)Examples:$(NC)"
	@echo "  make plan ENV=staging"
	@echo "  make apply ENV=prod"
	@echo "  make test"

init: ## Initialize Terraform
	@echo "$(BLUE)[INFO]$(NC) Initializing Terraform for $(ENV) environment..."
	@cp environments/$(ENV)/terraform.tfvars terraform.tfvars
	@terraform init
	@terraform workspace select $(ENV) || terraform workspace new $(ENV)
	@echo "$(GREEN)[SUCCESS]$(NC) Terraform initialized for $(ENV) environment"

validate: ## Validate Terraform configuration
	@echo "$(BLUE)[INFO]$(NC) Validating Terraform configuration..."
	@terraform validate
	@echo "$(GREEN)[SUCCESS]$(NC) Terraform configuration is valid"

format: ## Format Terraform code
	@echo "$(BLUE)[INFO]$(NC) Formatting Terraform code..."
	@terraform fmt -recursive
	@echo "$(GREEN)[SUCCESS]$(NC) Code formatted"

plan: init validate ## Generate Terraform execution plan
	@echo "$(BLUE)[INFO]$(NC) Generating Terraform plan for $(ENV) environment..."
	@terraform plan -var-file=terraform.tfvars -out=$(ENV).tfplan
	@echo "$(GREEN)[SUCCESS]$(NC) Plan generated: $(ENV).tfplan"

apply: ## Apply Terraform plan
	@echo "$(BLUE)[INFO]$(NC) Applying Terraform plan for $(ENV) environment..."
	@if [ -f "$(ENV).tfplan" ]; then \
		terraform apply $(ENV).tfplan; \
	else \
		echo "$(YELLOW)[WARNING]$(NC) No plan file found, generating new plan..."; \
		terraform plan -var-file=terraform.tfvars -out=$(ENV).tfplan; \
		terraform apply $(ENV).tfplan; \
	fi
	@echo "$(GREEN)[SUCCESS]$(NC) Infrastructure deployed for $(ENV) environment"

destroy: init ## Destroy Terraform infrastructure
	@echo "$(RED)[WARNING]$(NC) This will destroy all infrastructure for $(ENV) environment!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform destroy -var-file=terraform.tfvars; \
		echo "$(GREEN)[SUCCESS]$(NC) Infrastructure destroyed for $(ENV) environment"; \
	else \
		echo "$(YELLOW)[INFO]$(NC) Destruction cancelled"; \
	fi

test: ## Run all tests
	@echo "$(BLUE)[INFO]$(NC) Running pre-commit validation..."
	@./scripts/pre-commit-hooks.sh
	@echo "$(BLUE)[INFO]$(NC) Running integration tests..."
	@TEST_ENVIRONMENT=$(ENV) ./tests/integration_test.sh
	@echo "$(GREEN)[SUCCESS]$(NC) All tests passed"

test-modules: ## Test individual modules
	@echo "$(BLUE)[INFO]$(NC) Testing Terraform modules..."
	@for module in modules/*/; do \
		echo "Testing module: $$module"; \
		cd "$$module" && terraform init -backend=false && terraform validate && cd ../..; \
	done
	@echo "$(GREEN)[SUCCESS]$(NC) All modules validated"

security: ## Run security scanning
	@echo "$(BLUE)[INFO]$(NC) Running security scans..."
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec . --format table; \
	else \
		echo "$(YELLOW)[WARNING]$(NC) tfsec not installed, skipping security scan"; \
	fi
	@echo "$(GREEN)[SUCCESS]$(NC) Security scan completed"

lint: ## Run linting checks
	@echo "$(BLUE)[INFO]$(NC) Running linting checks..."
	@terraform fmt -check -recursive
	@if command -v tflint >/dev/null 2>&1; then \
		tflint --init && tflint; \
	else \
		echo "$(YELLOW)[WARNING]$(NC) tflint not installed, skipping lint checks"; \
	fi
	@echo "$(GREEN)[SUCCESS]$(NC) Linting completed"

clean: ## Clean up temporary files
	@echo "$(BLUE)[INFO]$(NC) Cleaning up temporary files..."
	@rm -f *.tfplan
	@rm -f terraform.tfvars
	@rm -f .terraform.lock.hcl
	@rm -rf .terraform/
	@echo "$(GREEN)[SUCCESS]$(NC) Cleanup completed"

outputs: ## Show Terraform outputs
	@echo "$(BLUE)[INFO]$(NC) Terraform outputs for $(ENV) environment:"
	@terraform output

state-list: ## List Terraform state resources
	@echo "$(BLUE)[INFO]$(NC) Terraform state resources for $(ENV) environment:"
	@terraform state list

workspace-list: ## List Terraform workspaces
	@echo "$(BLUE)[INFO]$(NC) Available Terraform workspaces:"
	@terraform workspace list

cost-estimate: ## Estimate infrastructure costs (requires infracost)
	@echo "$(BLUE)[INFO]$(NC) Estimating infrastructure costs..."
	@if command -v infracost >/dev/null 2>&1; then \
		infracost breakdown --path . --format table; \
	else \
		echo "$(YELLOW)[WARNING]$(NC) infracost not installed, skipping cost estimation"; \
		echo "Install from: https://www.infracost.io/docs/"; \
	fi

docs: ## Generate documentation
	@echo "$(BLUE)[INFO]$(NC) Generating Terraform documentation..."
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown table --output-file README.md .; \
		for module in modules/*/; do \
			terraform-docs markdown table --output-file README.md "$$module"; \
		done; \
	else \
		echo "$(YELLOW)[WARNING]$(NC) terraform-docs not installed, skipping documentation generation"; \
		echo "Install from: https://terraform-docs.io/user-guide/installation/"; \
	fi
	@echo "$(GREEN)[SUCCESS]$(NC) Documentation generated"

backup: ## Create infrastructure backup
	@echo "$(BLUE)[INFO]$(NC) Creating infrastructure backup..."
	@./scripts/rollback.sh --create-backup --environment $(ENV)
	@echo "$(GREEN)[SUCCESS]$(NC) Backup created for $(ENV) environment"

rollback: ## Rollback to previous state
	@echo "$(BLUE)[INFO]$(NC) Available backups for $(ENV) environment:"
	@./scripts/rollback.sh --list --environment $(ENV)
	@read -p "Enter backup ID to rollback to: " backup_id; \
	./scripts/rollback.sh --environment $(ENV) --backup-id "$$backup_id"

setup-hooks: ## Setup git pre-commit hooks
	@echo "$(BLUE)[INFO]$(NC) Setting up git pre-commit hooks..."
	@chmod +x scripts/pre-commit-hooks.sh
	@ln -sf ../../scripts/pre-commit-hooks.sh .git/hooks/pre-commit
	@echo "$(GREEN)[SUCCESS]$(NC) Pre-commit hooks configured"

check-tools: ## Check required tools installation
	@echo "$(BLUE)[INFO]$(NC) Checking required tools..."
	@echo -n "Terraform: "; \
	if command -v terraform >/dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell terraform version | head -n1)$(NC)"; \
	else \
		echo "$(RED)✗ Not installed$(NC)"; \
	fi
	@echo -n "AWS CLI: "; \
	if command -v aws >/dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell aws --version)$(NC)"; \
	else \
		echo "$(RED)✗ Not installed$(NC)"; \
	fi
	@echo -n "Git: "; \
	if command -v git >/dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell git --version)$(NC)"; \
	else \
		echo "$(RED)✗ Not installed$(NC)"; \
	fi
	@echo -n "tfsec: "; \
	if command -v tfsec >/dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell tfsec --version)$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Not installed (optional)$(NC)"; \
	fi
	@echo -n "tflint: "; \
	if command -v tflint >/dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell tflint --version)$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Not installed (optional)$(NC)"; \
	fi

install-tools: ## Install optional tools (Linux/macOS)
	@echo "$(BLUE)[INFO]$(NC) Installing optional tools..."
	@echo "Installing tfsec..."
	@curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
	@echo "Installing tflint..."
	@curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
	@echo "$(GREEN)[SUCCESS]$(NC) Optional tools installed"

ci-validate: format validate lint security test-modules ## Run CI validation pipeline
	@echo "$(GREEN)[SUCCESS]$(NC) CI validation pipeline completed"

ci-plan: init plan ## Run CI plan pipeline
	@echo "$(GREEN)[SUCCESS]$(NC) CI plan pipeline completed"

ci-deploy: apply ## Run CI deployment pipeline
	@echo "$(GREEN)[SUCCESS]$(NC) CI deployment pipeline completed"

# Environment-specific shortcuts
dev: ## Quick deployment to dev environment
	@$(MAKE) apply ENV=dev

staging: ## Quick deployment to staging environment
	@$(MAKE) apply ENV=staging

prod: ## Quick deployment to prod environment (with confirmation)
	@echo "$(RED)[WARNING]$(NC) Deploying to PRODUCTION environment!"
	@read -p "Are you sure? Type 'DEPLOY' to continue: " confirm; \
	if [ "$$confirm" = "DEPLOY" ]; then \
		$(MAKE) apply ENV=prod; \
	else \
		echo "$(YELLOW)[INFO]$(NC) Production deployment cancelled"; \
	fi

# Default target
.DEFAULT_GOAL := help