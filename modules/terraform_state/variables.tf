# Terraform State Management Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "streaming-logs"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# State storage configuration
variable "state_version_retention_days" {
  description = "Number of days to retain old state versions"
  type        = number
  default     = 30
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB lock table"
  type        = bool
  default     = true
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

# Access control
variable "terraform_users_arns" {
  description = "List of IAM user/role ARNs that need Terraform state access"
  type        = list(string)
  default     = []
}

variable "create_cicd_role" {
  description = "Create IAM role for CI/CD pipeline"
  type        = bool
  default     = true
}

variable "cicd_role_trusted_arns" {
  description = "List of ARNs trusted to assume the CI/CD role"
  type        = list(string)
  default     = []
}

variable "require_external_id" {
  description = "Require external ID for CI/CD role assumption"
  type        = bool
  default     = false
}

variable "external_id" {
  description = "External ID for CI/CD role assumption"
  type        = string
  default     = ""
  sensitive   = true
}

# Backup configuration
variable "enable_state_backup" {
  description = "Enable state backup with S3 replication"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain state backups"
  type        = number
  default     = 90
}

# Monitoring configuration
variable "enable_state_monitoring" {
  description = "Enable CloudWatch monitoring for state operations"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

# Workspace configuration
variable "workspace_key_prefix" {
  description = "Prefix for workspace-specific state keys"
  type        = string
  default     = "workspaces"
}

variable "default_workspace_key" {
  description = "State key for default workspace"
  type        = string
  default     = "terraform.tfstate"
}

# Security settings
variable "enable_mfa_delete" {
  description = "Enable MFA delete for state bucket (production only)"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access state resources"
  type        = list(string)
  default     = []
}

# Tagging
variable "additional_tags" {
  description = "Additional tags to apply to state management resources"
  type        = map(string)
  default     = {}
}