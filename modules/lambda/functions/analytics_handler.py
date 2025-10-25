import json
import boto3
import os
import logging
import random
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
cloudwatch_client = boto3.client('cloudwatch')
rds_client = boto3.client('rds-data')
dynamodb = boto3.resource('dynamodb')

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

@handle_database_errors
def handle_get_metrics(query_params):
    """Handle metrics retrieval with real CloudWatch data"""
    try:
        metric_type = query_params.get('type', 'all') if query_params else 'all'
        time_range = query_params.get('range', '24h') if query_params else '24h'
        streamer_filter = query_params.get('streamer') if query_params else None
        
        # Parse time range
        end_time = datetime.utcnow()
        if time_range == '1h':
            start_time = end_time - timedelta(hours=1)
        elif time_range == '24h':
            start_time = end_time - timedelta(hours=24)
        elif time_range == '7d':
            start_time = end_time - timedelta(days=7)
        elif time_range == '30d':
            start_time = end_time - timedelta(days=30)
        else:
            start_time = end_time - timedelta(hours=24)
        
        # Get real metrics from CloudWatch and database
        metrics = {}
        
        if metric_type == 'all' or metric_type == 'viewers':
            metrics['viewers'] = get_viewer_metrics(start_time, end_time, streamer_filter)
        
        if metric_type == 'all' or metric_type == 'streams':
            metrics['streams'] = get_stream_metrics(start_time, end_time, streamer_filter)
        
        if metric_type == 'all' or metric_type == 'system':
            metrics['system'] = get_system_metrics(start_time, end_time)
        
        if metric_type == 'all' or metric_type == 'engagement':
            metrics['engagement'] = get_engagement_metrics(start_time, end_time, streamer_filter)
        
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

