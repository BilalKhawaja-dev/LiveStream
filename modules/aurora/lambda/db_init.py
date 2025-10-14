import json
import boto3
import pymysql
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to initialize Aurora database with application schema
    """
    
    # Get database connection details from environment variables
    db_host = os.environ['DB_HOST']
    db_port = int(os.environ.get('DB_PORT', 3306))
    db_name = os.environ.get('DB_NAME', 'streaming_platform')
    secret_arn = os.environ['SECRET_ARN']
    
    # Get database credentials from Secrets Manager
    secrets_client = boto3.client('secretsmanager')
    
    try:
        secret_response = secrets_client.get_secret_value(SecretId=secret_arn)
        secret_data = json.loads(secret_response['SecretString'])
        db_username = secret_data['username']
        db_password = secret_data['password']
        
        logger.info(f"Retrieved database credentials from Secrets Manager")
        
    except Exception as e:
        logger.error(f"Error retrieving database credentials: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to retrieve database credentials',
                'details': str(e)
            })
        }
    
    # Read SQL initialization script
    sql_script = """
-- Database initialization script for streaming platform
-- This script creates the necessary tables and indexes for the application

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS streaming_platform;
USE streaming_platform;

-- Users table for user profiles and authentication data
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    cognito_id VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    role ENUM('viewer', 'creator', 'admin', 'support', 'analyst', 'developer') NOT NULL DEFAULT 'viewer',
    subscription_tier ENUM('bronze', 'silver', 'gold') NOT NULL DEFAULT 'bronze',
    subscription_status ENUM('active', 'cancelled', 'expired') NOT NULL DEFAULT 'active',
    subscription_renewal_date DATETIME,
    avatar_url VARCHAR(500),
    preferences JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    
    INDEX idx_cognito_id (cognito_id),
    INDEX idx_email (email),
    INDEX idx_username (username),
    INDEX idx_role (role),
    INDEX idx_subscription_tier (subscription_tier),
    INDEX idx_created_at (created_at)
);

-- Streams table for stream configuration and metadata
CREATE TABLE IF NOT EXISTS streams (
    id VARCHAR(36) PRIMARY KEY,
    creator_id VARCHAR(36) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    status ENUM('scheduled', 'live', 'ended', 'cancelled') NOT NULL DEFAULT 'scheduled',
    media_live_channel_id VARCHAR(255),
    s3_media_prefix VARCHAR(500),
    scheduled_start DATETIME,
    actual_start DATETIME,
    end_time DATETIME,
    viewer_count INT DEFAULT 0,
    max_viewers INT DEFAULT 0,
    total_views INT DEFAULT 0,
    chat_enabled BOOLEAN DEFAULT TRUE,
    recording_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_creator_id (creator_id),
    INDEX idx_status (status),
    INDEX idx_category (category),
    INDEX idx_scheduled_start (scheduled_start),
    INDEX idx_created_at (created_at)
);

-- Support tickets table for customer service
CREATE TABLE IF NOT EXISTS support_tickets (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    creator_id VARCHAR(36),
    type ENUM('technical', 'billing', 'content', 'account', 'general') NOT NULL,
    priority ENUM('low', 'medium', 'high', 'urgent') NOT NULL DEFAULT 'medium',
    status ENUM('open', 'in_progress', 'resolved', 'closed') NOT NULL DEFAULT 'open',
    subject VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    assigned_to VARCHAR(36),
    context JSON,
    ai_suggestions JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_creator_id (creator_id),
    INDEX idx_type (type),
    INDEX idx_priority (priority),
    INDEX idx_status (status),
    INDEX idx_assigned_to (assigned_to),
    INDEX idx_created_at (created_at)
);

-- System configuration table for application settings
CREATE TABLE IF NOT EXISTS system_config (
    id VARCHAR(36) PRIMARY KEY,
    config_key VARCHAR(255) UNIQUE NOT NULL,
    config_value JSON NOT NULL,
    description TEXT,
    category VARCHAR(100),
    is_sensitive BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_config_key (config_key),
    INDEX idx_category (category)
);

-- Insert default system configuration
INSERT IGNORE INTO system_config (id, config_key, config_value, description, category) VALUES
(UUID(), 'subscription_tiers', '{"bronze": {"quality": "720p", "price": 9.99}, "silver": {"quality": "1080p", "price": 19.99}, "gold": {"quality": "4k", "price": 39.99}}', 'Subscription tier configuration', 'billing'),
(UUID(), 'streaming_settings', '{"max_concurrent_streams": 1000, "default_quality": "1080p", "enable_chat": true}', 'Default streaming settings', 'streaming'),
(UUID(), 'ai_moderation', '{"rekognition_confidence_threshold": 0.8, "comprehend_confidence_threshold": 0.7, "auto_approve_threshold": 0.9}', 'AI moderation thresholds', 'moderation'),
(UUID(), 'support_settings', '{"auto_assign_tickets": true, "escalation_timeout_hours": 24, "ai_suggestions_enabled": true}', 'Support system configuration', 'support');
"""
    
    # Connect to database and execute initialization script
    connection = None
    try:
        # Connect to MySQL
        connection = pymysql.connect(
            host=db_host,
            port=db_port,
            user=db_username,
            password=db_password,
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=False
        )
        
        logger.info(f"Connected to Aurora database at {db_host}")
        
        # Execute SQL script
        with connection.cursor() as cursor:
            # Split script into individual statements and execute
            statements = [stmt.strip() for stmt in sql_script.split(';') if stmt.strip()]
            
            for statement in statements:
                if statement:
                    logger.info(f"Executing: {statement[:100]}...")
                    cursor.execute(statement)
            
            connection.commit()
            logger.info("Database initialization completed successfully")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Database initialized successfully',
                'tables_created': [
                    'users', 'streams', 'support_tickets', 'system_config'
                ]
            })
        }
        
    except Exception as e:
        logger.error(f"Error initializing database: {str(e)}")
        if connection:
            connection.rollback()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Database initialization failed',
                'details': str(e)
            })
        }
        
    finally:
        if connection:
            connection.close()
            logger.info("Database connection closed")