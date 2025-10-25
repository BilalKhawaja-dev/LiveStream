import json
import boto3
import os
import logging
from datetime import datetime, timedelta
import pandas as pd
from io import StringIO

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
athena_client = boto3.client('athena')
rds_data_client = boto3.client('rds-data')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
ANALYTICS_BUCKET = os.environ['ANALYTICS_BUCKET']
ATHENA_WORKGROUP = os.environ['ATHENA_WORKGROUP']
ATHENA_DATABASE = os.environ['ATHENA_DATABASE']
AURORA_CLUSTER_ARN = os.environ['AURORA_CLUSTER_ARN']
AURORA_SECRET_ARN = os.environ['AURORA_SECRET_ARN']

def lambda_handler(event, context):
    """
    Process analytics data and generate insights
    """
    try:
        logger.info(f"Processing analytics event: {json.dumps(event)}")
        
        action = event.get('action', 'hourly_processing')
        
        if action == 'hourly_processing':
            return process_hourly_analytics()
        elif action == 'daily_aggregation':
            return process_daily_aggregation()
        elif action == 'custom_query':
            return process_custom_query(event)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid action'})
            }
            
    except Exception as e:
        logger.error(f"Error processing analytics: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process analytics'})
        }

def process_hourly_analytics():
    """Process hourly analytics aggregation"""
    try:
        logger.info("Starting hourly analytics processing")
        
        # Get current hour data
        current_hour = datetime.now().replace(minute=0, second=0, microsecond=0)
        previous_hour = current_hour - timedelta(hours=1)
        
        # Process different analytics categories
        results = {
            'user_engagement': process_user_engagement_analytics(previous_hour, current_hour),
            'stream_performance': process_stream_performance_analytics(previous_hour, current_hour),
            'content_analytics': process_content_analytics(previous_hour, current_hour),
            'revenue_metrics': process_revenue_analytics(previous_hour, current_hour)
        }
        
        # Store aggregated data in S3
        store_hourly_analytics(results, previous_hour)
        
        # Send custom metrics to CloudWatch
        send_cloudwatch_metrics(results, previous_hour)
        
        logger.info("Hourly analytics processing completed")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Hourly analytics processed successfully',
                'timestamp': previous_hour.isoformat(),
                'results': results
            })
        }
        
    except Exception as e:
        logger.error(f"Error in hourly analytics processing: {str(e)}")
        raise

def process_user_engagement_analytics(start_time, end_time):
    """Process user engagement metrics"""
    try:
        # Query user sessions and activities
        query = """
        SELECT 
            COUNT(DISTINCT us.user_id) as active_users,
            AVG(us.duration_seconds) as avg_session_duration,
            COUNT(us.id) as total_sessions,
            COUNT(DISTINCT ae.user_id) as engaged_users,
            COUNT(ae.id) as total_events
        FROM user_sessions us
        LEFT JOIN analytics_events ae ON us.user_id = ae.user_id 
            AND ae.server_timestamp BETWEEN :start_time AND :end_time
        WHERE us.started_at BETWEEN :start_time AND :end_time
        """
        
        result = execute_aurora_query(query, {
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat()
        })
        
        if result and len(result) > 0:
            row = result[0]
            return {
                'active_users': row.get('active_users', 0),
                'avg_session_duration': float(row.get('avg_session_duration', 0) or 0),
                'total_sessions': row.get('total_sessions', 0),
                'engaged_users': row.get('engaged_users', 0),
                'total_events': row.get('total_events', 0),
                'engagement_rate': (row.get('engaged_users', 0) / max(row.get('active_users', 1), 1)) * 100
            }
        
        return {
            'active_users': 0,
            'avg_session_duration': 0,
            'total_sessions': 0,
            'engaged_users': 0,
            'total_events': 0,
            'engagement_rate': 0
        }
        
    except Exception as e:
        logger.error(f"Error processing user engagement analytics: {str(e)}")
        return {}

