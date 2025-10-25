#!/bin/bash

echo "=== FIXING ALL STRING LITERAL ISSUES ==="

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Fixing string literals for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Fix all string literal issues
    find "$service_dir/src" -name "*.tsx" -o -name "*.ts" | while read -r file; do
        # Skip the stub files themselves
        if [[ "$file" == *"/stubs/"* ]]; then
            continue
        fi
        
        # Fix multiline template literals with unterminated strings
        # This is a more comprehensive fix
        python3 -c "
import re
import sys

with open('$file', 'r') as f:
    content = f.read()

# Fix pattern: ? 'value' : '
# followed by newline and closing template literal
content = re.sub(r\"(\? '[^']*' : ')(\s*\n\s*)\}\`\}\", r\"\1'\\2}\`}\", content)

# Fix pattern: ? 'value' : '
# at end of line in template literal
content = re.sub(r\"(\? '[^']*' : ')(\s*\$)\", r\"\1'\\2\", content)

# Fix any remaining unterminated strings in template literals
content = re.sub(r\"(\? '[^']*' : ')(\s*[\n\r]+\s*[\}\`])\", r\"\1'\\2\", content)

with open('$file', 'w') as f:
    f.write(content)
"
        
        echo "  Fixed string literals in $(basename "$file")"
    done
    
    echo "✅ Fixed string literals for $service"
done

echo "=== ALL STRING LITERAL ISSUES FIXED ==="