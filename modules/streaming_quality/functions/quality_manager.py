import json
import boto3
import os
import logging
from typing import Dict, Any, List
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
rds_data_client = boto3.client('rds-data')
dynamodb_client = boto3.client('dynamodb')
cloudfront_client = boto3.client('cloudfront')

# Quality tier definitions
QUALITY_TIERS = {
    'bronze': {
        'max_resolution': '480p',
        'max_bitrate': 1000000,  # 1 Mbps
        'allowed_qualities': ['480p'],
        'concurrent_streams': 1
    },
    'silver': {
        'max_resolution': '720p',
        'max_bitrate': 2500000,  # 2.5 Mbps
        'allowed_qualities': ['480p', '720p'],
        'concurrent_streams': 2
    },
    'gold': {
        'max_resolution': '1080p',
        'max_bitrate': 5000000,  # 5 Mbps
        'allowed_qualities': ['480p', '720p', '1080p'],
        'concurrent_streams': 3
    },
    'platinum': {
        'max_resolution': '1080p',
        'max_bitrate': 8000000,  # 8 Mbps
        'allowed_qualities': ['480p', '720p', '1080p'],
        'concurrent_streams': 5,
        'priority_access': True
    }
}

def lambda_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    Quality management Lambda function
    Handles subscription-based quality enforcement and optimization
    """
    
    try:
        # Parse the request
        action = event.get('action', 'get_quality_config')
        user_id = event.get('user_id')
        subscription_tier = event.get('subscription_tier', 'bronze')
        
        logger.info(f"Processing quality action: {action} for user: {user_id}, tier: {subscription_tier}")
        
        if action == 'get_quality_config':
            return get_quality_config(user_id, subscription_tier)
        elif action == 'validate_stream_access':
            return validate_stream_access(event)
        elif action == 'update_viewer_metrics':
            return update_viewer_metrics(event)
        elif action == 'optimize_quality':
            return optimize_quality_for_user(event)
        else:
            return create_response(400, {'error': f'Unknown action: {action}'})
            
    except Exception as e:
        logger.error(f"Error in quality manager: {str(e)}")
        return create_response(500, {
            'error': 'Quality management failed',
            'message': str(e)
        })

def get_quality_config(user_id: str, subscription_tier: str) -> Dict[str, Any]:
    """Get quality configuration for user's subscription tier"""
    try:
        tier_config = QUALITY_TIERS.get(subscription_tier, QUALITY_TIERS['bronze'])
        
        # Get user's current streaming sessions
        current_sessions = get_user_streaming_sessions(user_id)
        
        # Check concurrent stream limits
        can_start_new_stream = len(current_sessions) < tier_config['concurrent_streams']
        
        # Get adaptive bitrate recommendations
        network_conditions = get_user_network_conditions(user_id)
        recommended_quality = get_recommended_quality(tier_config, network_conditions)
        
        quality_config = {
            'user_id': user_id,
            'subscription_tier': subscription_tier,
            'max_resolution': tier_config['max_resolution'],
            'max_bitrate': tier_config['max_bitrate'],
            'allowed_qualities': tier_config['allowed_qualities'],
            'concurrent_streams': {
                'limit': tier_config['concurrent_streams'],
                'current': len(current_sessions),
                'can_start_new': can_start_new_stream
            },
            'recommended_quality': recommended_quality,
            'priority_access': tier_config.get('priority_access', False),
            'adaptive_streaming': {
                'enabled': True,
                'buffer_threshold': get_buffer_threshold(subscription_tier),
                'quality_switch_threshold': get_quality_switch_threshold(subscription_tier)
            }
        }
        
        logger.info(f"Generated quality config for user {user_id}: {recommended_quality}")
        
        return create_response(200, quality_config)
        
    except Exception as e:
        logger.error(f"Error getting quality config: {str(e)}")
        return create_response(500, {
            'error': 'Failed to get quality configuration',
            'message': str(e)
        })

