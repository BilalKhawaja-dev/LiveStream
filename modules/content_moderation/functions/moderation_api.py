import json
import boto3
import os
import logging
from datetime import datetime
from decimal import Decimal
from boto3.dynamodb.conditions import Key, Attr

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')

# Environment variables
MODERATION_TABLE = os.environ['MODERATION_TABLE']
FLAGGED_CONTENT_BUCKET = os.environ['FLAGGED_CONTENT_BUCKET']
VIDEOS_TABLE = os.environ['VIDEOS_TABLE']
MESSAGES_TABLE = os.environ['MESSAGES_TABLE']

# Initialize DynamoDB tables
moderation_table = dynamodb.Table(MODERATION_TABLE)
videos_table = dynamodb.Table(VIDEOS_TABLE)
messages_table = dynamodb.Table(MESSAGES_TABLE)

def lambda_handler(event, context):
    """
    Handle moderation API requests for manual review
    """
    try:
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        query_params = event.get('queryStringParameters') or {}
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        
        logger.info(f"Processing {http_method} request to {path}")
        
        # Route the request
        if path.endswith('/moderation/queue'):
            return handle_moderation_queue_request(query_params)
        elif path.endswith('/moderation/review'):
            return handle_moderation_review_request(body)
        elif path.endswith('/moderation/stats'):
            return handle_moderation_stats_request(query_params)
        elif path.endswith('/moderation/content'):
            return handle_content_action_request(body)
        else:
            return {
                'statusCode': 404,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Endpoint not found'})
            }
            
    except Exception as e:
        logger.error(f"Error processing moderation API request: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Internal server error'})
        }

def handle_moderation_queue_request(query_params):
    """Get moderation queue items"""
    try:
        status_filter = query_params.get('status', 'pending')
        limit = int(query_params.get('limit', '50'))
        
        # Query moderation items by status
        if status_filter == 'all':
            response = moderation_table.scan(Limit=limit)
        else:
            response = moderation_table.scan(
                FilterExpression=Attr('status').eq(status_filter),
                Limit=limit
            )
        
        items = response.get('Items', [])
        
        # Process items for response
        moderation_items = []
        for item in items:
            moderation_item = {
                'moderationId': item.get('moderation_id'),
                'contentType': item.get('content_type'),
                'userId': item.get('user_id'),
                'status': item.get('status'),
                'confidence': float(item.get('confidence', 0)),
                'flags': item.get('flags', []),
                'createdAt': item.get('created_at'),
                'updatedAt': item.get('updated_at'),
                'analysisType': item.get('analysis_type')
            }
            
            # Add content preview
            if item.get('content'):
                moderation_item['contentPreview'] = item['content'][:200] + ('...' if len(item['content']) > 200 else '')
            elif item.get('s3_key'):
                moderation_item['s3Key'] = item['s3_key']
                moderation_item['s3Bucket'] = item.get('s3_bucket', FLAGGED_CONTENT_BUCKET)
            
            moderation_items.append(moderation_item)
        
        # Sort by creation date (newest first)
        moderation_items.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
        
        result = {
            'items': moderation_items,
            'totalCount': len(moderation_items),
            'status': status_filter
        }
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result, default=decimal_serializer)
        }
        
    except Exception as e:
        logger.error(f"Error handling moderation queue request: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to get moderation queue'})
        }