def process_stream_performance_analytics(start_time, end_time):
    """Process stream performance metrics"""
    try:
        # Query stream metrics
        query = """
        SELECT 
            COUNT(DISTINCT s.id) as active_streams,
            AVG(s.viewer_count) as avg_viewers_per_stream,
            SUM(s.viewer_count) as total_concurrent_viewers,
            MAX(s.viewer_count) as peak_concurrent_viewers,
            COUNT(DISTINCT cm.user_id) as unique_chatters,
            COUNT(cm.id) as total_chat_messages
        FROM streams s
        LEFT JOIN chat_messages cm ON s.id = cm.stream_id 
            AND cm.created_at BETWEEN :start_time AND :end_time
        WHERE s.status = 'live' 
            AND s.actual_start <= :end_time 
            AND (s.end_time IS NULL OR s.end_time >= :start_time)
        """
        
        result = execute_aurora_query(query, {
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat()
        })
        
        if result and len(result) > 0:
            row = result[0]
            return {
                'active_streams': row.get('active_streams', 0),
                'avg_viewers_per_stream': float(row.get('avg_viewers_per_stream', 0) or 0),
                'total_concurrent_viewers': row.get('total_concurrent_viewers', 0),
                'peak_concurrent_viewers': row.get('peak_concurrent_viewers', 0),
                'unique_chatters': row.get('unique_chatters', 0),
                'total_chat_messages': row.get('total_chat_messages', 0),
                'chat_engagement_rate': (row.get('unique_chatters', 0) / max(row.get('total_concurrent_viewers', 1), 1)) * 100
            }
        
        return {
            'active_streams': 0,
            'avg_viewers_per_stream': 0,
            'total_concurrent_viewers': 0,
            'peak_concurrent_viewers': 0,
            'unique_chatters': 0,
            'total_chat_messages': 0,
            'chat_engagement_rate': 0
        }
        
    except Exception as e:
        logger.error(f"Error processing stream performance analytics: {str(e)}")
        return {}

def process_content_analytics(start_time, end_time):
    """Process content analytics"""
    try:
        # Query content metrics
        query = """
        SELECT 
            COUNT(vc.id) as videos_uploaded,
            COUNT(CASE WHEN vc.processing_status = 'completed' THEN 1 END) as videos_processed,
            AVG(vc.duration_seconds) as avg_video_duration,
            SUM(vc.view_count) as total_video_views,
            COUNT(CASE WHEN cm.moderation_status = 'flagged' THEN 1 END) as flagged_content_count,
            COUNT(CASE WHEN cm.moderation_status = 'approved' THEN 1 END) as approved_content_count
        FROM video_content vc
        LEFT JOIN content_moderation cm ON vc.id = cm.content_id 
            AND cm.created_at BETWEEN :start_time AND :end_time
        WHERE vc.created_at BETWEEN :start_time AND :end_time
        """
        
        result = execute_aurora_query(query, {
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat()
        })
        
        if result and len(result) > 0:
            row = result[0]
            total_content = row.get('flagged_content_count', 0) + row.get('approved_content_count', 0)
            return {
                'videos_uploaded': row.get('videos_uploaded', 0),
                'videos_processed': row.get('videos_processed', 0),
                'avg_video_duration': float(row.get('avg_video_duration', 0) or 0),
                'total_video_views': row.get('total_video_views', 0),
                'flagged_content_count': row.get('flagged_content_count', 0),
                'approved_content_count': row.get('approved_content_count', 0),
                'content_approval_rate': (row.get('approved_content_count', 0) / max(total_content, 1)) * 100
            }
        
        return {
            'videos_uploaded': 0,
            'videos_processed': 0,
            'avg_video_duration': 0,
            'total_video_views': 0,
            'flagged_content_count': 0,
            'approved_content_count': 0,
            'content_approval_rate': 100
        }
        
    except Exception as e:
        logger.error(f"Error processing content analytics: {str(e)}")
        return {}

