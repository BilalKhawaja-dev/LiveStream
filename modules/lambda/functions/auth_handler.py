import json
import boto3
import hashlib
import hmac
import base64
import os
import uuid
from datetime import datetime, timedelta
import logging
from typing import Dict, Any, Optional, List

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
cognito_client = boto3.client('cognito-idp')
rds_client = boto3.client('rds-data')
secrets_client = boto3.client('secretsmanager')

# Helper functions
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

def handle_database_errors(func):
    """Decorator for database operations with comprehensive error handling"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            logger.error(f"Database operation error in {func.__name__}: {str(e)}")
            return create_response(500, {'error': 'Database operation failed'})
    return wrapper

def lambda_handler(event, context):
    """
    Handle authentication requests
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
        if path == '/auth' and http_method == 'GET':
            return handle_auth_info()
        elif path == '/auth/register' and http_method == 'POST':
            return handle_register(body)
        elif path == '/auth/login' and http_method == 'POST':
            return handle_login(body)
        elif path == '/auth/refresh' and http_method == 'POST':
            return handle_refresh(body)
        elif path == '/auth/logout' and http_method == 'POST':
            return handle_logout(body)
        elif path == '/auth/verify' and http_method == 'POST':
            return handle_verify(body)
        elif path == '/users' and http_method == 'GET':
            return handle_get_users()
        elif path == '/users/profile' and http_method == 'GET':
            return handle_get_profile(event.get('headers', {}))
        elif path == '/users/preferences' and http_method == 'GET':
            return handle_get_preferences(event.get('headers', {}))
        elif path == '/users/subscription' and http_method == 'GET':
            return handle_get_subscription(event.get('headers', {}))
        elif path == '/users/subscription' and http_method == 'PUT':
            return handle_update_subscription(body)
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

@handle_database_errors
def handle_register(body):
    """Handle user registration with Aurora database integration"""
    try:
        email = body.get('email')
        password = body.get('password')
        username = body.get('username')
        display_name = body.get('display_name', username)
        role = body.get('role', 'viewer')
        
        if not all([email, password, username]):
            return create_response(400, {'error': 'Missing required fields'})
        
        user_pool_id = os.environ.get('COGNITO_USER_POOL_ID')
        client_id = os.environ.get('COGNITO_CLIENT_ID')
        
        if not user_pool_id or not client_id:
            logger.error("Missing Cognito configuration")
            return create_response(500, {'error': 'Authentication service not configured'})
        
        # Generate unique user ID
        user_id = str(uuid.uuid4())
        
        # Sanitize username for Cognito (only alphanumeric and some special chars)
        import re
        sanitized_username = re.sub(r'[^a-zA-Z0-9._-]', '', username)
        if not sanitized_username:
            sanitized_username = f"user_{user_id[:8]}"
        
        # Create user in Cognito (use email as username since that's how the pool is configured)
        cognito_response = cognito_client.admin_create_user(
            UserPoolId=user_pool_id,
            Username=email,  # Use email as username
            UserAttributes=[
                {'Name': 'email', 'Value': email},
                {'Name': 'email_verified', 'Value': 'true'}
            ],
            TemporaryPassword=password,
            MessageAction='SUPPRESS'
        )
        
        # Set permanent password
        cognito_client.admin_set_user_password(
            UserPoolId=user_pool_id,
            Username=email,  # Use email as username
            Password=password,
            Permanent=True
        )
        
        # Get Cognito user ID
        cognito_id = cognito_response['User']['Username']
        
        # Create user profile in Aurora database
        sql = """
        INSERT INTO users (
            id, cognito_id, email, username, display_name, role, 
            subscription_tier, subscription_status, preferences, created_at, updated_at
        ) VALUES (
            :user_id, :cognito_id, :email, :username, :display_name, :role,
            'bronze', 'active', :preferences, NOW(), NOW()
        )
        """
        
        default_preferences = {
            'theme': 'light',
            'language': 'en',
            'notifications': {
                'email': True,
                'push': False,
                'sms': False
            },
            'privacy': {
                'profileVisibility': 'public',
                'showActivity': True
            },
            'streaming': {
                'defaultQuality': 'auto',
                'autoPlay': True,
                'chatEnabled': True
            }
        }
        
        parameters = [
            {'name': 'user_id', 'value': {'stringValue': user_id}},
            {'name': 'cognito_id', 'value': {'stringValue': cognito_id}},
            {'name': 'email', 'value': {'stringValue': email}},
            {'name': 'username', 'value': {'stringValue': username}},
            {'name': 'display_name', 'value': {'stringValue': display_name}},
            {'name': 'role', 'value': {'stringValue': role}},
            {'name': 'preferences', 'value': {'stringValue': json.dumps(default_preferences)}}
        ]
        
        execute_sql(sql, parameters)
        
        logger.info(f"User registered successfully: {username} ({user_id})")
        
        return create_response(201, {
            'message': 'User registered successfully',
            'user_id': user_id,
            'username': username,
            'email': email,
            'role': role,
            'subscription_tier': 'bronze'
        })
        
    except cognito_client.exceptions.UsernameExistsException:
        return create_response(409, {'error': 'Username already exists'})
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        return create_response(500, {'error': 'Registration failed'})

