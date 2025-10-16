import json
import boto3
import os
from datetime import datetime, timedelta
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.client('dynamodb')
cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns')

def handler(event, context):
    """
    Validate DynamoDB backup status and send alerts if issues are found
    """
    table_names = json.loads(os.environ['TABLE_NAMES'])
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    environment = os.environ['ENVIRONMENT']
    project_name = os.environ['PROJECT_NAME']
    
    backup_issues = []
    
    for table_name in table_names:
        try:
            # Check point-in-time recovery status
            response = dynamodb.describe_continuous_backups(TableName=table_name)
            pitr_status = response['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['PointInTimeRecoveryStatus']
            
            if pitr_status != 'ENABLED':
                backup_issues.append(f"Point-in-time recovery is {pitr_status} for table {table_name}")
                continue
            
            # Check backup lag
            earliest_restorable_time = response['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['EarliestRestorableDateTime']
            latest_restorable_time = response['ContinuousBackupsDescription']['PointInTimeRecoveryDescription']['LatestRestorableDateTime']
            
            current_time = datetime.now(latest_restorable_time.tzinfo)
            backup_lag = (current_time - latest_restorable_time).total_seconds()
            
            # Send custom metric for backup lag
            cloudwatch.put_metric_data(
                Namespace='DynamoDB/BackupMonitoring',
                MetricData=[
                    {
                        'MetricName': 'BackupLagSeconds',
                        'Dimensions': [
                            {
                                'Name': 'TableName',
                                'Value': table_name
                            },
                            {
                                'Name': 'Environment',
                                'Value': environment
                            }
                        ],
                        'Value': backup_lag,
                        'Unit': 'Seconds',
                        'Timestamp': current_time
                    }
                ]
            )
            
            # Alert if backup lag is too high (more than 5 minutes)
            if backup_lag > 300:
                backup_issues.append(f"High backup lag ({backup_lag:.0f} seconds) for table {table_name}")
            
            # Check retention period
            retention_hours = (current_time - earliest_restorable_time).total_seconds() / 3600
            expected_retention_hours = 7 * 24  # 7 days for development
            
            if retention_hours < expected_retention_hours * 0.9:  # Allow 10% variance
                backup_issues.append(f"Backup retention period is shorter than expected for table {table_name}: {retention_hours:.1f} hours")
            
            logger.info(f"Backup validation successful for table {table_name}")
            
        except Exception as e:
            backup_issues.append(f"Error validating backups for table {table_name}: {str(e)}")
            logger.error(f"Error validating backups for table {table_name}: {str(e)}")
    
    # Send alert if there are any issues
    if backup_issues:
        message = f"DynamoDB Backup Issues Detected in {environment} environment:\\n\\n"
        message += "\\n".join(f"- {issue}" for issue in backup_issues)
        
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject=f"DynamoDB Backup Issues - {project_name} {environment}",
            Message=message
        )
        
        logger.warning(f"Backup issues found: {backup_issues}")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'issues_found',
                'issues': backup_issues
            })
        }
    
    logger.info("All backup validations passed")
    return {
        'statusCode': 200,
        'body': json.dumps({
            'status': 'success',
            'message': 'All backup validations passed'
        })
    }