@handle_database_errors
def handle_dashboard_data():
    """Handle dashboard data request with real data aggregation"""
    try:
        # Get overview statistics from database
        overview = get_overview_statistics()
        
        # Get recent streams
        recent_streams = get_recent_streams()
        
        # Get top categories
        top_categories = get_top_categories()
        
        # Get system health metrics
        system_health = get_system_health()
        
        dashboard_data = {
            'overview': overview,
            'recent_streams': recent_streams,
            'top_categories': top_categories,
            'system_health': system_health,
            'last_updated': datetime.utcnow().isoformat()
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

# Database and CloudWatch helper functions
def handle_database_errors(func):
    """Decorator for database operations with comprehensive error handling"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            logger.error(f"Database operation error in {func.__name__}: {str(e)}")
            return create_response(500, {'error': 'Database operation failed'})
    return wrapper

def execute_sql(sql: str, parameters: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Execute SQL query with proper error handling"""
    try:
        response = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        return response
    except Exception as e:
        logger.error(f"SQL execution error: {str(e)}")
        raise

def get_cloudwatch_metric(namespace: str, metric_name: str, dimensions: List[Dict], 
                         start_time: datetime, end_time: datetime, statistic: str = 'Average') -> float:
    """Get CloudWatch metric value"""
    try:
        response = cloudwatch_client.get_metric_statistics(
            Namespace=namespace,
            MetricName=metric_name,
            Dimensions=dimensions,
            StartTime=start_time,
            EndTime=end_time,
            Period=300,  # 5 minutes
            Statistics=[statistic]
        )
        
        datapoints = response.get('Datapoints', [])
        if datapoints:
            return max(datapoint[statistic] for datapoint in datapoints)
        return 0.0
        
    except Exception as e:
        logger.error(f"CloudWatch metric error: {str(e)}")
        return 0.0

def get_viewer_metrics(start_time: datetime, end_time: datetime, streamer_filter: Optional[str]) -> Dict[str, Any]:
    """Get viewer metrics from database and CloudWatch"""
    try:
        # Current active viewers from database
        sql = """
        SELECT SUM(viewer_count) as current_viewers,
               MAX(viewer_count) as peak_viewers,
               AVG(viewer_count) as avg_viewers
        FROM streams 
        WHERE status = 'live'
        """
        
        if streamer_filter:
            sql += """
            AND creator_id IN (
                SELECT id FROM users WHERE username ILIKE :streamer
            )
            """
            parameters = [{'name': 'streamer', 'value': {'stringValue': f'%{streamer_filter}%'}}]
        else:
            parameters = []
        
        result = execute_sql(sql, parameters)
        
        current_viewers = 0
        peak_viewers = 0
        avg_viewers = 0
        
        if result.get('records') and len(result['records']) > 0:
            record = result['records'][0]
            current_viewers = int(record[0]['longValue']) if record[0].get('longValue') else 0
            peak_viewers = int(record[1]['longValue']) if record[1].get('longValue') else 0
            avg_viewers = float(record[2]['doubleValue']) if record[2].get('doubleValue') else 0.0
        
        # Historical peak from analytics table
        historical_sql = """
        SELECT MAX(metric_value) as historical_peak
        FROM stream_analytics 
        WHERE metric_type = 'viewer_count' 
        AND recorded_at BETWEEN :start_time AND :end_time
        """
        
        hist_params = [
            {'name': 'start_time', 'value': {'stringValue': start_time.isoformat()}},
            {'name': 'end_time', 'value': {'stringValue': end_time.isoformat()}}
        ]
        
        hist_result = execute_sql(historical_sql, hist_params)
        historical_peak = 0
        
        if hist_result.get('records') and len(hist_result['records']) > 0:
            record = hist_result['records'][0]
            historical_peak = float(record[0]['doubleValue']) if record[0].get('doubleValue') else 0.0
        
        return {
            'current': current_viewers,
            'peak_24h': max(peak_viewers, historical_peak),
            'average_24h': round(avg_viewers, 1),
            'total_unique_viewers': get_unique_viewer_count(start_time, end_time, streamer_filter)
        }
        
    except Exception as e:
        logger.error(f"Viewer metrics error: {str(e)}")
        return {'current': 0, 'peak_24h': 0, 'average_24h': 0, 'total_unique_viewers': 0}

def get_stream_metrics(start_time: datetime, end_time: datetime, streamer_filter: Optional[str]) -> Dict[str, Any]:
    """Get stream metrics from database"""
    try:
        # Active streams
        active_sql = "SELECT COUNT(*) FROM streams WHERE status = 'live'"
        active_params = []
        
        if streamer_filter:
            active_sql += """
            AND creator_id IN (
                SELECT id FROM users WHERE username ILIKE :streamer
            )
            """
            active_params = [{'name': 'streamer', 'value': {'stringValue': f'%{streamer_filter}%'}}]
        
        active_result = execute_sql(active_sql, active_params)
        active_streams = int(active_result['records'][0][0]['longValue']) if active_result.get('records') else 0
        
        # Total streams in time period
        total_sql = """
        SELECT COUNT(*) as total_streams,
               COUNT(CASE WHEN status = 'ended' THEN 1 END) as completed_streams,
               AVG(CASE WHEN end_time IS NOT NULL AND actual_start IS NOT NULL 
                   THEN EXTRACT(EPOCH FROM (end_time - actual_start))/60 END) as avg_duration
        FROM streams 
        WHERE created_at BETWEEN :start_time AND :end_time
        """
        
        total_params = [
            {'name': 'start_time', 'value': {'stringValue': start_time.isoformat()}},
            {'name': 'end_time', 'value': {'stringValue': end_time.isoformat()}}
        ]
        
        if streamer_filter:
            total_sql += """
            AND creator_id IN (
                SELECT id FROM users WHERE username ILIKE :streamer
            )
            """
            total_params.append({'name': 'streamer', 'value': {'stringValue': f'%{streamer_filter}%'}})
        
        total_result = execute_sql(total_sql, total_params)
        
        total_streams = 0
        completed_streams = 0
        avg_duration = 0
        
        if total_result.get('records') and len(total_result['records']) > 0:
            record = total_result['records'][0]
            total_streams = int(record[0]['longValue']) if record[0].get('longValue') else 0
            completed_streams = int(record[1]['longValue']) if record[1].get('longValue') else 0
            avg_duration = float(record[2]['doubleValue']) if record[2].get('doubleValue') else 0.0
        
        return {
            'active': active_streams,
            'total_24h': total_streams,
            'completed_24h': completed_streams,
            'average_duration_minutes': round(avg_duration, 1)
        }
        
    except Exception as e:
        logger.error(f"Stream metrics error: {str(e)}")
        return {'active': 0, 'total_24h': 0, 'completed_24h': 0, 'average_duration_minutes': 0}

def get_system_metrics(start_time: datetime, end_time: datetime) -> Dict[str, Any]:
    """Get system performance metrics from CloudWatch"""
    try:
        # Lambda function metrics
        lambda_duration = get_cloudwatch_metric(
            'AWS/Lambda', 'Duration',
            [{'Name': 'FunctionName', 'Value': 'streaming-platform-handler'}],
            start_time, end_time, 'Average'
        )
        
        lambda_errors = get_cloudwatch_metric(
            'AWS/Lambda', 'Errors',
            [{'Name': 'FunctionName', 'Value': 'streaming-platform-handler'}],
            start_time, end_time, 'Sum'
        )
        
        # API Gateway metrics
        api_latency = get_cloudwatch_metric(
            'AWS/ApiGateway', 'Latency',
            [{'Name': 'ApiName', 'Value': 'streaming-platform-api'}],
            start_time, end_time, 'Average'
        )
        
        api_errors = get_cloudwatch_metric(
            'AWS/ApiGateway', '4XXError',
            [{'Name': 'ApiName', 'Value': 'streaming-platform-api'}],
            start_time, end_time, 'Sum'
        )
        
        # Database metrics
        db_connections = get_cloudwatch_metric(
            'AWS/RDS', 'DatabaseConnections',
            [{'Name': 'DBClusterIdentifier', 'Value': 'streaming-platform-aurora'}],
            start_time, end_time, 'Average'
        )
        
        return {
            'lambda_avg_duration_ms': round(lambda_duration, 2),
            'lambda_error_count': int(lambda_errors),
            'api_avg_latency_ms': round(api_latency, 2),
            'api_error_count': int(api_errors),
            'db_avg_connections': round(db_connections, 1),
            'system_health': 'healthy' if lambda_errors < 10 and api_errors < 50 else 'degraded'
        }
        
    except Exception as e:
        logger.error(f"System metrics error: {str(e)}")
        return {
            'lambda_avg_duration_ms': 0,
            'lambda_error_count': 0,
            'api_avg_latency_ms': 0,
            'api_error_count': 0,
            'db_avg_connections': 0,
            'system_health': 'unknown'
        }

def get_engagement_metrics(start_time: datetime, end_time: datetime, streamer_filter: Optional[str]) -> Dict[str, Any]:
    """Get engagement metrics from analytics data"""
    try:
        # This would typically come from a chat messages table or analytics events
        # For now, we'll calculate based on stream analytics
        sql = """
        SELECT 
            COUNT(CASE WHEN metric_type = 'chat_activity' THEN 1 END) as chat_events,
            SUM(CASE WHEN metric_type = 'chat_activity' THEN metric_value ELSE 0 END) as total_messages,
            COUNT(CASE WHEN metric_type = 'engagement' THEN 1 END) as engagement_events
        FROM stream_analytics 
        WHERE recorded_at BETWEEN :start_time AND :end_time
        """
        
        parameters = [
            {'name': 'start_time', 'value': {'stringValue': start_time.isoformat()}},
            {'name': 'end_time', 'value': {'stringValue': end_time.isoformat()}}
        ]
        
        if streamer_filter:
            sql += """
            AND stream_id IN (
                SELECT id FROM streams s
                JOIN users u ON s.creator_id = u.id
                WHERE u.username ILIKE :streamer
            )
            """
            parameters.append({'name': 'streamer', 'value': {'stringValue': f'%{streamer_filter}%'}})
        
        result = execute_sql(sql, parameters)
        
        chat_events = 0
        total_messages = 0
        engagement_events = 0
        
        if result.get('records') and len(result['records']) > 0:
            record = result['records'][0]
            chat_events = int(record[0]['longValue']) if record[0].get('longValue') else 0
            total_messages = float(record[1]['doubleValue']) if record[1].get('doubleValue') else 0
            engagement_events = int(record[2]['longValue']) if record[2].get('longValue') else 0
        
        return {
            'chat_messages_24h': int(total_messages),
            'active_chatters': chat_events,
            'engagement_events': engagement_events,
            'avg_messages_per_stream': round(total_messages / max(chat_events, 1), 1)
        }
        
    except Exception as e:
        logger.error(f"Engagement metrics error: {str(e)}")
        return {
            'chat_messages_24h': 0,
            'active_chatters': 0,
            'engagement_events': 0,
            'avg_messages_per_stream': 0
        }

def get_overview_statistics() -> Dict[str, Any]:
    """Get overview statistics for dashboard"""
    try:
        sql = """
        SELECT 
            (SELECT COUNT(*) FROM users) as total_users,
            (SELECT COUNT(*) FROM streams WHERE status = 'live') as active_streams,
            (SELECT SUM(total_views) FROM streams) as total_views,
            (SELECT COUNT(*) FROM users WHERE last_login > NOW() - INTERVAL '24 hours') as active_users_24h
        """
        
        result = execute_sql(sql, [])
        
        if result.get('records') and len(result['records']) > 0:
            record = result['records'][0]
            return {
                'total_users': int(record[0]['longValue']) if record[0].get('longValue') else 0,
                'active_streams': int(record[1]['longValue']) if record[1].get('longValue') else 0,
                'total_views': int(record[2]['longValue']) if record[2].get('longValue') else 0,
                'active_users_24h': int(record[3]['longValue']) if record[3].get('longValue') else 0
            }
        
        return {'total_users': 0, 'active_streams': 0, 'total_views': 0, 'active_users_24h': 0}
        
    except Exception as e:
        logger.error(f"Overview statistics error: {str(e)}")
        return {'total_users': 0, 'active_streams': 0, 'total_views': 0, 'active_users_24h': 0}

def get_recent_streams() -> List[Dict[str, Any]]:
    """Get recent streams for dashboard"""
    try:
        sql = """
        SELECT s.id, s.title, s.status, s.viewer_count, s.actual_start,
               u.username, u.display_name
        FROM streams s
        JOIN users u ON s.creator_id = u.id
        WHERE s.status IN ('live', 'ended')
        ORDER BY s.actual_start DESC
        LIMIT 10
        """
        
        result = execute_sql(sql, [])
        
        streams = []
        for record in result.get('records', []):
            stream = {
                'stream_id': record[0]['stringValue'],
                'title': record[1]['stringValue'],
                'status': record[2]['stringValue'],
                'viewers': int(record[3]['longValue']) if record[3].get('longValue') else 0,
                'started_at': record[4]['stringValue'] if record[4].get('stringValue') else None,
                'streamer': record[5]['stringValue'],
                'streamer_display_name': record[6]['stringValue'] if record[6].get('stringValue') else None
            }
            streams.append(stream)
        
        return streams
        
    except Exception as e:
        logger.error(f"Recent streams error: {str(e)}")
        return []

def get_top_categories() -> List[Dict[str, Any]]:
    """Get top streaming categories"""
    try:
        sql = """
        SELECT category, COUNT(*) as stream_count, SUM(viewer_count) as total_viewers
        FROM streams 
        WHERE status = 'live' AND category IS NOT NULL
        GROUP BY category
        ORDER BY total_viewers DESC
        LIMIT 10
        """
        
        result = execute_sql(sql, [])
        
        categories = []
        for record in result.get('records', []):
            category = {
                'name': record[0]['stringValue'],
                'stream_count': int(record[1]['longValue']) if record[1].get('longValue') else 0,
                'viewers': int(record[2]['longValue']) if record[2].get('longValue') else 0
            }
            categories.append(category)
        
        return categories
        
    except Exception as e:
        logger.error(f"Top categories error: {str(e)}")
        return []

def get_system_health() -> Dict[str, Any]:
    """Get system health indicators"""
    try:
        # Check database connectivity
        db_health = True
        try:
            execute_sql("SELECT 1", [])
        except:
            db_health = False
        
        # Check recent errors
        error_count = 0
        try:
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=1)
            error_count = get_cloudwatch_metric(
                'AWS/Lambda', 'Errors',
                [{'Name': 'FunctionName', 'Value': 'streaming-platform-handler'}],
                start_time, end_time, 'Sum'
            )
        except:
            pass
        
        overall_health = 'healthy'
        if not db_health or error_count > 10:
            overall_health = 'unhealthy'
        elif error_count > 5:
            overall_health = 'degraded'
        
        return {
            'overall': overall_health,
            'database': 'healthy' if db_health else 'unhealthy',
            'api': 'healthy' if error_count < 5 else 'degraded',
            'recent_errors': int(error_count)
        }
        
    except Exception as e:
        logger.error(f"System health error: {str(e)}")
        return {
            'overall': 'unknown',
            'database': 'unknown',
            'api': 'unknown',
            'recent_errors': 0
        }

def get_unique_viewer_count(start_time: datetime, end_time: datetime, streamer_filter: Optional[str]) -> int:
    """Get unique viewer count (simplified estimation)"""
    try:
        # This is a simplified calculation - in a real system you'd track unique viewers
        sql = """
        SELECT COUNT(DISTINCT stream_id) * 50 as estimated_unique_viewers
        FROM stream_analytics 
        WHERE metric_type = 'viewer_count' 
        AND recorded_at BETWEEN :start_time AND :end_time
        """
        
        parameters = [
            {'name': 'start_time', 'value': {'stringValue': start_time.isoformat()}},
            {'name': 'end_time', 'value': {'stringValue': end_time.isoformat()}}
        ]
        
        result = execute_sql(sql, parameters)
        
        if result.get('records') and len(result['records']) > 0:
            return int(result['records'][0][0]['longValue']) if result['records'][0][0].get('longValue') else 0
        
        return 0
        
    except Exception as e:
        logger.error(f"Unique viewer count error: {str(e)}")
        return 0

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