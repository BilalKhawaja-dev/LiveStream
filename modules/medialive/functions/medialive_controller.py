import json
import boto3
import os
import logging
from datetime import datetime, timedelta
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
medialive_client = boto3.client('medialive')
sns_client = boto3.client('sns')
cloudwatch_client = boto3.client('cloudwatch')

def lambda_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    MediaLive cost control Lambda function
    Handles channel start/stop operations and cost monitoring
    """
    
    try:
        # Parse the request
        action = event.get('action', 'status')
        channel_id = os.environ['CHANNEL_ID']
        
        logger.info(f"Processing MediaLive action: {action} for channel: {channel_id}")
        
        if action == 'start':
            return start_channel(channel_id)
        elif action == 'stop':
            return stop_channel(channel_id)
        elif action == 'status':
            return get_channel_status(channel_id)
        elif action == 'check_runtime':
            return check_runtime_and_alert(channel_id)
        else:
            return create_response(400, {'error': f'Unknown action: {action}'})
            
    except Exception as e:
        logger.error(f"Error in MediaLive controller: {str(e)}")
        return create_response(500, {
            'error': 'MediaLive controller failed',
            'message': str(e)
        })

def start_channel(channel_id: str) -> Dict[str, Any]:
    """Start MediaLive channel with cost monitoring"""
    try:
        # Check current channel state
        response = medialive_client.describe_channel(ChannelId=channel_id)
        current_state = response['State']
        
        if current_state == 'RUNNING':
            return create_response(200, {
                'message': 'Channel is already running',
                'channel_id': channel_id,
                'state': current_state
            })
        
        if current_state not in ['IDLE', 'STOPPED']:
            return create_response(400, {
                'error': 'Channel cannot be started',
                'current_state': current_state,
                'message': 'Channel must be in IDLE or STOPPED state to start'
            })
        
        # Start the channel
        medialive_client.start_channel(ChannelId=channel_id)
        
        # Send notification
        send_notification(
            f"MediaLive channel {channel_id} has been started",
            f"Channel started at {datetime.now().isoformat()}. "
            f"Maximum runtime: {os.environ['MAX_RUNTIME_HOURS']} hours. "
            f"Estimated cost: ${calculate_estimated_cost()} per hour."
        )
        
        # Create custom metric for runtime tracking
        put_custom_metric(channel_id, 'ChannelStarted', 1)
        
        logger.info(f"Successfully started MediaLive channel: {channel_id}")
        
        return create_response(200, {
            'message': 'Channel start initiated',
            'channel_id': channel_id,
            'estimated_cost_per_hour': calculate_estimated_cost(),
            'max_runtime_hours': int(os.environ['MAX_RUNTIME_HOURS']),
            'auto_shutdown_enabled': True
        })
        
    except Exception as e:
        logger.error(f"Error starting channel {channel_id}: {str(e)}")
        return create_response(500, {
            'error': 'Failed to start channel',
            'message': str(e)
        })

def stop_channel(channel_id: str) -> Dict[str, Any]:
    """Stop MediaLive channel"""
    try:
        # Check current channel state
        response = medialive_client.describe_channel(ChannelId=channel_id)
        current_state = response['State']
        
        if current_state in ['IDLE', 'STOPPED']:
            return create_response(200, {
                'message': 'Channel is already stopped',
                'channel_id': channel_id,
                'state': current_state
            })
        
        if current_state != 'RUNNING':
            return create_response(400, {
                'error': 'Channel cannot be stopped',
                'current_state': current_state,
                'message': 'Channel must be in RUNNING state to stop'
            })
        
        # Stop the channel
        medialive_client.stop_channel(ChannelId=channel_id)
        
        # Calculate runtime and cost
        runtime_info = calculate_runtime_cost(channel_id)
        
        # Send notification
        send_notification(
            f"MediaLive channel {channel_id} has been stopped",
            f"Channel stopped at {datetime.now().isoformat()}. "
            f"Runtime: {runtime_info['runtime_hours']:.2f} hours. "
            f"Estimated cost: ${runtime_info['estimated_cost']:.2f}"
        )
        
        # Create custom metric for runtime tracking
        put_custom_metric(channel_id, 'ChannelStopped', 1)
        put_custom_metric(channel_id, 'ChannelRunningTime', 0)  # Reset runtime
        
        logger.info(f"Successfully stopped MediaLive channel: {channel_id}")
        
        return create_response(200, {
            'message': 'Channel stop initiated',
            'channel_id': channel_id,
            'runtime_info': runtime_info
        })
        
    except Exception as e:
        logger.error(f"Error stopping channel {channel_id}: {str(e)}")
        return create_response(500, {
            'error': 'Failed to stop channel',
            'message': str(e)
        })

def get_channel_status(channel_id: str) -> Dict[str, Any]:
    """Get current channel status and runtime information"""
    try:
        # Get channel details
        response = medialive_client.describe_channel(ChannelId=channel_id)
        
        channel_info = {
            'channel_id': channel_id,
            'name': response['Name'],
            'state': response['State'],
            'channel_class': response['ChannelClass'],
            'input_specification': response['InputSpecification'],
            'destinations': response['Destinations']
        }
        
        # If channel is running, get runtime information
        if response['State'] == 'RUNNING':
            runtime_info = calculate_runtime_cost(channel_id)
            channel_info['runtime_info'] = runtime_info
            
            # Check if approaching max runtime
            max_hours = int(os.environ['MAX_RUNTIME_HOURS'])
            if runtime_info['runtime_hours'] >= max_hours * 0.8:  # 80% of max runtime
                channel_info['warning'] = f"Approaching maximum runtime of {max_hours} hours"
        
        return create_response(200, channel_info)
        
    except Exception as e:
        logger.error(f"Error getting channel status {channel_id}: {str(e)}")
        return create_response(500, {
            'error': 'Failed to get channel status',
            'message': str(e)
        })

def check_runtime_and_alert(channel_id: str) -> Dict[str, Any]:
    """Check channel runtime and send alerts or auto-shutdown"""
    try:
        # Get channel state
        response = medialive_client.describe_channel(ChannelId=channel_id)
        
        if response['State'] != 'RUNNING':
            return create_response(200, {
                'message': 'Channel is not running',
                'state': response['State']
            })
        
        # Calculate runtime
        runtime_info = calculate_runtime_cost(channel_id)
        max_hours = int(os.environ['MAX_RUNTIME_HOURS'])
        
        # Update custom metric
        put_custom_metric(channel_id, 'ChannelRunningTime', runtime_info['runtime_hours'])
        
        # Check if max runtime exceeded
        if runtime_info['runtime_hours'] >= max_hours:
            # Auto-shutdown
            medialive_client.stop_channel(ChannelId=channel_id)
            
            send_notification(
                f"MediaLive channel {channel_id} auto-shutdown",
                f"Channel automatically stopped after {runtime_info['runtime_hours']:.2f} hours "
                f"(max: {max_hours} hours). Estimated cost: ${runtime_info['estimated_cost']:.2f}"
            )
            
            logger.warning(f"Auto-shutdown channel {channel_id} after {runtime_info['runtime_hours']:.2f} hours")
            
            return create_response(200, {
                'message': 'Channel auto-shutdown due to max runtime exceeded',
                'runtime_info': runtime_info,
                'max_runtime_hours': max_hours
            })
        
        # Check if approaching cost threshold
        cost_threshold = float(os.environ['COST_ALERT_THRESHOLD'])
        if runtime_info['estimated_cost'] >= cost_threshold * 0.8:  # 80% of threshold
            send_notification(
                f"MediaLive cost alert for channel {channel_id}",
                f"Current estimated cost: ${runtime_info['estimated_cost']:.2f} "
                f"(threshold: ${cost_threshold}). Runtime: {runtime_info['runtime_hours']:.2f} hours."
            )
        
        return create_response(200, {
            'message': 'Runtime check completed',
            'runtime_info': runtime_info,
            'max_runtime_hours': max_hours,
            'cost_threshold': cost_threshold
        })
        
    except Exception as e:
        logger.error(f"Error checking runtime for channel {channel_id}: {str(e)}")
        return create_response(500, {
            'error': 'Failed to check runtime',
            'message': str(e)
        })

def calculate_runtime_cost(channel_id: str) -> Dict[str, Any]:
    """Calculate channel runtime and estimated cost"""
    try:
        # Get CloudWatch metrics for channel state changes
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=1)  # Look back 24 hours
        
        # This is a simplified calculation - in production you'd track actual start time
        # For now, estimate based on when the function was last called
        estimated_runtime_hours = 1.0  # Placeholder - implement proper tracking
        
        # MediaLive pricing (approximate, varies by region and configuration)
        cost_per_hour = calculate_estimated_cost()
        estimated_cost = estimated_runtime_hours * cost_per_hour
        
        return {
            'runtime_hours': estimated_runtime_hours,
            'cost_per_hour': cost_per_hour,
            'estimated_cost': estimated_cost,
            'last_checked': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error calculating runtime cost: {str(e)}")
        return {
            'runtime_hours': 0,
            'cost_per_hour': 0,
            'estimated_cost': 0,
            'error': str(e)
        }

def calculate_estimated_cost() -> float:
    """Calculate estimated cost per hour based on channel configuration"""
    # MediaLive pricing (approximate USD per hour)
    # These are example prices - check current AWS pricing
    pricing = {
        'STANDARD': {
            'SD': 1.50,
            'HD': 3.00,
            'UHD': 12.00
        },
        'SINGLE_PIPELINE': {
            'SD': 0.75,
            'HD': 1.50,
            'UHD': 6.00
        }
    }
    
    # Default to HD STANDARD for estimation
    return pricing['STANDARD']['HD']

def put_custom_metric(channel_id: str, metric_name: str, value: float):
    """Put custom CloudWatch metric"""
    try:
        cloudwatch_client.put_metric_data(
            Namespace='Custom/MediaLive',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Dimensions': [
                        {
                            'Name': 'ChannelId',
                            'Value': channel_id
                        }
                    ],
                    'Value': value,
                    'Unit': 'Count' if metric_name in ['ChannelStarted', 'ChannelStopped'] else 'None',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
    except Exception as e:
        logger.error(f"Error putting custom metric: {str(e)}")

def send_notification(subject: str, message: str):
    """Send SNS notification"""
    try:
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if not sns_topic_arn:
            logger.warning("SNS topic ARN not configured")
            return
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info(f"Sent notification: {subject}")
        
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create HTTP response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body)
    }