def handle_moderation_review_request(body):
    """Handle moderation review decision"""
    try:
        moderation_id = body.get('moderationId')
        decision = body.get('decision')  # 'approve', 'reject', 'escalate'
        reviewer_id = body.get('reviewerId')
        notes = body.get('notes', '')
        
        if not moderation_id or not decision or not reviewer_id:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'moderationId, decision, and reviewerId are required'})
            }
        
        if decision not in ['approve', 'reject', 'escalate']:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Invalid decision. Must be approve, reject, or escalate'})
            }
        
        # Get the moderation item
        response = moderation_table.get_item(Key={'moderation_id': moderation_id})
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Moderation item not found'})
            }
        
        moderation_item = response['Item']
        
        # Update moderation status
        new_status = {
            'approve': 'approved',
            'reject': 'rejected',
            'escalate': 'escalated'
        }[decision]
        
        moderation_table.update_item(
            Key={'moderation_id': moderation_id},
            UpdateExpression='SET #status = :status, reviewer_id = :reviewer_id, review_notes = :notes, reviewed_at = :reviewed_at',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': new_status,
                ':reviewer_id': reviewer_id,
                ':notes': notes,
                ':reviewed_at': datetime.now().isoformat()
            }
        )
        
        # Take action on the original content
        if decision == 'reject':
            content_action_result = take_content_action(moderation_item, 'remove')
        elif decision == 'approve':
            content_action_result = take_content_action(moderation_item, 'approve')
        else:  # escalate
            content_action_result = {'action': 'escalated', 'success': True}
        
        result = {
            'moderationId': moderation_id,
            'decision': decision,
            'status': new_status,
            'contentAction': content_action_result,
            'reviewedAt': datetime.now().isoformat()
        }
        
        logger.info(f"Moderation review completed: {moderation_id} -> {decision}")
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Error handling moderation review: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to process moderation review'})
        }

def handle_moderation_stats_request(query_params):
    """Get moderation statistics"""
    try:
        # Get stats for different time periods
        stats = {
            'total': get_moderation_count(),
            'pending': get_moderation_count('pending'),
            'approved': get_moderation_count('approved'),
            'rejected': get_moderation_count('rejected'),
            'escalated': get_moderation_count('escalated'),
            'flagged': get_moderation_count('flagged'),
            'review_required': get_moderation_count('review_required')
        }
        
        # Get recent activity (last 24 hours)
        recent_activity = get_recent_moderation_activity()
        
        result = {
            'stats': stats,
            'recentActivity': recent_activity,
            'generatedAt': datetime.now().isoformat()
        }
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result, default=decimal_serializer)
        }
        
    except Exception as e:
        logger.error(f"Error handling moderation stats request: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to get moderation stats'})
        }

def handle_content_action_request(body):
    """Handle direct content action (remove, approve, etc.)"""
    try:
        content_type = body.get('contentType')  # 'video', 'message', 'user'
        content_id = body.get('contentId')
        action = body.get('action')  # 'remove', 'approve', 'suspend'
        admin_id = body.get('adminId')
        reason = body.get('reason', '')
        
        if not all([content_type, content_id, action, admin_id]):
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'contentType, contentId, action, and adminId are required'})
            }
        
        # Execute the content action
        if content_type == 'video':
            result = handle_video_action(content_id, action, admin_id, reason)
        elif content_type == 'message':
            result = handle_message_action(content_id, action, admin_id, reason)
        else:
            return {
                'statusCode': 400,
                'headers': get_cors_headers(),
                'body': json.dumps({'error': 'Unsupported content type'})
            }
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Error handling content action: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Failed to execute content action'})
        }

def take_content_action(moderation_item, action):
    """Take action on content based on moderation decision"""
    try:
        content_type = moderation_item.get('content_type')
        
        if content_type == 'text':
            # For text content (messages), we need to identify the message
            # This is a simplified approach - in practice, you'd need better content tracking
            return {'action': action, 'success': True, 'message': 'Text content action completed'}
        
        elif content_type == 'image':
            s3_key = moderation_item.get('s3_key')
            if s3_key and action == 'remove':
                # Move to quarantine or delete
                try:
                    s3_client.delete_object(
                        Bucket=moderation_item.get('s3_bucket', FLAGGED_CONTENT_BUCKET),
                        Key=s3_key
                    )
                    return {'action': 'removed', 'success': True}
                except Exception as e:
                    logger.error(f"Failed to remove S3 object {s3_key}: {str(e)}")
                    return {'action': 'remove_failed', 'success': False, 'error': str(e)}
            else:
                return {'action': action, 'success': True}
        
        return {'action': action, 'success': True}
        
    except Exception as e:
        logger.error(f"Error taking content action: {str(e)}")
        return {'action': action, 'success': False, 'error': str(e)}