def validate_stream_access(event: Dict[str, Any]) -> Dict[str, Any]:
    """Validate if user can access requested stream quality"""
    try:
        user_id = event.get('user_id')
        subscription_tier = event.get('subscription_tier', 'bronze')
        requested_quality = event.get('requested_quality', '480p')
        stream_id = event.get('stream_id')
        
        tier_config = QUALITY_TIERS.get(subscription_tier, QUALITY_TIERS['bronze'])
        
        # Check if requested quality is allowed for subscription tier
        if requested_quality not in tier_config['allowed_qualities']:
            return create_response(403, {
                'error': 'Quality not allowed for subscription tier',
                'requested_quality': requested_quality,
                'allowed_qualities': tier_config['allowed_qualities'],
                'subscription_tier': subscription_tier,
                'upgrade_required': True
            })
        
        # Check concurrent stream limits
        current_sessions = get_user_streaming_sessions(user_id)
        if len(current_sessions) >= tier_config['concurrent_streams']:
            return create_response(429, {
                'error': 'Concurrent stream limit exceeded',
                'current_sessions': len(current_sessions),
                'limit': tier_config['concurrent_streams'],
                'active_sessions': current_sessions
            })
        
        # Record stream access
        record_stream_access(user_id, stream_id, requested_quality, subscription_tier)
        
        return create_response(200, {
            'access_granted': True,
            'quality': requested_quality,
            'stream_id': stream_id,
            'session_info': {
                'max_duration': get_max_session_duration(subscription_tier),
                'buffer_size': get_buffer_size(subscription_tier),
                'adaptive_enabled': True
            }
        })
        
    except Exception as e:
        logger.error(f"Error validating stream access: {str(e)}")
        return create_response(500, {
            'error': 'Stream access validation failed',
            'message': str(e)
        })

def update_viewer_metrics(event: Dict[str, Any]) -> Dict[str, Any]:
    """Update viewer experience metrics for quality optimization"""
    try:
        user_id = event.get('user_id')
        stream_id = event.get('stream_id')
        metrics = event.get('metrics', {})
        
        # Validate required metrics
        required_metrics = ['buffer_ratio', 'startup_time', 'rebuffer_count', 'quality_switches']
        for metric in required_metrics:
            if metric not in metrics:
                return create_response(400, {
                    'error': f'Missing required metric: {metric}',
                    'required_metrics': required_metrics
                })
        
        # Store metrics in DynamoDB
        timestamp = datetime.now().isoformat()
        
        dynamodb_client.put_item(
            TableName=os.environ['DYNAMODB_ANALYTICS_TABLE'],
            Item={
                'pk': {'S': f'VIEWER_METRICS#{user_id}'},
                'sk': {'S': f'STREAM#{stream_id}#{timestamp}'},
                'user_id': {'S': user_id},
                'stream_id': {'S': stream_id},
                'timestamp': {'S': timestamp},
                'buffer_ratio': {'N': str(metrics['buffer_ratio'])},
                'startup_time': {'N': str(metrics['startup_time'])},
                'rebuffer_count': {'N': str(metrics['rebuffer_count'])},
                'quality_switches': {'N': str(metrics['quality_switches'])},
                'current_quality': {'S': metrics.get('current_quality', '480p')},
                'bandwidth_estimate': {'N': str(metrics.get('bandwidth_estimate', 0))},
                'ttl': {'N': str(int(datetime.now().timestamp()) + 86400 * 7)}  # 7 days TTL
            }
        )
        
        # Trigger quality optimization if metrics indicate poor experience
        if should_trigger_optimization(metrics):
            optimize_quality_for_user({
                'user_id': user_id,
                'stream_id': stream_id,
                'current_metrics': metrics
            })
        
        logger.info(f"Updated viewer metrics for user {user_id}, stream {stream_id}")
        
        return create_response(200, {
            'message': 'Viewer metrics updated successfully',
            'optimization_triggered': should_trigger_optimization(metrics)
        })
        
    except Exception as e:
        logger.error(f"Error updating viewer metrics: {str(e)}")
        return create_response(500, {
            'error': 'Failed to update viewer metrics',
            'message': str(e)
        })