@handle_database_errors
def handle_login(body):
    """Handle user login with database profile loading"""
    try:
        # Accept both username and email for login
        username = body.get('username') or body.get('email')
        password = body.get('password')
        
        if not username or not password:
            return create_response(400, {'error': 'Username/email and password required'})
        
        client_id = os.environ.get('COGNITO_CLIENT_ID')
        client_secret = os.environ.get('COGNITO_CLIENT_SECRET')
        
        if not client_id:
            return create_response(500, {'error': 'Authentication service not configured'})
        
        # Prepare auth parameters
        auth_params = {
            'USERNAME': username,
            'PASSWORD': password
        }
        
        # Add SECRET_HASH if client secret is configured
        if client_secret:
            secret_hash = calculate_secret_hash(username, client_id, client_secret)
            auth_params['SECRET_HASH'] = secret_hash
        
        # Authenticate with Cognito
        cognito_response = cognito_client.initiate_auth(
            ClientId=client_id,
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters=auth_params
        )
        
        # Get user details from Cognito
        access_token = cognito_response['AuthenticationResult']['AccessToken']
        user_details = cognito_client.get_user(AccessToken=access_token)
        
        # Extract user attributes
        user_attributes = {}
        for attr in user_details['UserAttributes']:
            user_attributes[attr['Name']] = attr['Value']
        
        cognito_username = user_details['Username']
        
        # Load user profile from Aurora database
        user_profile = get_user_profile_by_cognito_id(cognito_username)
        
        if not user_profile:
            logger.warning(f"User profile not found for Cognito user: {cognito_username}")
            # Create profile if missing
            user_profile = create_missing_user_profile(cognito_username, user_attributes)
        
        # Update last login timestamp
        update_last_login(user_profile['id'])
        
        # Prepare response with user profile
        auth_result = {
            'access_token': access_token,
            'refresh_token': cognito_response['AuthenticationResult']['RefreshToken'],
            'id_token': cognito_response['AuthenticationResult']['IdToken'],
            'expires_in': cognito_response['AuthenticationResult']['ExpiresIn'],
            'user_profile': {
                'id': user_profile['id'],
                'username': user_profile['username'],
                'email': user_profile['email'],
                'display_name': user_profile['display_name'],
                'role': user_profile['role'],
                'subscription_tier': user_profile['subscription_tier'],
                'subscription_status': user_profile['subscription_status'],
                'avatar_url': user_profile.get('avatar_url'),
                'preferences': user_profile.get('preferences', {}),
                'last_login': user_profile.get('last_login')
            }
        }
        
        logger.info(f"User logged in successfully: {user_profile['username']} ({user_profile['id']})")
        
        return create_response(200, auth_result)
        
    except cognito_client.exceptions.NotAuthorizedException:
        return create_response(401, {'error': 'Invalid credentials'})
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return create_response(500, {'error': 'Login failed'})