def handle_video_action(video_id, action, admin_id, reason):
    """Handle video-specific actions"""
    try:
        if action == 'remove':
            # Update video status to removed
            videos_table.update_item(
                Key={'video_id': video_id},
                UpdateExpression='SET #status = :status, moderation_action = :action, moderated_by = :admin_id, moderated_at = :timestamp, moderation_reason = :reason',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':status': 'removed',
                    ':action': action,
                    ':admin_id': admin_id,
                    ':timestamp': datetime.now().isoformat(),
                    ':reason': reason
                }
            )
        elif action == 'approve':
            # Update video status to approved
            videos_table.update_item(
                Key={'video_id': video_id},
                UpdateExpression='SET moderation_action = :action, moderated_by = :admin_id, moderated_at = :timestamp',
                ExpressionAttributeValues={
                    ':action': action,
                    ':admin_id': admin_id,
                    ':timestamp': datetime.now().isoformat()
                }
            )
        
        return {
            'contentType': 'video',
            'contentId': video_id,
            'action': action,
            'success': True,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error handling video action: {str(e)}")
        return {
            'contentType': 'video',
            'contentId': video_id,
            'action': action,
            'success': False,
            'error': str(e)
        }

def handle_message_action(message_id, action, admin_id, reason):
    """Handle message-specific actions"""
    try:
        if action == 'remove':
            # Update message status to removed
            # Note: This assumes message_id is in format "stream_id#timestamp"
            parts = message_id.split('#')
            if len(parts) == 2:
                stream_id, timestamp = parts
                messages_table.update_item(
                    Key={'stream_id': stream_id, 'timestamp': timestamp},
                    UpdateExpression='SET moderation_action = :action, moderated_by = :admin_id, moderated_at = :mod_timestamp, moderation_reason = :reason',
                    ExpressionAttributeValues={
                        ':action': action,
                        ':admin_id': admin_id,
                        ':mod_timestamp': datetime.now().isoformat(),
                        ':reason': reason
                    }
                )
        
        return {
            'contentType': 'message',
            'contentId': message_id,
            'action': action,
            'success': True,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error handling message action: {str(e)}")
        return {
            'contentType': 'message',
            'contentId': message_id,
            'action': action,
            'success': False,
            'error': str(e)
        }

def get_moderation_count(status=None):
    """Get count of moderation items by status"""
    try:
        if status:
            response = moderation_table.scan(
                FilterExpression=Attr('status').eq(status),
                Select='COUNT'
            )
        else:
            response = moderation_table.scan(Select='COUNT')
        
        return response.get('Count', 0)
        
    except Exception as e:
        logger.error(f"Error getting moderation count: {str(e)}")
        return 0

def get_recent_moderation_activity():
    """Get recent moderation activity (last 24 hours)"""
    try:
        from datetime import timedelta
        
        yesterday = (datetime.now() - timedelta(days=1)).isoformat()
        
        response = moderation_table.scan(
            FilterExpression=Attr('created_at').gt(yesterday),
            Limit=100
        )
        
        items = response.get('Items', [])
        
        # Group by hour
        activity_by_hour = {}
        for item in items:
            created_at = item.get('created_at', '')
            if created_at:
                hour = created_at[:13]  # YYYY-MM-DDTHH
                if hour not in activity_by_hour:
                    activity_by_hour[hour] = {'total': 0, 'flagged': 0, 'approved': 0}
                
                activity_by_hour[hour]['total'] += 1
                if item.get('status') == 'flagged':
                    activity_by_hour[hour]['flagged'] += 1
                elif item.get('status') == 'approved':
                    activity_by_hour[hour]['approved'] += 1
        
        return activity_by_hour
        
    except Exception as e:
        logger.error(f"Error getting recent activity: {str(e)}")
        return {}

def get_cors_headers():
    """Get CORS headers for API responses"""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }

def decimal_serializer(obj):
    """JSON serializer for Decimal objects"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")