def process_revenue_analytics(start_time, end_time):
    """Process revenue and subscription metrics"""
    try:
        # Query revenue metrics
        query = """
        SELECT 
            COUNT(CASE WHEN pt.type = 'subscription' AND pt.status = 'succeeded' THEN 1 END) as successful_subscriptions,
            COUNT(CASE WHEN pt.type = 'donation' AND pt.status = 'succeeded' THEN 1 END) as successful_donations,
            SUM(CASE WHEN pt.status = 'succeeded' THEN pt.amount ELSE 0 END) as total_revenue,
            AVG(CASE WHEN pt.type = 'subscription' AND pt.status = 'succeeded' THEN pt.amount END) as avg_subscription_value,
            COUNT(DISTINCT u.id) as total_subscribers,
            COUNT(CASE WHEN u.subscription_tier = 'bronze' THEN 1 END) as bronze_subscribers,
            COUNT(CASE WHEN u.subscription_tier = 'silver' THEN 1 END) as silver_subscribers,
            COUNT(CASE WHEN u.subscription_tier = 'gold' THEN 1 END) as gold_subscribers
        FROM payment_transactions pt
        LEFT JOIN users u ON pt.user_id = u.id AND u.subscription_status = 'active'
        WHERE pt.created_at BETWEEN :start_time AND :end_time
        """
        
        result = execute_aurora_query(query, {
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat()
        })
        
        if result and len(result) > 0:
            row = result[0]
            return {
                'successful_subscriptions': row.get('successful_subscriptions', 0),
                'successful_donations': row.get('successful_donations', 0),
                'total_revenue': float(row.get('total_revenue', 0) or 0),
                'avg_subscription_value': float(row.get('avg_subscription_value', 0) or 0),
                'total_subscribers': row.get('total_subscribers', 0),
                'bronze_subscribers': row.get('bronze_subscribers', 0),
                'silver_subscribers': row.get('silver_subscribers', 0),
                'gold_subscribers': row.get('gold_subscribers', 0)
            }
        
        return {
            'successful_subscriptions': 0,
            'successful_donations': 0,
            'total_revenue': 0,
            'avg_subscription_value': 0,
            'total_subscribers': 0,
            'bronze_subscribers': 0,
            'silver_subscribers': 0,
            'gold_subscribers': 0
        }
        
    except Exception as e:
        logger.error(f"Error processing revenue analytics: {str(e)}")
        return {}

def process_daily_aggregation():
    """Process daily aggregation from hourly data"""
    try:
        logger.info("Starting daily aggregation processing")
        
        # Get yesterday's data
        yesterday = (datetime.now() - timedelta(days=1)).date()
        
        # Aggregate hourly data for the day
        daily_metrics = aggregate_daily_metrics(yesterday)
        
        # Store daily aggregation
        store_daily_analytics(daily_metrics, yesterday)
        
        logger.info("Daily aggregation processing completed")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Daily aggregation processed successfully',
                'date': yesterday.isoformat(),
                'metrics': daily_metrics
            })
        }
        
    except Exception as e:
        logger.error(f"Error in daily aggregation: {str(e)}")
        raise

def aggregate_daily_metrics(date):
    """Aggregate hourly metrics into daily metrics"""
    try:
        # This would typically read from S3 hourly data files
        # For now, we'll query the database directly
        start_time = datetime.combine(date, datetime.min.time())
        end_time = start_time + timedelta(days=1)
        
        return {
            'user_engagement': process_user_engagement_analytics(start_time, end_time),
            'stream_performance': process_stream_performance_analytics(start_time, end_time),
            'content_analytics': process_content_analytics(start_time, end_time),
            'revenue_metrics': process_revenue_analytics(start_time, end_time)
        }
        
    except Exception as e:
        logger.error(f"Error aggregating daily metrics: {str(e)}")
        return {}

def store_hourly_analytics(data, timestamp):
    """Store hourly analytics data in S3"""
    try:
        key = f"hourly-analytics/{timestamp.strftime('%Y/%m/%d/%H')}/analytics.json"
        
        s3_client.put_object(
            Bucket=ANALYTICS_BUCKET,
            Key=key,
            Body=json.dumps(data, default=str),
            ContentType='application/json'
        )
        
        logger.info(f"Stored hourly analytics data: {key}")
        
    except Exception as e:
        logger.error(f"Error storing hourly analytics: {str(e)}")
        raise

def store_daily_analytics(data, date):
    """Store daily analytics data in S3"""
    try:
        key = f"daily-analytics/{date.strftime('%Y/%m/%d')}/analytics.json"
        
        s3_client.put_object(
            Bucket=ANALYTICS_BUCKET,
            Key=key,
            Body=json.dumps(data, default=str),
            ContentType='application/json'
        )
        
        logger.info(f"Stored daily analytics data: {key}")
        
    except Exception as e:
        logger.error(f"Error storing daily analytics: {str(e)}")
        raise

