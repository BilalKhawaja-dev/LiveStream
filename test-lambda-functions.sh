#!/bin/bash

# Test Lambda Functions Implementation
echo "🧪 Testing Lambda Functions Implementation"
echo "=========================================="

# Set API endpoint
API_BASE="https://ep00whgcd5.execute-api.eu-west-2.amazonaws.com/dev"

# Test 1: Auth Handler - User Registration
echo "\n📝 Test 1: User Registration"
curl -X POST "$API_BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser_$(date +%s)",
    "email": "test_$(date +%s)@example.com",
    "password": "TestPassword123!",
    "display_name": "Test User",
    "role": "creator"
  }' | jq .

# Test 2: Auth Handler - Get Users (Admin)
echo "\n👥 Test 2: Get Users List"
curl -X GET "$API_BASE/users" \
  -H "Authorization: Bearer test-token" | jq .

# Test 3: Streaming Handler - List Streams
echo "\n📺 Test 3: List Active Streams"
curl -X GET "$API_BASE/streams" \
  -H "Authorization: Bearer test-token" | jq .

# Test 4: Support Handler - Create Ticket
echo "\n🎫 Test 4: Create Support Ticket"
curl -X POST "$API_BASE/support/tickets" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-token" \
  -d '{
    "user_id": "test-user-123",
    "subject": "Test streaming issue",
    "description": "I am having trouble starting my stream. The video quality is poor and there are connection issues.",
    "priority": "medium",
    "source_context": {
      "application": "creator-dashboard",
      "current_page": "/streaming",
      "user_agent": "test-browser"
    }
  }' | jq .

# Test 5: Analytics Handler - Get Metrics
echo "\n📊 Test 5: Get Analytics Metrics"
curl -X GET "$API_BASE/analytics/users" \
  -H "Authorization: Bearer test-token" | jq .

# Test 6: Analytics Handler - Dashboard Data
echo "\n📈 Test 6: Get Dashboard Data"
curl -X GET "$API_BASE/analytics/streams" \
  -H "Authorization: Bearer test-token" | jq .

echo "\n✅ Lambda Function Tests Completed"
echo "Check the responses above for any errors or issues."