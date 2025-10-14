import json
import boto3
import os
import logging
import uuid
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
rds_client = boto3.client('rds-data')
dynamodb = boto3.resource('dynamodb')
athena_client = boto3.client('athena')
s3_client = boto3.client('s3')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Analytics handler for streaming platform
    Handles real-time analytics, historical reports, and data aggregation
    """
    
    try:
        # Parse the request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        query_params = event.get('queryStringParameters') or {}
        
        logger.info(f"Processing {http_method} request to {path}")
        
        # Route to appropriate handler
        if path.endswith('/users') and http_method == 'GET':
            return handle_user_analytics(query_params)
        elif path.endswith('/streams') and http_method == 'GET':
            return handle_stream_analytics(query_params)
        elif path.endswith('/revenue') and http_method == 'GET':
            return handle_revenue_analytics(query_params)
        elif path.endswith('/reports') and http_method == 'POST':
            return handle_generate_report(body)
        elif path.endswith('/reports') and http_method == 'GET':
            return handle_list_reports(query_params)
        elif '/reports/' in path and http_method == 'GET':
            report_id = path.split('/reports/')[-1]
            return handle_get_report(report_id)
        elif path.endswith('/dashboard') and http_method == 'GET':
            return handle_dashboard_data(query_params)
        elif path.endswith('/metrics/record') and http_method == 'POST':
            return handle_record_metrics(body)
        else:
            return create_response(400, {'error': 'Invalid endpoint or method'})
            
    except Exception as e:
        logger.error(f"Analytics handler error: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_user_analytics(query_params: Dict[str, Any]) -> Dict[str, Any]:
    """Get user analytics and engagement metrics"""
    
    try:
        user_id = query_params.get('user_id')
        start_date = query_params.get('start_date')
        end_date = query_params.get('end_date')
        metric_type = query_params.get('metric_type', 'all')
        
        # Default to last 30 days if no date range provided
        if not start_date:
            start_date = (datetime.utcnow() - timedelta(days=30)).isoformat()
        if not end_date:
            end_date = datetime.utcnow().isoformat()
        
        analytics_data = {}
        
        # Get user engagement metrics
        if metric_type in ['all', 'engagement']:
            engagement_metrics = get_user_engagement_metrics(user_id, start_date, end_date)
            analytics_data['engagement'] = engagement_metrics
        
        # Get subscription analytics
        if metric_type in ['all', 'subscription']:
            subscription_metrics = get_subscription_analytics(user_id, start_date, end_date)
            analytics_data['subscription'] = subscription_metrics
        
        # Get viewing analytics
        if metric_type in ['all', 'viewing']:
            viewing_metrics = get_viewing_analytics(user_id, start_date, end_date)
            analytics_data['viewing'] = viewing_metrics
        
        # Get creator analytics if user is a creator
        if metric_type in ['all', 'creator']:
            creator_metrics = get_creator_analytics(user_id, start_date, end_date)
            if creator_metrics:
                analytics_data['creator'] = creator_metrics
        
        return create_response(200, {
            'user_id': user_id,
            'date_range': {
                'start_date': start_date,
                'end_date': end_date
            },
            'analytics': analytics_data,
            'generated_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"User analytics error: {str(e)}")
        return create_response(500, {'error': 'Failed to get user analytics'})

def handle_stream_analytics(query_params: Dict[str, Any]) -> Dict[str, Any]:
    """Get stream analytics and performance metrics"""
    
    try:
        stream_id = query_params.get('stream_id')
        creator_id = query_params.get('creator_id')
        start_date = query_params.get('start_date')
        end_date = query_params.get('end_date')
        
        if not stream_id and not creator_id:
            return create_response(400, {'error': 'Stream ID or Creator ID required'})
        
        # Default to last 30 days if no date range provided
        if not start_date:
            start_date = (datetime.utcnow() - timedelta(days=30)).isoformat()
        if not end_date:
            end_date = datetime.utcnow().isoformat()
        
        if stream_id:
            # Get analytics for specific stream
            analytics_data = get_stream_specific_analytics(stream_id, start_date, end_date)
        else:
            # Get analytics for all streams by creator
            analytics_data = get_creator_stream_analytics(creator_id, start_date, end_date)
        
        return create_response(200, {
            'stream_id': stream_id,
            'creator_id': creator_id,
            'date_range': {
                'start_date': start_date,
                'end_date': end_date
            },
            'analytics': analytics_data,
            'generated_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Stream analytics error: {str(e)}")
        return create_response(500, {'error': 'Failed to get stream analytics'})

def handle_revenue_analytics(query_params: Dict[str, Any]) -> Dict[str, Any]:
    """Get revenue analytics and financial metrics"""
    
    try:
        creator_id = query_params.get('creator_id')
        start_date = query_params.get('start_date')
        end_date = query_params.get('end_date')
        breakdown = query_params.get('breakdown', 'monthly')  # daily, weekly, monthly
        
        # Default to last 12 months if no date range provided
        if not start_date:
            start_date = (datetime.utcnow() - timedelta(days=365)).isoformat()
        if not end_date:
            end_date = datetime.utcnow().isoformat()
        
        # Get revenue data from database
        sql = """
        SELECT 
            DATE_FORMAT(created_at, CASE 
                WHEN :breakdown = 'daily' THEN '%Y-%m-%d'
                WHEN :breakdown = 'weekly' THEN '%Y-%u'
                ELSE '%Y-%m'
            END) as period,
            type,
            SUM(amount) as total_amount,
            COUNT(*) as transaction_count
        FROM payment_transactions 
        WHERE created_at BETWEEN :start_date AND :end_date
        AND status = 'succeeded'
        """
        
        parameters = [
            {'name': 'breakdown', 'value': {'stringValue': breakdown}},
            {'name': 'start_date', 'value': {'stringValue': start_date}},
            {'name': 'end_date', 'value': {'stringValue': end_date}}
        ]
        
        if creator_id:
            sql += " AND user_id = :creator_id"
            parameters.append({'name': 'creator_id', 'value': {'stringValue': creator_id}})
        
        sql += " GROUP BY period, type ORDER BY period DESC"
        
        result = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        # Process revenue data
        revenue_data = {}
        total_revenue = 0
        
        for record in result['records']:
            period = record[0]['stringValue']
            transaction_type = record[1]['stringValue']
            amount = record[2]['doubleValue']
            count = record[3]['longValue']
            
            if period not in revenue_data:
                revenue_data[period] = {}
            
            revenue_data[period][transaction_type] = {
                'amount': amount,
                'count': count
            }
            total_revenue += amount
        
        # Get subscription metrics
        subscription_metrics = get_subscription_revenue_metrics(creator_id, start_date, end_date)
        
        return create_response(200, {
            'creator_id': creator_id,
            'date_range': {
                'start_date': start_date,
                'end_date': end_date
            },
            'breakdown': breakdown,
            'total_revenue': total_revenue,
            'revenue_by_period': revenue_data,
            'subscription_metrics': subscription_metrics,
            'generated_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Revenue analytics error: {str(e)}")
        return create_response(500, {'error': 'Failed to get revenue analytics'})

def handle_generate_report(body: Dict[str, Any]) -> Dict[str, Any]:
    """Generate custom analytics report using Athena"""
    
    try:
        report_type = body.get('report_type')
        parameters = body.get('parameters', {})
        user_id = body.get('user_id')
        
        if not report_type or not user_id:
            return create_response(400, {'error': 'Report type and user ID required'})
        
        # Generate report based on type
        report_id = str(uuid.uuid4())
        
        if report_type == 'user_engagement':
            query = generate_user_engagement_query(parameters)
        elif report_type == 'stream_performance':
            query = generate_stream_performance_query(parameters)
        elif report_type == 'revenue_analysis':
            query = generate_revenue_analysis_query(parameters)
        elif report_type == 'platform_overview':
            query = generate_platform_overview_query(parameters)
        else:
            return create_response(400, {'error': 'Invalid report type'})
        
        # Execute Athena query
        query_execution_id = execute_athena_query(query, report_id)
        
        # Store report metadata
        store_report_metadata(report_id, report_type, user_id, parameters, query_execution_id)
        
        return create_response(202, {
            'report_id': report_id,
            'status': 'generating',
            'query_execution_id': query_execution_id,
            'estimated_completion': (datetime.utcnow() + timedelta(minutes=5)).isoformat()
        })
        
    except Exception as e:
        logger.error(f"Generate report error: {str(e)}")
        return create_response(500, {'error': 'Failed to generate report'})

def get_user_engagement_metrics(user_id: Optional[str], start_date: str, end_date: str) -> Dict[str, Any]:
    """Get user engagement metrics from DynamoDB and Aurora"""
    
    try:
        # Get real-time engagement data from DynamoDB
        analytics_table = dynamodb.Table(os.environ['DYNAMODB_ANALYTICS_TABLE'])
        
        engagement_data = {
            'total_sessions': 0,
            'average_session_duration': 0,
            'streams_watched': 0,
            'chat_messages_sent': 0,
            'subscription_changes': 0
        }
        
        # Query DynamoDB for user engagement data
        if user_id:
            response = analytics_table.query(
                KeyConditionExpression='user_id = :user_id AND #timestamp BETWEEN :start_date AND :end_date',
                ExpressionAttributeNames={'#timestamp': 'timestamp'},
                ExpressionAttributeValues={
                    ':user_id': user_id,
                    ':start_date': start_date,
                    ':end_date': end_date
                }
            )
            
            # Process engagement data
            for item in response['Items']:
                metric_type = item.get('metric_type')
                value = item.get('value', 0)
                
                if metric_type == 'session_duration':
                    engagement_data['total_sessions'] += 1
                    engagement_data['average_session_duration'] += value
                elif metric_type == 'stream_view':
                    engagement_data['streams_watched'] += 1
                elif metric_type == 'chat_message':
                    engagement_data['chat_messages_sent'] += value
        
        # Calculate averages
        if engagement_data['total_sessions'] > 0:
            engagement_data['average_session_duration'] /= engagement_data['total_sessions']
        
        return engagement_data
        
    except Exception as e:
        logger.error(f"Get user engagement metrics error: {str(e)}")
        return {}

def get_stream_specific_analytics(stream_id: str, start_date: str, end_date: str) -> Dict[str, Any]:
    """Get analytics for a specific stream"""
    
    try:
        # Get stream data from Aurora
        sql = """
        SELECT s.*, 
               COUNT(DISTINCT sa.id) as analytics_records,
               AVG(sa.metric_value) as avg_metric_value
        FROM streams s
        LEFT JOIN stream_analytics sa ON s.id = sa.stream_id
        WHERE s.id = :stream_id
        AND (sa.recorded_at IS NULL OR sa.recorded_at BETWEEN :start_date AND :end_date)
        GROUP BY s.id
        """
        
        parameters = [
            {'name': 'stream_id', 'value': {'stringValue': stream_id}},
            {'name': 'start_date', 'value': {'stringValue': start_date}},
            {'name': 'end_date', 'value': {'stringValue': end_date}}
        ]
        
        result = rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        if not result['records']:
            return {}
        
        record = result['records'][0]
        
        analytics_data = {
            'stream_id': stream_id,
            'title': record[2]['stringValue'],
            'status': record[5]['stringValue'],
            'total_views': record[10].get('longValue', 0),
            'max_viewers': record[9].get('longValue', 0),
            'current_viewers': record[8].get('longValue', 0),
            'analytics_records': record[-2].get('longValue', 0),
            'average_engagement': record[-1].get('doubleValue', 0)
        }
        
        return analytics_data
        
    except Exception as e:
        logger.error(f"Get stream analytics error: {str(e)}")
        return {}

def execute_athena_query(query: str, report_id: str) -> str:
    """Execute Athena query for report generation"""
    
    try:
        response = athena_client.start_query_execution(
            QueryString=query,
            QueryExecutionContext={
                'Database': os.environ['ATHENA_DATABASE']
            },
            ResultConfiguration={
                'OutputLocation': f"s3://{os.environ['S3_RESULTS_BUCKET']}/reports/{report_id}/"
            },
            WorkGroup=os.environ['ATHENA_WORKGROUP']
        )
        
        return response['QueryExecutionId']
        
    except Exception as e:
        logger.error(f"Execute Athena query error: {str(e)}")
        raise

def generate_user_engagement_query(parameters: Dict[str, Any]) -> str:
    """Generate Athena query for user engagement report"""
    
    start_date = parameters.get('start_date', (datetime.utcnow() - timedelta(days=30)).strftime('%Y-%m-%d'))
    end_date = parameters.get('end_date', datetime.utcnow().strftime('%Y-%m-%d'))
    
    query = f"""
    SELECT 
        u.role,
        u.subscription_tier,
        COUNT(DISTINCT u.id) as user_count,
        AVG(CASE WHEN s.total_views > 0 THEN s.total_views ELSE 0 END) as avg_views_per_user,
        COUNT(DISTINCT s.id) as total_streams,
        SUM(s.total_views) as total_platform_views
    FROM users u
    LEFT JOIN streams s ON u.id = s.creator_id
    WHERE u.created_at BETWEEN '{start_date}' AND '{end_date}'
    GROUP BY u.role, u.subscription_tier
    ORDER BY user_count DESC
    """
    
    return query

def store_report_metadata(report_id: str, report_type: str, user_id: str, 
                         parameters: Dict[str, Any], query_execution_id: str) -> None:
    """Store report metadata in DynamoDB"""
    
    try:
        analytics_table = dynamodb.Table(os.environ['DYNAMODB_ANALYTICS_TABLE'])
        
        analytics_table.put_item(
            Item={
                'report_id': report_id,
                'report_type': report_type,
                'user_id': user_id,
                'parameters': parameters,
                'query_execution_id': query_execution_id,
                'status': 'generating',
                'created_at': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow() + timedelta(days=90)).timestamp())
            }
        )
        
    except Exception as e:
        logger.error(f"Store report metadata error: {str(e)}")

def handle_record_metrics(body: Dict[str, Any]) -> Dict[str, Any]:
    """Record real-time metrics in DynamoDB"""
    
    try:
        user_id = body.get('user_id')
        metric_type = body.get('metric_type')
        value = body.get('value', 1)
        metadata = body.get('metadata', {})
        
        if not user_id or not metric_type:
            return create_response(400, {'error': 'User ID and metric type required'})
        
        # Store metric in DynamoDB
        analytics_table = dynamodb.Table(os.environ['DYNAMODB_ANALYTICS_TABLE'])
        
        metric_id = str(uuid.uuid4())
        
        analytics_table.put_item(
            Item={
                'metric_id': metric_id,
                'user_id': user_id,
                'metric_type': metric_type,
                'value': value,
                'metadata': metadata,
                'timestamp': datetime.utcnow().isoformat(),
                'ttl': int((datetime.utcnow() + timedelta(days=30)).timestamp())
            }
        )
        
        return create_response(200, {
            'metric_id': metric_id,
            'recorded_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Record metrics error: {str(e)}")
        return create_response(500, {'error': 'Failed to record metrics'})

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create standardized API response"""
    
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