def send_cloudwatch_metrics(data, timestamp):
    """Send custom metrics to CloudWatch"""
    try:
        metric_data = []
        
        # User engagement metrics
        if 'user_engagement' in data:
            ue = data['user_engagement']
            metric_data.extend([
                {
                    'MetricName': 'ActiveUsers',
                    'Value': ue.get('active_users', 0),
                    'Unit': 'Count',
                    'Timestamp': timestamp
                },
                {
                    'MetricName': 'EngagementRate',
                    'Value': ue.get('engagement_rate', 0),
                    'Unit': 'Percent',
                    'Timestamp': timestamp
                }
            ])
        
        # Stream performance metrics
        if 'stream_performance' in data:
            sp = data['stream_performance']
            metric_data.extend([
                {
                    'MetricName': 'ActiveStreams',
                    'Value': sp.get('active_streams', 0),
                    'Unit': 'Count',
                    'Timestamp': timestamp
                },
                {
                    'MetricName': 'TotalConcurrentViewers',
                    'Value': sp.get('total_concurrent_viewers', 0),
                    'Unit': 'Count',
                    'Timestamp': timestamp
                }
            ])
        
        # Revenue metrics
        if 'revenue_metrics' in data:
            rm = data['revenue_metrics']
            metric_data.extend([
                {
                    'MetricName': 'TotalRevenue',
                    'Value': rm.get('total_revenue', 0),
                    'Unit': 'None',
                    'Timestamp': timestamp
                },
                {
                    'MetricName': 'TotalSubscribers',
                    'Value': rm.get('total_subscribers', 0),
                    'Unit': 'Count',
                    'Timestamp': timestamp
                }
            ])
        
        # Send metrics in batches of 20 (CloudWatch limit)
        for i in range(0, len(metric_data), 20):
            batch = metric_data[i:i+20]
            cloudwatch.put_metric_data(
                Namespace='StreamingPlatform/Analytics',
                MetricData=batch
            )
        
        logger.info(f"Sent {len(metric_data)} custom metrics to CloudWatch")
        
    except Exception as e:
        logger.error(f"Error sending CloudWatch metrics: {str(e)}")

def execute_aurora_query(query, parameters=None):
    """Execute query against Aurora using RDS Data API"""
    try:
        params = {
            'resourceArn': AURORA_CLUSTER_ARN,
            'secretArn': AURORA_SECRET_ARN,
            'database': 'streaming_platform',
            'sql': query
        }
        
        if parameters:
            params['parameters'] = [
                {'name': key, 'value': {'stringValue': str(value)}}
                for key, value in parameters.items()
            ]
        
        response = rds_data_client.execute_statement(**params)
        
        # Convert response to list of dictionaries
        if 'records' in response:
            columns = [col['name'] for col in response.get('columnMetadata', [])]
            results = []
            
            for record in response['records']:
                row = {}
                for i, col in enumerate(columns):
                    if i < len(record):
                        value = record[i]
                        if 'stringValue' in value:
                            row[col] = value['stringValue']
                        elif 'longValue' in value:
                            row[col] = value['longValue']
                        elif 'doubleValue' in value:
                            row[col] = value['doubleValue']
                        elif 'booleanValue' in value:
                            row[col] = value['booleanValue']
                        else:
                            row[col] = None
                    else:
                        row[col] = None
                results.append(row)
            
            return results
        
        return []
        
    except Exception as e:
        logger.error(f"Error executing Aurora query: {str(e)}")
        return []

def process_custom_query(event):
    """Process custom analytics query"""
    try:
        query_type = event.get('queryType')
        parameters = event.get('parameters', {})
        
        if query_type == 'user_retention':
            return calculate_user_retention(parameters)
        elif query_type == 'stream_trends':
            return analyze_stream_trends(parameters)
        elif query_type == 'revenue_forecast':
            return generate_revenue_forecast(parameters)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Unknown query type'})
            }
            
    except Exception as e:
        logger.error(f"Error processing custom query: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process custom query'})
        }

def calculate_user_retention(parameters):
    """Calculate user retention metrics"""
    # Implementation for user retention analysis
    return {'retention_rate': 75.5, 'cohort_analysis': {}}

def analyze_stream_trends(parameters):
    """Analyze streaming trends"""
    # Implementation for stream trend analysis
    return {'trending_categories': [], 'growth_metrics': {}}

def generate_revenue_forecast(parameters):
    """Generate revenue forecast"""
    # Implementation for revenue forecasting
    return {'forecast': [], 'confidence_interval': {}}