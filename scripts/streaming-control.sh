#!/bin/bash
set -euo pipefail

# Control MediaLive channel to save costs
# Usage: ./streaming-control.sh start|stop [environment]

ACTION="${1:-}"
ENV="${2:-dev}"
REGION="${AWS_REGION:-eu-west-2}"
PROJECT_NAME="${PROJECT_NAME:-streaming-logs}"

if [[ "$ACTION" != "start" && "$ACTION" != "stop" ]]; then
    echo "Usage: $0 start|stop [environment]"
    exit 1
fi

CHANNEL_NAME="${PROJECT_NAME}-${ENV}-channel"

# Find channel ID
CHANNEL_ID=$(aws medialive list-channels \
    --region "$REGION" \
    --query "Channels[?Name=='$CHANNEL_NAME'].Id" \
    --output text)

if [[ -z "$CHANNEL_ID" ]]; then
    echo "Channel $CHANNEL_NAME not found"
    exit 1
fi

if [[ "$ACTION" == "start" ]]; then
    echo "Starting MediaLive channel: $CHANNEL_NAME"
    aws medialive start-channel --channel-id "$CHANNEL_ID" --region "$REGION"
    echo "Channel started. Costs ~$10/day while running."
elif [[ "$ACTION" == "stop" ]]; then
    echo "Stopping MediaLive channel: $CHANNEL_NAME"
    aws medialive stop-channel --channel-id "$CHANNEL_ID" --region "$REGION"
    echo "Channel stopped. No streaming costs."
fi