def handle_refresh(body):
    """Handle token refresh"""
    try:
        refresh_token = body.get('refresh_token')
        
        if not refresh_token:
            return create_response(400, {'error': 'Refresh token required'})
        
        client_id = os.environ.get('COGNITO_CLIENT_ID')
        
        response = cognito_client.initiate_auth(
            ClientId=client_id,
            AuthFlow='REFRESH_TOKEN_AUTH',
            AuthParameters={
                'REFRESH_TOKEN': refresh_token
            }
        )
        
        return create_response(200, {
            'access_token': response['AuthenticationResult']['AccessToken'],
            'id_token': response['AuthenticationResult']['IdToken'],
            'expires_in': response['AuthenticationResult']['ExpiresIn']
        })
        
    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return create_response(500, {'error': 'Token refresh failed'})

def handle_logout(body):
    """Handle user logout"""
    try:
        access_token = body.get('access_token')
        
        if not access_token:
            return create_response(400, {'error': 'Access token required'})
        
        cognito_client.global_sign_out(
            AccessToken=access_token
        )
        
        return create_response(200, {'message': 'Logged out successfully'})
        
    except Exception as e:
        logger.error(f"Logout error: {str(e)}")
        return create_response(500, {'error': 'Logout failed'})

def handle_verify(body):
    """Handle token verification"""
    try:
        access_token = body.get('access_token')
        
        if not access_token:
            return create_response(400, {'error': 'Access token required'})
        
        response = cognito_client.get_user(
            AccessToken=access_token
        )
        
        user_attributes = {}
        for attr in response['UserAttributes']:
            user_attributes[attr['Name']] = attr['Value']
        
        return create_response(200, {
            'username': response['Username'],
            'attributes': user_attributes
        })
        
    except cognito_client.exceptions.NotAuthorizedException:
        return create_response(401, {'error': 'Invalid or expired token'})
    except Exception as e:
        logger.error(f"Token verification error: {str(e)}")
        return create_response(500, {'error': 'Token verification failed'})

def calculate_secret_hash(username, client_id, client_secret):
    """Calculate SECRET_HASH for Cognito"""
    message = username + client_id
    dig = hmac.new(
        client_secret.encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256
    ).digest()
    return base64.b64encode(dig).decode()

def handle_auth_info():
    """Handle auth info request"""
    try:
        auth_info = {
            'service': 'Authentication Service',
            'version': '1.0.0',
            'endpoints': ['/login', '/register', '/refresh', '/logout', '/verify'],
            'status': 'operational'
        }
        
        return create_response(200, auth_info)
        
    except Exception as e:
        logger.error(f"Auth info error: {str(e)}")
        return create_response(500, {'error': 'Failed to get auth info'})

@handle_database_errors
def handle_get_users():
    """Handle get users request with real database query"""
    try:
        # Query users from Aurora database with streaming statistics
        sql = """
        SELECT u.id, u.username, u.email, u.display_name, u.role, 
               u.subscription_tier, u.subscription_status, u.created_at,
               COUNT(s.id) as total_streams,
               COUNT(CASE WHEN s.status = 'live' THEN 1 END) as active_streams,
               COALESCE(SUM(s.total_views), 0) as total_views
        FROM users u
        LEFT JOIN streams s ON u.id = s.creator_id
        GROUP BY u.id, u.username, u.email, u.display_name, u.role, 
                 u.subscription_tier, u.subscription_status, u.created_at
        ORDER BY u.created_at DESC
        LIMIT 100
        """
        
        result = execute_sql(sql, [])
        
        users = []
        for record in result.get('records', []):
            user = {
                'user_id': record[0]['stringValue'],
                'username': record[1]['stringValue'],
                'email': record[2]['stringValue'],
                'display_name': record[3]['stringValue'] if record[3].get('stringValue') else None,
                'role': record[4]['stringValue'],
                'subscription_tier': record[5]['stringValue'],
                'subscription_status': record[6]['stringValue'],
                'created_at': record[7]['stringValue'],
                'total_streams': int(record[8]['longValue']) if record[8].get('longValue') else 0,
                'active_streams': int(record[9]['longValue']) if record[9].get('longValue') else 0,
                'total_views': int(record[10]['longValue']) if record[10].get('longValue') else 0
            }
            users.append(user)
        
        return create_response(200, {
            'users': users,
            'total': len(users)
        })
        
    except Exception as e:
        logger.error(f"Get users error: {str(e)}")
        return create_response(500, {'error': 'Failed to get users'})

