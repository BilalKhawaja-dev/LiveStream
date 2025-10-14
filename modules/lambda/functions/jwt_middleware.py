import json
import jwt
import boto3
import os
import logging
import time
from typing import Dict, Any, Optional
from urllib.request import urlopen
from jose import jwk, jwt as jose_jwt
from jose.exceptions import JWTError

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
cognito_client = boto3.client('cognito-idp')

# Cache for JWKS
jwks_cache = {}
jwks_cache_expiry = 0

def lambda_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    JWT middleware for API Gateway
    Validates JWT tokens and adds user context to requests
    """
    
    try:
        # Extract token from Authorization header
        token = extract_token_from_event(event)
        if not token:
            return generate_policy('user', 'Deny', event['methodArn'], {
                'error': 'Missing authorization token'
            })
        
        # Validate and decode token
        decoded_token = validate_jwt_token(token)
        if not decoded_token:
            return generate_policy('user', 'Deny', event['methodArn'], {
                'error': 'Invalid or expired token'
            })
        
        # Extract user information
        user_info = extract_user_info(decoded_token)
        
        # Check if token needs refresh
        if should_refresh_token(decoded_token):
            user_info['token_refresh_needed'] = True
        
        logger.info(f"JWT validation successful for user: {user_info.get('username', 'unknown')}")
        
        # Generate allow policy with user context
        return generate_policy(
            user_info['username'], 
            'Allow', 
            event['methodArn'], 
            user_info
        )
        
    except Exception as e:
        logger.error(f"JWT validation error: {str(e)}")
        return generate_policy('user', 'Deny', event['methodArn'], {
            'error': 'Token validation failed',
            'message': str(e)
        })

def extract_token_from_event(event: Dict[str, Any]) -> Optional[str]:
    """
    Extract JWT token from API Gateway event
    """
    # Check Authorization header
    headers = event.get('headers', {})
    auth_header = headers.get('Authorization') or headers.get('authorization')
    
    if auth_header and auth_header.startswith('Bearer '):
        return auth_header[7:]  # Remove 'Bearer ' prefix
    
    # Check query parameters as fallback
    query_params = event.get('queryStringParameters') or {}
    return query_params.get('token')

def validate_jwt_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Validate JWT token against Cognito User Pool
    """
    try:
        # Get JWKS from Cognito
        jwks = get_jwks()
        
        # Get token header to find the key ID
        unverified_header = jose_jwt.get_unverified_header(token)
        kid = unverified_header.get('kid')
        
        if not kid:
            logger.error("Token missing key ID")
            return None
        
        # Find the correct key
        key = None
        for jwk_key in jwks['keys']:
            if jwk_key['kid'] == kid:
                key = jwk.construct(jwk_key)
                break
        
        if not key:
            logger.error(f"Key ID {kid} not found in JWKS")
            return None
        
        # Verify and decode token
        decoded_token = jose_jwt.decode(
            token,
            key,
            algorithms=['RS256'],
            audience=os.environ['COGNITO_USER_POOL_CLIENT_ID'],
            issuer=f"https://cognito-idp.{os.environ['AWS_REGION']}.amazonaws.com/{os.environ['COGNITO_USER_POOL_ID']}"
        )
        
        # Additional validation
        if decoded_token.get('token_use') != 'access':
            logger.error("Token is not an access token")
            return None
        
        return decoded_token
        
    except JWTError as e:
        logger.error(f"JWT validation error: {str(e)}")
        return None
    except Exception as e:
        logger.error(f"Token validation error: {str(e)}")
        return None

def get_jwks() -> Dict[str, Any]:
    """
    Get JWKS from Cognito User Pool with caching
    """
    global jwks_cache, jwks_cache_expiry
    
    current_time = time.time()
    
    # Check if cache is still valid (cache for 1 hour)
    if jwks_cache and current_time < jwks_cache_expiry:
        return jwks_cache
    
    try:
        # Fetch JWKS from Cognito
        jwks_url = f"https://cognito-idp.{os.environ['AWS_REGION']}.amazonaws.com/{os.environ['COGNITO_USER_POOL_ID']}/.well-known/jwks.json"
        
        with urlopen(jwks_url) as response:
            jwks_data = json.loads(response.read().decode('utf-8'))
        
        # Cache the JWKS for 1 hour
        jwks_cache = jwks_data
        jwks_cache_expiry = current_time + 3600
        
        return jwks_data
        
    except Exception as e:
        logger.error(f"Failed to fetch JWKS: {str(e)}")
        raise