def optimize_quality_for_user(event: Dict[str, Any]) -> Dict[str, Any]:
    """Optimize streaming quality based on user metrics and network conditions"""
    try:
        user_id = event.get('user_id')
        stream_id = event.get('stream_id')
        current_metrics = event.get('current_metrics', {})
        
        # Get user's subscription tier
        subscription_tier = get_user_subscription_tier(user_id)
        tier_config = QUALITY_TIERS.get(subscription_tier, QUALITY_TIERS['bronze'])
        
        # Analyze current performance
        performance_analysis = analyze_streaming_performance(user_id, current_metrics)
        
        # Determine optimal quality
        optimal_quality = determine_optimal_quality(
            tier_config,
            performance_analysis,
            current_metrics
        )
        
        # Generate optimization recommendations
        recommendations = {
            'user_id': user_id,
            'stream_id': stream_id,
            'current_quality': current_metrics.get('current_quality', '480p'),
            'recommended_quality': optimal_quality,
            'performance_score': performance_analysis['score'],
            'optimizations': performance_analysis['recommendations'],
            'adaptive_settings': {
                'buffer_target': calculate_buffer_target(performance_analysis),
                'quality_switch_threshold': calculate_switch_threshold(performance_analysis),
                'startup_quality': determine_startup_quality(tier_config, performance_analysis)
            }
        }
        
        # Store optimization results
        store_optimization_results(user_id, recommendations)
        
        logger.info(f"Generated quality optimization for user {user_id}: {optimal_quality}")
        
        return create_response(200, recommendations)
        
    except Exception as e:
        logger.error(f"Error optimizing quality: {str(e)}")
        return create_response(500, {
            'error': 'Quality optimization failed',
            'message': str(e)
        })

def get_user_streaming_sessions(user_id: str) -> List[Dict[str, Any]]:
    """Get user's current active streaming sessions"""
    try:
        response = dynamodb_client.query(
            TableName=os.environ['DYNAMODB_ANALYTICS_TABLE'],
            KeyConditionExpression='pk = :pk AND begins_with(sk, :sk_prefix)',
            ExpressionAttributeValues={
                ':pk': {'S': f'ACTIVE_SESSIONS#{user_id}'},
                ':sk_prefix': {'S': 'SESSION#'}
            }
        )
        
        sessions = []
        for item in response.get('Items', []):
            sessions.append({
                'session_id': item['sk']['S'].split('#')[1],
                'stream_id': item.get('stream_id', {}).get('S', ''),
                'quality': item.get('quality', {}).get('S', '480p'),
                'start_time': item.get('start_time', {}).get('S', '')
            })
        
        return sessions
        
    except Exception as e:
        logger.error(f"Error getting user sessions: {str(e)}")
        return []

def get_user_network_conditions(user_id: str) -> Dict[str, Any]:
    """Get user's recent network condition metrics"""
    try:
        # Query recent metrics for the user
        response = dynamodb_client.query(
            TableName=os.environ['DYNAMODB_ANALYTICS_TABLE'],
            KeyConditionExpression='pk = :pk',
            ExpressionAttributeValues={
                ':pk': {'S': f'VIEWER_METRICS#{user_id}'}
            },
            ScanIndexForward=False,  # Get most recent first
            Limit=10
        )
        
        if not response.get('Items'):
            return {'bandwidth_estimate': 1000000, 'stability': 'unknown'}  # Default values
        
        # Calculate average network conditions
        total_bandwidth = 0
        buffer_ratios = []
        
        for item in response['Items']:
            if 'bandwidth_estimate' in item:
                total_bandwidth += float(item['bandwidth_estimate']['N'])
            if 'buffer_ratio' in item:
                buffer_ratios.append(float(item['buffer_ratio']['N']))
        
        avg_bandwidth = total_bandwidth / len(response['Items']) if response['Items'] else 1000000
        avg_buffer_ratio = sum(buffer_ratios) / len(buffer_ratios) if buffer_ratios else 0.1
        
        # Determine network stability
        stability = 'stable' if avg_buffer_ratio < 0.1 else 'unstable' if avg_buffer_ratio > 0.3 else 'moderate'
        
        return {
            'bandwidth_estimate': avg_bandwidth,
            'buffer_ratio': avg_buffer_ratio,
            'stability': stability
        }
        
    except Exception as e:
        logger.error(f"Error getting network conditions: {str(e)}")
        return {'bandwidth_estimate': 1000000, 'stability': 'unknown'}

