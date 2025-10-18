import json
import boto3
import hashlib
import hmac
import base64
import os
from datetime import datetime, timedelta
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
cognito_client = boto3.client('cognito-idp')

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
        else:
            return create_response(404, {'error': 'Endpoint not found'})
            
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_register(body):
    """Handle user registration"""
    try:
        email = body.get('email')
        password = body.get('password')
        username = body.get('username')
        
        if not all([email, password, username]):
            return create_response(400, {'error': 'Missing required fields'})
        
        user_pool_id = os.environ.get('COGNITO_USER_POOL_ID')
        client_id = os.environ.get('COGNITO_CLIENT_ID')
        
        if not user_pool_id or not client_id:
            logger.error("Missing Cognito configuration")
            return create_response(500, {'error': 'Authentication service not configured'})
        
        # Create user in Cognito
        response = cognito_client.admin_create_user(
            UserPoolId=user_pool_id,
            Username=username,
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
            Username=username,
            Password=password,
            Permanent=True
        )
        
        return create_response(201, {
            'message': 'User registered successfully',
            'username': username
        })
        
    except cognito_client.exceptions.UsernameExistsException:
        return create_response(409, {'error': 'Username already exists'})
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        return create_response(500, {'error': 'Registration failed'})

def handle_login(body):
    """Handle user login"""
    try:
        username = body.get('username')
        password = body.get('password')
        
        if not username or not password:
            return create_response(400, {'error': 'Username and password required'})
        
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
        
        response = cognito_client.initiate_auth(
            ClientId=client_id,
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters=auth_params
        )
        
        return create_response(200, {
            'access_token': response['AuthenticationResult']['AccessToken'],
            'refresh_token': response['AuthenticationResult']['RefreshToken'],
            'id_token': response['AuthenticationResult']['IdToken'],
            'expires_in': response['AuthenticationResult']['ExpiresIn']
        })
        
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

def handle_get_users():
    """Handle get users request"""
    try:
        # Mock user list (replace with actual user management)
        users = [
            {
                'user_id': 'user_001',
                'username': 'testuser1',
                'email': 'test1@example.com',
                'role': 'viewer',
                'created_at': '2024-01-15T10:30:00Z'
            },
            {
                'user_id': 'user_002',
                'username': 'creator1',
                'email': 'creator1@example.com',
                'role': 'creator',
                'created_at': '2024-01-14T09:15:00Z'
            }
        ]
        
        return create_response(200, {
            'users': users,
            'total': len(users)
        })
        
    except Exception as e:
        logger.error(f"Get users error: {str(e)}")
        return create_response(500, {'error': 'Failed to get users'})

def handle_get_preferences(headers):
    """Handle get user preferences"""
    try:
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