def extract_user_info(decoded_token: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract user information from decoded JWT token
    """
    return {
        'username': decoded_token.get('username', ''),
        'sub': decoded_token.get('sub', ''),
        'email': decoded_token.get('email', ''),
        'email_verified': decoded_token.get('email_verified', False),
        'cognito_groups': decoded_token.get('cognito:groups', []),
        'token_use': decoded_token.get('token_use', ''),
        'scope': decoded_token.get('scope', ''),
        'auth_time': decoded_token.get('auth_time', 0),
        'iat': decoded_token.get('iat', 0),
        'exp': decoded_token.get('exp', 0),
        'client_id': decoded_token.get('client_id', ''),
        'custom_attributes': {
            'subscription_tier': decoded_token.get('custom:subscription_tier', 'bronze'),
            'role': decoded_token.get('custom:role', 'viewer'),
            'display_name': decoded_token.get('custom:display_name', '')
        }
    }

def should_refresh_token(decoded_token: Dict[str, Any]) -> bool:
    """
    Check if token should be refreshed (expires within 5 minutes)
    """
    exp = decoded_token.get('exp', 0)
    current_time = time.time()
    time_until_expiry = exp - current_time
    
    # Suggest refresh if token expires within 5 minutes
    return time_until_expiry < 300

def generate_policy(principal_id: str, effect: str, resource: str, context: Dict[str, Any]) -> Dict[str, Any]:
    """
    Generate IAM policy for API Gateway
    """
    auth_response = {
        'principalId': principal_id
    }
    
    if effect and resource:
        policy_document = {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }
            ]
        }
        auth_response['policyDocument'] = policy_document
    
    # Add context information
    if context:
        # API Gateway context values must be strings
        string_context = {}
        for key, value in context.items():
            if isinstance(value, (dict, list)):
                string_context[key] = json.dumps(value)
            else:
                string_context[key] = str(value)
        
        auth_response['context'] = string_context
    
    return auth_response

def refresh_access_token(refresh_token: str) -> Optional[Dict[str, Any]]:
    """
    Refresh access token using refresh token
    """
    try:
        response = cognito_client.admin_initiate_auth(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            ClientId=os.environ['COGNITO_USER_POOL_CLIENT_ID'],
            AuthFlow='REFRESH_TOKEN_AUTH',
            AuthParameters={
                'REFRESH_TOKEN': refresh_token
            }
        )
        
        auth_result = response.get('AuthenticationResult', {})
        
        return {
            'access_token': auth_result.get('AccessToken'),
            'id_token': auth_result.get('IdToken'),
            'expires_in': auth_result.get('ExpiresIn'),
            'token_type': auth_result.get('TokenType', 'Bearer')
        }
        
    except Exception as e:
        logger.error(f"Token refresh error: {str(e)}")
        return None

# Handler for token refresh endpoint
def refresh_token_handler(event: Dict[str, Any], context) -> Dict[str, Any]:
    """
    Separate handler for token refresh requests
    """
    try:
        body = json.loads(event.get('body', '{}'))
        refresh_token = body.get('refresh_token')
        
        if not refresh_token:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                    'Access-Control-Allow-Methods': 'POST,OPTIONS'
                },
                'body': json.dumps({
                    'error': 'Missing refresh token'
                })
            }
        
        # Refresh the token
        new_tokens = refresh_access_token(refresh_token)
        
        if not new_tokens:
            return {
                'statusCode': 401,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                    'Access-Control-Allow-Methods': 'POST,OPTIONS'
                },
                'body': json.dumps({
                    'error': 'Invalid or expired refresh token'
                })
            }
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({
                'message': 'Token refreshed successfully',
                'tokens': new_tokens
            })
        }
        
    except Exception as e:
        logger.error(f"Token refresh handler error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({
                'error': 'Token refresh failed',
                'message': str(e)
            })
        }