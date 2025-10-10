# S3 Storage Module Tests

This directory contains validation tests for the S3 storage module used in the centralized logging infrastructure.

## Test Files

- `validation.tf` - Terraform configuration that instantiates the storage module with different parameter sets
- `terraform.tf` - Provider configuration for testing (uses mock AWS provider)
- `test_storage_module.sh` - Shell script that runs comprehensive validation tests
- `README.md` - This documentation file

## Running Tests

### Prerequisites

- Terraform >= 1.0
- jq (for JSON parsing in shell script)
- Bash shell

### Execute Tests

```bash
# Make the test script executable (if not already)
chmod +x test_storage_module.sh

# Run the validation tests
./test_storage_module.sh
```

## Test Coverage

The validation tests cover:

1. **Configuration Validation**
   - Terraform syntax validation
   - Format checking
   - Plan generation without errors

2. **Bucket Naming Conventions**
   - AWS S3 bucket naming rules compliance
   - Length constraints (3-63 characters)
   - Character restrictions (lowercase, numbers, hyphens)

3. **Security Configuration**
   - KMS encryption enabled for all buckets
   - Public access blocking configured
   - Proper IAM permissions structure

4. **Lifecycle Policy Validation**
   - Correct transition rules (Standard → Standard-IA → Glacier)
   - Appropriate retention periods for each tier
   - Noncurrent version management
   - Incomplete multipart upload cleanup

5. **Versioning Configuration**
   - Versioning enabled for all buckets
   - Noncurrent version lifecycle rules

6. **Module Instantiation**
   - Default parameter values work correctly
   - Custom parameter values are applied properly
   - All required outputs are generated

## Test Scenarios

### Default Configuration Test
Tests the module with default parameter values:
- Hot tier: 7 days
- Warm tier: 30 days  
- Cold tier: 365 days
- Athena results retention: 30 days

### Custom Configuration Test
Tests the module with custom parameter values:
- Hot tier: 5 days
- Warm tier: 20 days
- Cold tier: 200 days
- Athena results retention: 15 days

## Expected Outputs

When tests pass successfully, you should see:
```
✓ Default module configuration validated successfully
✓ Custom module configuration validated successfully
✓ Bucket name 'example-bucket-name' follows AWS naming conventions
✓ All buckets have encryption configuration
✓ All buckets have versioning configuration
✓ All buckets have lifecycle configuration
✓ All buckets have public access blocking enabled
All S3 Storage Module validation tests passed successfully! ✓
```

## Troubleshooting

If tests fail:

1. **Terraform Validation Errors**: Check syntax in the module files
2. **Naming Convention Failures**: Ensure bucket names follow AWS rules
3. **Missing Configurations**: Verify all required resources are defined
4. **JSON Parsing Errors**: Ensure jq is installed and terraform plan generates valid JSON

## Integration with CI/CD

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions step
- name: Validate S3 Storage Module
  run: |
    cd terraform_live_stream/modules/storage/tests
    ./test_storage_module.sh
```