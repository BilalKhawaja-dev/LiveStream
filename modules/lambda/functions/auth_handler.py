import json
import boto3
import jwt
import os
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
cognito_client = boto3.client('cognito-idp')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Authentication handler for streaming platform
    Handles login, logout, token refresh, and user registration
    """
    
    try:
        # Parse the request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        headers = event.get('headers', {})
        
        logger.info(f"Processing {http_method} request to {path}")
        
        # Route to appropriate handler
        if path.endswith('/login') and http_method == 'POST':
            return handle_login(body)
        elif path.endswith('/logout') and http_method == 'POST':
            return handle_logout(headers)
        elif path.endswith('/refresh') and http_method == 'POST':
            return handle_token_refresh(body)
        elif path.endswith('/register') and http_method == 'POST':
            return handle_registration(body)
        elif path.endswith('/profile') and http_method == 'GET':
            return handle_get_profile(headers)
        else:
            return create_response(400, {'error': 'Invalid endpoint or method'})
            
    except Exception as e:
        logger.error(f"Authentication error: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_login(body: Dict[str, Any]) -> Dict[str, Any]:
    """Handle user login with Cognito"""
    
    try:
        email = body.get('email')
        password = body.get('password')
        
        if not email or not password:
            return create_response(400, {'error': 'Email and password required'})
        
        # Authenticate with Cognito
        response = cognito_client.admin_initiate_auth(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            ClientId=os.environ['COGNITO_CLIENT_ID'],
            AuthFlow='ADMIN_NO_SRP_AUTH',
            AuthParameters={
                'USERNAME': email,
                'PASSWORD': password
            }
        )
        
        # Get user attributes
        user_response = cognito_client.admin_get_user(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            Username=email
        )
        
        # Extract user information
        user_attributes = {attr['Name']: attr['Value'] for attr in user_response['UserAttributes']}
        
        # Create custom JWT token with user info
        token_payload = {
            'sub': user_attributes.get('sub'),
            'email': user_attributes.get('email'),
            'role': user_attributes.get('custom:role', 'viewer'),
            'subscription_tier': user_attributes.get('custom:subscription_tier', 'bronze'),
            'exp': datetime.utcnow() + timedelta(hours=12),
            'iat': datetime.utcnow()
        }
        
        # Get JWT secret
        jwt_secret = get_jwt_secret()
        access_token = jwt.encode(token_payload, jwt_secret, algorithm='HS256')
        
        return create_response(200, {
            'access_token': access_token,
            'token_type': 'Bearer',
            'expires_in': 43200,  # 12 hours
            'user': {
                'id': user_attributes.get('sub'),
                'email': user_attributes.get('email'),
                'role': user_attributes.get('custom:role', 'viewer'),
                'subscription_tier': user_attributes.get('custom:subscription_tier', 'bronze')
            }
        })
        
    except cognito_client.exceptions.NotAuthorizedException:
        return create_response(401, {'error': 'Invalid credentials'})
    except cognito_client.exceptions.UserNotFoundException:
        return create_response(404, {'error': 'User not found'})
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return create_response(500, {'error': 'Login failed'})

def handle_logout(headers: Dict[str, Any]) -> Dict[str, Any]:
    """Handle user logout"""
    
    try:
        # In a stateless JWT system, logout is handled client-side
        # We could implement token blacklisting here if needed
        
        return create_response(200, {'message': 'Logged out successfully'})
        
    except Exception as e:
        logger.error(f"Logout error: {str(e)}")
        return create_response(500, {'error': 'Logout failed'})

def handle_token_refresh(body: Dict[str, Any]) -> Dict[str, Any]:
    """Handle token refresh"""
    
    try:
        refresh_token = body.get('refresh_token')
        
        if not refresh_token:
            return create_response(400, {'error': 'Refresh token required'})
        
        # Validate and decode the refresh token
        jwt_secret = get_jwt_secret()
        
        try:
            decoded_token = jwt.decode(refresh_token, jwt_secret, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return create_response(401, {'error': 'Refresh token expired'})
        except jwt.InvalidTokenError:
            return create_response(401, {'error': 'Invalid refresh token'})
        
        # Create new access token
        token_payload = {
            'sub': decoded_token['sub'],
            'email': decoded_token['email'],
            'role': decoded_token['role'],
            'subscription_tier': decoded_token['subscription_tier'],
            'exp': datetime.utcnow() + timedelta(hours=12),
            'iat': datetime.utcnow()
        }
        
        access_token = jwt.encode(token_payload, jwt_secret, algorithm='HS256')
        
        return create_response(200, {
            'access_token': access_token,
            'token_type': 'Bearer',
            'expires_in': 43200
        })
        
    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return create_response(500, {'error': 'Token refresh failed'})

def handle_registration(body: Dict[str, Any]) -> Dict[str, Any]:
    """Handle user registration"""
    
    try:
        email = body.get('email')
        password = body.get('password')
        username = body.get('username')
        role = body.get('role', 'viewer')
        
        if not email or not password or not username:
            return create_response(400, {'error': 'Email, password, and username required'})
        
        # Create user in Cognito
        response = cognito_client.admin_create_user(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            Username=email,
            UserAttributes=[
                {'Name': 'email', 'Value': email},
                {'Name': 'email_verified', 'Value': 'true'},
                {'Name': 'custom:role', 'Value': role},
                {'Name': 'custom:subscription_tier', 'Value': 'bronze'}
            ],
            TemporaryPassword=password,
            MessageAction='SUPPRESS'
        )
        
        # Set permanent password
        cognito_client.admin_set_user_password(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            Username=email,
            Password=password,
            Permanent=True
        )
        
        return create_response(201, {
            'message': 'User registered successfully',
            'user_id': response['User']['Username']
        })
        
    except cognito_client.exceptions.UsernameExistsException:
        return create_response(409, {'error': 'User already exists'})
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        return create_response(500, {'error': 'Registration failed'})

def handle_get_profile(headers: Dict[str, Any]) -> Dict[str, Any]:
    """Get user profile from token"""
    
    try:
        # Extract token from Authorization header
        auth_header = headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return create_response(401, {'error': 'Invalid authorization header'})
        
        token = auth_header.split(' ')[1]
        jwt_secret = get_jwt_secret()
        
        try:
            decoded_token = jwt.decode(token, jwt_secret, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            return create_response(401, {'error': 'Token expired'})
        except jwt.InvalidTokenError:
            return create_response(401, {'error': 'Invalid token'})
        
        # Get fresh user data from Cognito
        user_response = cognito_client.admin_get_user(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            Username=decoded_token['email']
        )
        
        user_attributes = {attr['Name']: attr['Value'] for attr in user_response['UserAttributes']}
        
        return create_response(200, {
            'user': {
                'id': user_attributes.get('sub'),
                'email': user_attributes.get('email'),
                'role': user_attributes.get('custom:role', 'viewer'),
                'subscription_tier': user_attributes.get('custom:subscription_tier', 'bronze'),
                'created_at': user_response['UserCreateDate'].isoformat(),
                'last_modified': user_response['UserLastModifiedDate'].isoformat()
            }
        })
        
    except Exception as e:
        logger.error(f"Get profile error: {str(e)}")
        return create_response(500, {'error': 'Failed to get profile'})

def get_jwt_secret() -> str:
    """Get JWT secret from Secrets Manager"""
    
    try:
        response = secrets_client.get_secret_value(SecretId=os.environ['JWT_SECRET_ARN'])
        secret_data = json.loads(response['SecretString'])
        return secret_data['jwt_secret']
    except Exception as e:
        logger.error(f"Failed to get JWT secret: {str(e)}")
        raise

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