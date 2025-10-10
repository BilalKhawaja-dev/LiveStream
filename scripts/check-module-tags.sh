#!/bin/bash

# Script to check which modules support tags variables
# This helps ensure we only pass tags to modules that accept them

echo "Checking which modules support tags variables..."
echo "================================================"

for module_dir in terraform_live_stream/modules/*/; do
    if [ -d "$module_dir" ]; then
        module_name=$(basename "$module_dir")
        if grep -q "variable.*\"tags\"" "$module_dir/variables.tf" 2>/dev/null; then
            echo "✓ $module_name - supports 'tags' parameter"
        elif grep -q "variable.*\"additional_tags\"" "$module_dir/variables.tf" 2>/dev/null; then
            echo "✓ $module_name - supports 'additional_tags' parameter"
        else
            echo "✗ $module_name - does NOT support tags"
        fi
    fi
done

echo ""
echo "Summary: Only pass tags parameter to modules that support it!"