def handle_get_profile(headers):
    """Handle get user profile"""
    try:
        # Extract user from authorization header (simplified)
        auth_header = headers.get('Authorization', '')
        if not auth_header:
            return create_response(401, {'error': 'Unauthorized', 'message': 'Authentication required'})
        
        # Mock profile (replace with actual user profile lookup)
        profile = {
            'user_id': 'user_123',
            'username': 'testuser',
            'email': 'test@example.com',
            'display_name': 'Test User',
            'role': 'viewer',
            'subscription_tier': 'bronze',
            'created_at': '2024-01-01T00:00:00Z'
        }
        
        return create_response(200, profile)
        
    except Exception as e:
        logger.error(f"Get profile error: {str(e)}")
        return create_response(500, {'error': 'Failed to get profile'})

def handle_get_preferences(headers):
    """Handle get user preferences"""
    try:
        # Extract user from authorization header (simplified)
        auth_header = headers.get('Authorization', '')
        if not auth_header:
            return create_response(401, {'error': 'Unauthorized', 'message': 'Authentication required'})
        
        # Mock preferences (replace with actual user preferences)
        preferences = {
            'theme': 'dark',
            'language': 'en',
            'notifications': {
                'email': True,
                'push': False,
                'sms': False
            },
            'privacy': {
                'profile_visibility': 'public',
                'show_activity': True
            }
        }
        
        return create_response(200, preferences)
        
    except Exception as e:
        logger.error(f"Get preferences error: {str(e)}")
        return create_response(500, {'error': 'Failed to get preferences'})

def handle_get_subscription(headers):
    """Handle get user subscription"""
    try:
        # Mock subscription (replace with actual subscription data)
        subscription = {
            'tier': 'bronze',
            'status': 'active',
            'expires_at': '2024-12-31T23:59:59Z',
            'features': ['basic_streaming', 'chat_access'],
            'billing': {
                'amount': 9.99,
                'currency': 'USD',
                'interval': 'monthly'
            }
        }
        
        return create_response(200, subscription)
        
    except Exception as e:
        logger.error(f"Get subscription error: {str(e)}")
        return create_response(500, {'error': 'Failed to get subscription'})

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

def get_user_profile_by_cognito_id(cognito_id: str) -> Optional[Dict[str, Any]]:
    """Get user profile from Aurora database by Cognito ID"""
    sql = """
    SELECT id, cognito_id, email, username, display_name, role, 
           subscription_tier, subscription_status, subscription_renewal_date,
           avatar_url, preferences, created_at, updated_at, last_login
    FROM users 
    WHERE cognito_id = :cognito_id
    """
    
    parameters = [{'name': 'cognito_id', 'value': {'stringValue': cognito_id}}]
    result = execute_sql(sql, parameters)
    
    if result.get('records') and len(result['records']) > 0:
        record = result['records'][0]
        return {
            'id': record[0]['stringValue'],
            'cognito_id': record[1]['stringValue'],
            'email': record[2]['stringValue'],
            'username': record[3]['stringValue'],
            'display_name': record[4]['stringValue'] if record[4].get('stringValue') else None,
            'role': record[5]['stringValue'],
            'subscription_tier': record[6]['stringValue'],
            'subscription_status': record[7]['stringValue'],
            'subscription_renewal_date': record[8]['stringValue'] if record[8].get('stringValue') else None,
            'avatar_url': record[9]['stringValue'] if record[9].get('stringValue') else None,
            'preferences': json.loads(record[10]['stringValue']) if record[10].get('stringValue') else {},
            'created_at': record[11]['stringValue'],
            'updated_at': record[12]['stringValue'],
            'last_login': record[13]['stringValue'] if record[13].get('stringValue') else None
        }
    return None

