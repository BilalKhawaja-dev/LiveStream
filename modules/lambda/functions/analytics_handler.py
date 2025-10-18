import json
import boto3
import os
import logging
from datetime import datetime, timedelta
import random

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
cloudwatch_client = boto3.client('cloudwatch')

def lambda_handler(event, context):
    """
    Handle analytics requests
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract HTTP method and path
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        
        # Parse request body
        body = {}
        if event.get('body'):
            try:
                body = json.loads(event['body'])
            except json.JSONDecodeError:
                return create_response(400, {'error': 'Invalid JSON in request body'})
        
        # Route based on path and method
        if path == '/analytics' and http_method == 'GET':
            return handle_dashboard_data()
        elif path == '/analytics/metrics' and http_method == 'GET':
            return handle_get_metrics(event.get('queryStringParameters', {}))
        elif path == '/analytics/events' and http_method == 'POST':
            return handle_track_event(body)
        elif path == '/analytics/dashboard' and http_method == 'GET':
            return handle_dashboard_data()
        elif path == '/analytics/reports' and http_method == 'GET':
            return handle_reports(event.get('queryStringParameters', {}))
        elif path == '/analytics/users' and http_method == 'GET':
            return handle_user_analytics(event.get('queryStringParameters', {}))
        elif path == '/analytics/streams' and http_method == 'GET':
            return handle_stream_analytics(event.get('queryStringParameters', {}))
        elif path == '/analytics/revenue' and http_method == 'GET':
            return handle_revenue_analytics(event.get('queryStringParameters', {}))
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_get_metrics(query_params):
    """Handle metrics retrieval"""
    try:
        metric_type = query_params.get('type', 'all') if query_params else 'all'
        time_range = query_params.get('range', '24h') if query_params else '24h'
        
        # Mock metrics data (replace with actual CloudWatch queries)
        metrics = {
            'viewers': {
                'current': random.randint(100, 1000),
                'peak_24h': random.randint(500, 2000),
                'average_24h': random.randint(200, 800)
            },
            'streams': {
                'active': random.randint(5, 50),
                'total_24h': random.randint(20, 100),
                'completed_24h': random.randint(15, 80)
            },
            'bandwidth': {
                'current_mbps': round(random.uniform(100, 1000), 2),
                'peak_24h_mbps': round(random.uniform(500, 2000), 2),
                'total_24h_gb': round(random.uniform(1000, 5000), 2)
            },
            'engagement': {
                'chat_messages_24h': random.randint(1000, 10000),
                'likes_24h': random.randint(500, 5000),
                'shares_24h': random.randint(50, 500)
            }
        }
        
        if metric_type != 'all' and metric_type in metrics:
            return create_response(200, {metric_type: metrics[metric_type]})
        
        return create_response(200, metrics)
        
    except Exception as e:
        logger.error(f"Get metrics error: {str(e)}")
        return create_response(500, {'error': 'Failed to retrieve metrics'})

def handle_track_event(body):
    """Handle event tracking"""
    try:
        event_type = body.get('event_type')
        user_id = body.get('user_id')
        stream_id = body.get('stream_id')
        properties = body.get('properties', {})
        
        if not event_type:
            return create_response(400, {'error': 'Event type required'})
        
        # Mock event tracking (replace with actual analytics service)
        event_data = {
            'event_id': f"evt_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{random.randint(1000, 9999)}",
            'event_type': event_type,
            'user_id': user_id,
            'stream_id': stream_id,
            'properties': properties,
            'timestamp': datetime.now().isoformat()
        }
        
        logger.info(f"Tracked event: {event_data}")
        
        return create_response(200, {
            'message': 'Event tracked successfully',
            'event_id': event_data['event_id']
        })
        
    except Exception as e:
        logger.error(f"Track event error: {str(e)}")
        return create_response(500, {'error': 'Failed to track event'})

def handle_dashboard_data():
    """Handle dashboard data request"""
    try:
        # Mock dashboard data (replace with actual data aggregation)
        dashboard_data = {
            'overview': {
                'total_users': random.randint(10000, 50000),
                'active_streams': random.randint(10, 100),
                'total_views_today': random.randint(50000, 200000),
                'revenue_today': round(random.uniform(1000, 10000), 2)
            },
            'recent_streams': [
                {
                    'stream_id': 'stream_001',
                    'title': 'Gaming Tournament',
                    'streamer': 'ProGamer123',
                    'viewers': random.randint(100, 1000),
                    'duration': '02:15:30',
                    'status': 'live'
                },
                {
                    'stream_id': 'stream_002',
                    'title': 'Music Session',
                    'streamer': 'MusicMaker',
                    'viewers': random.randint(50, 500),
                    'duration': '01:45:20',
                    'status': 'live'
                }
            ],
            'top_categories': [
                {'name': 'Gaming', 'viewers': random.randint(5000, 15000)},
                {'name': 'Music', 'viewers': random.randint(2000, 8000)},
                {'name': 'Talk Shows', 'viewers': random.randint(1000, 5000)},
                {'name': 'Education', 'viewers': random.randint(500, 3000)}
            ]
        }
        
        return create_response(200, dashboard_data)
        
    except Exception as e:
        logger.error(f"Dashboard data error: {str(e)}")
        return create_response(500, {'error': 'Failed to retrieve dashboard data'})

def handle_reports(query_params):
    """Handle reports request"""
    try:
        report_type = query_params.get('type', 'summary') if query_params else 'summary'
        date_from = query_params.get('from') if query_params else None
        date_to = query_params.get('to') if query_params else None
        
        # Mock report data (replace with actual report generation)
        report_data = {
            'report_type': report_type,
            'period': {
                'from': date_from or (datetime.now() - timedelta(days=7)).isoformat(),
                'to': date_to or datetime.now().isoformat()
            },
            'summary': {
                'total_streams': random.randint(100, 500),
                'total_viewers': random.randint(10000, 50000),
                'total_watch_time_hours': random.randint(5000, 25000),
                'average_stream_duration_minutes': random.randint(60, 180)
            },
            'trends': [
                {'date': '2024-01-15', 'streams': random.randint(20, 50), 'viewers': random.randint(2000, 5000)},
                {'date': '2024-01-14', 'streams': random.randint(20, 50), 'viewers': random.randint(2000, 5000)},
                {'date': '2024-01-13', 'streams': random.randint(20, 50), 'viewers': random.randint(2000, 5000)}
            ]
        }
        
        return create_response(200, report_data)
        
    except Exception as e:
        logger.error(f"Reports error: {str(e)}")
        return create_response(500, {'error': 'Failed to generate report'})

def handle_user_analytics(query_params):
    """Handle user analytics"""
    try:
        user_analytics = {
            'total_users': random.randint(10000, 50000),
            'active_users_today': random.randint(1000, 5000),
            'new_registrations_today': random.randint(50, 200),
            'user_retention_rate': round(random.uniform(0.7, 0.9), 2)
        }
        
        return create_response(200, user_analytics)
        
    except Exception as e:
        logger.error(f"User analytics error: {str(e)}")
        return create_response(500, {'error': 'Failed to get user analytics'})

def handle_stream_analytics(query_params):
    """Handle stream analytics"""
    try:
        stream_analytics = {
            'total_streams_today': random.randint(100, 500),
            'live_streams_now': random.randint(10, 50),
            'average_stream_duration': f"{random.randint(60, 180)} minutes",
            'top_categories': [
                {'name': 'Gaming', 'count': random.randint(50, 200)},
                {'name': 'Music', 'count': random.randint(20, 100)},
                {'name': 'Education', 'count': random.randint(10, 50)}
            ]
        }
        
        return create_response(200, stream_analytics)
        
    except Exception as e:
        logger.error(f"Stream analytics error: {str(e)}")
        return create_response(500, {'error': 'Failed to get stream analytics'})

def handle_revenue_analytics(query_params):
    """Handle revenue analytics"""
    try:
        revenue_analytics = {
            'total_revenue_today': round(random.uniform(1000, 10000), 2),
            'subscription_revenue': round(random.uniform(500, 5000), 2),
            'donation_revenue': round(random.uniform(200, 2000), 2),
            'ad_revenue': round(random.uniform(100, 1000), 2),
            'top_earners': [
                {'streamer': 'ProGamer123', 'revenue': round(random.uniform(100, 1000), 2)},
                {'streamer': 'MusicMaker', 'revenue': round(random.uniform(50, 500), 2)}
            ]
        }
        
        return create_response(200, revenue_analytics)
        
    except Exception as e:
        logger.error(f"Revenue analytics error: {str(e)}")
        return create_response(500, {'error': 'Failed to get revenue analytics'})

def create_response(status_code, body):
    """Create HTTP response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body)
    }