def get_recommended_quality(tier_config: Dict[str, Any], network_conditions: Dict[str, Any]) -> str:
    """Get recommended quality based on tier and network conditions"""
    bandwidth = network_conditions.get('bandwidth_estimate', 1000000)
    stability = network_conditions.get('stability', 'unknown')
    
    # Quality bitrate requirements (approximate)
    quality_bitrates = {
        '480p': 1000000,   # 1 Mbps
        '720p': 2500000,   # 2.5 Mbps
        '1080p': 5000000   # 5 Mbps
    }
    
    # Find highest quality that fits bandwidth and subscription
    recommended = '480p'  # Default
    
    for quality in reversed(tier_config['allowed_qualities']):
        required_bitrate = quality_bitrates.get(quality, 1000000)
        
        # Add buffer for unstable connections
        buffer_multiplier = 1.5 if stability == 'unstable' else 1.2 if stability == 'moderate' else 1.1
        
        if bandwidth >= required_bitrate * buffer_multiplier:
            recommended = quality
            break
    
    return recommended

def should_trigger_optimization(metrics: Dict[str, Any]) -> bool:
    """Determine if quality optimization should be triggered"""
    buffer_ratio = metrics.get('buffer_ratio', 0)
    rebuffer_count = metrics.get('rebuffer_count', 0)
    startup_time = metrics.get('startup_time', 0)
    
    # Trigger optimization if experience is poor
    return (
        buffer_ratio > 0.2 or  # High buffering
        rebuffer_count > 3 or  # Frequent rebuffering
        startup_time > 5000    # Slow startup (5+ seconds)
    )

def analyze_streaming_performance(user_id: str, current_metrics: Dict[str, Any]) -> Dict[str, Any]:
    """Analyze streaming performance and generate recommendations"""
    buffer_ratio = current_metrics.get('buffer_ratio', 0)
    rebuffer_count = current_metrics.get('rebuffer_count', 0)
    startup_time = current_metrics.get('startup_time', 0)
    quality_switches = current_metrics.get('quality_switches', 0)
    
    # Calculate performance score (0-100)
    score = 100
    score -= min(buffer_ratio * 100, 30)  # Penalize buffering
    score -= min(rebuffer_count * 5, 20)  # Penalize rebuffering
    score -= min(startup_time / 100, 20)  # Penalize slow startup
    score -= min(quality_switches * 2, 10)  # Penalize excessive switching
    
    score = max(0, score)
    
    # Generate recommendations
    recommendations = []
    
    if buffer_ratio > 0.15:
        recommendations.append('Reduce quality to improve buffering')
    if startup_time > 3000:
        recommendations.append('Use lower startup quality for faster playback')
    if quality_switches > 5:
        recommendations.append('Increase switching threshold to reduce oscillation')
    if rebuffer_count > 2:
        recommendations.append('Consider adaptive buffer sizing')
    
    return {
        'score': score,
        'recommendations': recommendations,
        'buffer_health': 'good' if buffer_ratio < 0.1 else 'poor',
        'startup_health': 'good' if startup_time < 2000 else 'poor',
        'stability': 'good' if quality_switches < 3 else 'poor'
    }

def determine_optimal_quality(tier_config: Dict[str, Any], performance: Dict[str, Any], metrics: Dict[str, Any]) -> str:
    """Determine optimal quality based on performance analysis"""
    current_quality = metrics.get('current_quality', '480p')
    allowed_qualities = tier_config['allowed_qualities']
    
    # If performance is good, can try higher quality
    if performance['score'] > 80 and current_quality != allowed_qualities[-1]:
        current_index = allowed_qualities.index(current_quality)
        if current_index < len(allowed_qualities) - 1:
            return allowed_qualities[current_index + 1]
    
    # If performance is poor, reduce quality
    elif performance['score'] < 60 and current_quality != allowed_qualities[0]:
        current_index = allowed_qualities.index(current_quality)
        if current_index > 0:
            return allowed_qualities[current_index - 1]
    
    # Otherwise keep current quality
    return current_quality