def create_missing_user_profile(cognito_id: str, cognito_attributes: Dict[str, str]) -> Dict[str, Any]:
    """Create user profile for existing Cognito user"""
    user_id = str(uuid.uuid4())
    email = cognito_attributes.get('email', '')
    username = cognito_attributes.get('preferred_username', cognito_id)
    
    sql = """
    INSERT INTO users (
        id, cognito_id, email, username, display_name, role, 
        subscription_tier, subscription_status, created_at, updated_at
    ) VALUES (
        :user_id, :cognito_id, :email, :username, :username, 'viewer',
        'bronze', 'active', NOW(), NOW()
    )
    """
    
    parameters = [
        {'name': 'user_id', 'value': {'stringValue': user_id}},
        {'name': 'cognito_id', 'value': {'stringValue': cognito_id}},
        {'name': 'email', 'value': {'stringValue': email}},
        {'name': 'username', 'value': {'stringValue': username}}
    ]
    
    execute_sql(sql, parameters)
    
    return {
        'id': user_id,
        'cognito_id': cognito_id,
        'email': email,
        'username': username,
        'display_name': username,
        'role': 'viewer',
        'subscription_tier': 'bronze',
        'subscription_status': 'active'
    }

def update_last_login(user_id: str) -> None:
    """Update user's last login timestamp"""
    sql = "UPDATE users SET last_login = NOW(), updated_at = NOW() WHERE id = :user_id"
    parameters = [{'name': 'user_id', 'value': {'stringValue': user_id}}]
    execute_sql(sql, parameters)

@handle_database_errors
def handle_update_subscription(body):
    """Handle subscription tier updates (admin only)"""
    try:
        user_id = body.get('user_id')
        new_tier = body.get('subscription_tier')
        
        if not user_id or not new_tier:
            return create_response(400, {'error': 'User ID and subscription tier required'})
        
        if new_tier not in ['bronze', 'silver', 'gold']:
            return create_response(400, {'error': 'Invalid subscription tier'})
        
        # Update in Aurora database
        sql = """
        UPDATE users 
        SET subscription_tier = :tier, updated_at = NOW()
        WHERE id = :user_id
        """
        
        parameters = [
            {'name': 'tier', 'value': {'stringValue': new_tier}},
            {'name': 'user_id', 'value': {'stringValue': user_id}}
        ]
        
        execute_sql(sql, parameters)
        
        # Update in Cognito
        user_profile = get_user_profile_by_id(user_id)
        if user_profile:
            cognito_client.admin_update_user_attributes(
                UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
                Username=user_profile['cognito_id'],
                UserAttributes=[
                    {'Name': 'custom:subscription_tier', 'Value': new_tier}
                ]
            )
        
        logger.info(f"Subscription updated for user {user_id} to {new_tier}")
        
        return create_response(200, {
            'message': 'Subscription tier updated successfully',
            'user_id': user_id,
            'new_tier': new_tier
        })
        
    except Exception as e:
        logger.error(f"Update subscription error: {str(e)}")
        return create_response(500, {'error': 'Failed to update subscription'})

def get_user_profile_by_id(user_id: str) -> Optional[Dict[str, Any]]:
    """Get user profile by user ID"""
    sql = """
    SELECT id, cognito_id, email, username, display_name, role, 
           subscription_tier, subscription_status, avatar_url, preferences
    FROM users 
    WHERE id = :user_id
    """
    
    parameters = [{'name': 'user_id', 'value': {'stringValue': user_id}}]
    result = execute_sql(sql, parameters)
    
    if result.get('records') and len(result['records']) > 0:
        record = result['records'][0]
        return {
            'id': record[0]['stringValue'],
            'cognito_id': record[1]['stringValue'],
            'email': record[2]['stringValue'],
            'username': record[3]['stringValue'],
            'display_name': record[4]['stringValue'] if record[4].get('stringValue') else None,
            'role': record[5]['stringValue'],
            'subscription_tier': record[6]['stringValue'],
            'subscription_status': record[7]['stringValue'],
            'avatar_url': record[8]['stringValue'] if record[8].get('stringValue') else None,
            'preferences': json.loads(record[9]['stringValue']) if record[9].get('stringValue') else {}
        }
    return None