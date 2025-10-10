#!/bin/bash

# Test script for S3 Storage Module validation
# This script validates Terraform configuration without creating actual resources

set -e

echo "Starting S3 Storage Module validation tests..."

# Change to the test directory
cd "$(dirname "$0")"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init -backend=false

# Validate Terraform configuration
echo "Validating Terraform configuration..."
terraform validate

# Format check
echo "Checking Terraform formatting..."
terraform fmt -check=true -diff=true

# Plan validation (dry run)
echo "Running Terraform plan validation..."
terraform plan -out=test.tfplan

# Validate plan output
echo "Validating plan output..."
if terraform show -json test.tfplan | jq -e '.planned_values.root_module.child_modules[] | select(.address == "module.storage_test_default")' > /dev/null; then
    echo "✓ Default module configuration validated successfully"
else
    echo "✗ Default module configuration validation failed"
    exit 1
fi

if terraform show -json test.tfplan | jq -e '.planned_values.root_module.child_modules[] | select(.address == "module.storage_test_custom")' > /dev/null; then
    echo "✓ Custom module configuration validated successfully"
else
    echo "✗ Custom module configuration validation failed"
    exit 1
fi

# Validate bucket naming conventions
echo "Validating bucket naming conventions..."
terraform show -json test.tfplan | jq -r '.planned_values.root_module.child_modules[].resources[] | select(.type == "aws_s3_bucket") | .values.bucket' | while read bucket_name; do
    if [[ $bucket_name =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]] && [[ ${#bucket_name} -ge 3 ]] && [[ ${#bucket_name} -le 63 ]]; then
        echo "✓ Bucket name '$bucket_name' follows AWS naming conventions"
    else
        echo "✗ Bucket name '$bucket_name' violates AWS naming conventions"
        exit 1
    fi
done

# Validate encryption configuration
echo "Validating encryption configuration..."
encryption_count=$(terraform show -json test.tfplan | jq '[.planned_values.root_module.child_modules[].resources[] | select(.type == "aws_s3_bucket_server_side_encryption_configuration")] | length')
bucket_count=$(terraform show -json test.tfplan | jq '[.planned_values.root_module.child_modules[].resources[] | select(.type == "aws_s3_bucket")] | length')

if [ "$encryption_count" -eq "$bucket_count" ]; then
    echo "✓ All buckets have encryption configuration"
else
    echo "✗ Not all buckets have encryption configuration (Expected: $bucket_count, Found: $encryption_count)"
    exit 1
fi

# Validate versioning configuration
echo "Validating versioning configuration..."
versioning_count=$(terraform show -json test.tfplan | jq '[.planned_values.root_module.child_modules[].resources[] | select(.type == "aws_s3_bucket_versioning")] | length')

if [ "$versioning_count" -eq "$bucket_count" ]; then
    echo "✓ All buckets have versioning configuration"
else
    echo "✗ Not all buckets have versioning configuration (Expected: $bucket_count, Found: $versioning_count)"
    exit 1
fi

# Validate lifecycle configuration
echo "Validating lifecycle configuration..."
lifecycle_count=$(terraform show -json test.tfplan | jq '[.planned_values.root_module.child_modules[].resources[] | select(.type == "aws_s3_bucket_lifecycle_configuration")] | length')

if [ "$lifecycle_count" -eq "$bucket_count" ]; then
    echo "✓ All buckets have lifecycle configuration"
else
    echo "✗ Not all buckets have lifecycle configuration (Expected: $bucket_count, Found: $lifecycle_count)"
    exit 1
fi

# Validate public access blocking
echo "Validating public access blocking..."
public_access_block_count=$(terraform show -json test.tfplan | jq '[.planned_values.root_module.child_modules[].resources[] | select(.type == "aws_s3_bucket_public_access_block")] | length')

if [ "$public_access_block_count" -eq "$bucket_count" ]; then
    echo "✓ All buckets have public access blocking enabled"
else
    echo "✗ Not all buckets have public access blocking (Expected: $bucket_count, Found: $public_access_block_count)"
    exit 1
fi

# Clean up
echo "Cleaning up test files..."
rm -f test.tfplan
rm -rf .terraform/

echo "All S3 Storage Module validation tests passed successfully! ✓"