# Helper functions for configuration
def get_buffer_threshold(subscription_tier: str) -> float:
    thresholds = {'bronze': 0.3, 'silver': 0.2, 'gold': 0.15, 'platinum': 0.1}
    return thresholds.get(subscription_tier, 0.3)

def get_quality_switch_threshold(subscription_tier: str) -> float:
    thresholds = {'bronze': 0.4, 'silver': 0.3, 'gold': 0.2, 'platinum': 0.15}
    return thresholds.get(subscription_tier, 0.4)

def get_max_session_duration(subscription_tier: str) -> int:
    durations = {'bronze': 3600, 'silver': 7200, 'gold': 14400, 'platinum': 28800}  # seconds
    return durations.get(subscription_tier, 3600)

def get_buffer_size(subscription_tier: str) -> int:
    sizes = {'bronze': 10, 'silver': 15, 'gold': 20, 'platinum': 30}  # seconds
    return sizes.get(subscription_tier, 10)

def calculate_buffer_target(performance: Dict[str, Any]) -> float:
    base_target = 0.1
    if performance['score'] < 60:
        base_target = 0.2  # Higher buffer for poor performance
    elif performance['score'] > 80:
        base_target = 0.05  # Lower buffer for good performance
    return base_target

def calculate_switch_threshold(performance: Dict[str, Any]) -> float:
    base_threshold = 0.2
    if performance['stability'] == 'poor':
        base_threshold = 0.4  # Higher threshold to reduce switching
    return base_threshold

def determine_startup_quality(tier_config: Dict[str, Any], performance: Dict[str, Any]) -> str:
    allowed = tier_config['allowed_qualities']
    if performance['startup_health'] == 'poor':
        return allowed[0]  # Start with lowest quality
    else:
        return allowed[min(1, len(allowed) - 1)]  # Start with medium quality

def get_user_subscription_tier(user_id: str) -> str:
    """Get user's subscription tier from database"""
    try:
        # This would query the user database - simplified for example
        return 'silver'  # Default tier
    except Exception:
        return 'bronze'

def record_stream_access(user_id: str, stream_id: str, quality: str, subscription_tier: str):
    """Record stream access for analytics"""
    try:
        timestamp = datetime.now().isoformat()
        session_id = f"{user_id}_{stream_id}_{int(datetime.now().timestamp())}"
        
        dynamodb_client.put_item(
            TableName=os.environ['DYNAMODB_ANALYTICS_TABLE'],
            Item={
                'pk': {'S': f'ACTIVE_SESSIONS#{user_id}'},
                'sk': {'S': f'SESSION#{session_id}'},
                'user_id': {'S': user_id},
                'stream_id': {'S': stream_id},
                'quality': {'S': quality},
                'subscription_tier': {'S': subscription_tier},
                'start_time': {'S': timestamp},
                'ttl': {'N': str(int(datetime.now().timestamp()) + 86400)}  # 24 hours TTL
            }
        )
    except Exception as e:
        logger.error(f"Error recording stream access: {str(e)}")

def store_optimization_results(user_id: str, recommendations: Dict[str, Any]):
    """Store optimization results for future reference"""
    try:
        timestamp = datetime.now().isoformat()
        
        dynamodb_client.put_item(
            TableName=os.environ['DYNAMODB_ANALYTICS_TABLE'],
            Item={
                'pk': {'S': f'OPTIMIZATION#{user_id}'},
                'sk': {'S': f'RESULT#{timestamp}'},
                'user_id': {'S': user_id},
                'timestamp': {'S': timestamp},
                'recommendations': {'S': json.dumps(recommendations)},
                'ttl': {'N': str(int(datetime.now().timestamp()) + 86400 * 30)}  # 30 days TTL
            }
        )
    except Exception as e:
        logger.error(f"Error storing optimization results: {str(e)}")

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