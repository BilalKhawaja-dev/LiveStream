import json
import boto3
import psycopg2
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
    db_port = int(os.environ.get('DB_PORT', 5432))
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
    
    # Read SQL initialization script from file
    script_path = '/opt/init_database.sql'
    
    # If the file doesn't exist, use embedded script
    if not os.path.exists(script_path):
        sql_script = """
-- Create ENUM types for PostgreSQL
CREATE TYPE user_role AS ENUM ('viewer', 'creator', 'admin', 'support', 'analyst', 'developer');
CREATE TYPE subscription_tier AS ENUM ('bronze', 'silver', 'gold');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired');

-- Users table for user profiles and authentication data
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    cognito_id VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    role user_role NOT NULL DEFAULT 'viewer',
    subscription_tier subscription_tier NOT NULL DEFAULT 'bronze',
    subscription_status subscription_status NOT NULL DEFAULT 'active',
    subscription_renewal_date TIMESTAMP,
    avatar_url VARCHAR(500),
    preferences JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Create indexes for users table
CREATE INDEX IF NOT EXISTS idx_users_cognito_id ON users(cognito_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- System configuration table for application settings
CREATE TABLE IF NOT EXISTS system_config (
    id VARCHAR(36) PRIMARY KEY,
    config_key VARCHAR(255) UNIQUE NOT NULL,
    config_value JSONB NOT NULL,
    description TEXT,
    category VARCHAR(100),
    is_sensitive BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default system configuration
INSERT INTO system_config (id, config_key, config_value, description, category) VALUES
(gen_random_uuid()::text, 'subscription_tiers', '{"bronze": {"quality": "720p", "price": 9.99}, "silver": {"quality": "1080p", "price": 19.99}, "gold": {"quality": "4k", "price": 39.99}}', 'Subscription tier configuration', 'billing'),
(gen_random_uuid()::text, 'streaming_settings', '{"max_concurrent_streams": 1000, "default_quality": "1080p", "enable_chat": true}', 'Default streaming settings', 'streaming')
ON CONFLICT (config_key) DO NOTHING;
"""
    else:
        with open(script_path, 'r') as f:
            sql_script = f.read()
    
    # Connect to database and execute initialization script
    connection = None
    try:
        # Connect to PostgreSQL
        connection = psycopg2.connect(
            host=db_host,
            port=db_port,
            database=db_name,
            user=db_username,
            password=db_password
        )
        
        logger.info(f"Connected to Aurora PostgreSQL database at {db_host}")
        
        # Execute SQL script
        with connection.cursor() as cursor:
            # Execute the entire script at once for PostgreSQL
            cursor.execute(sql_script)
            
            connection.commit()
            logger.info("Database initialization completed successfully")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Database initialized successfully',
                'database': db_name,
                'engine': 'PostgreSQL'
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