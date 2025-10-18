import json
import boto3
import base64
import logging
import os
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
cognito_client = boto3.client('cognito-idp')

def lambda_handler(event, context):
    """
    JWT Middleware for API Gateway Authorization
    """
    try:
        logger.info(f"Authorization request: {json.dumps(event)}")
        
        # Extract token from the authorization header
        token = event.get('authorizationToken', '')
        method_arn = event.get('methodArn', '')
        
        if not token:
            logger.error("No authorization token provided")
            raise Exception('Unauthorized')
        
        # Remove 'Bearer ' prefix if present
        if token.startswith('Bearer '):
            token = token[7:]
        
        # Validate token with Cognito
        try:
            response = cognito_client.get_user(AccessToken=token)
            
            # Extract user information
            user_attributes = {}
            for attr in response['UserAttributes']:
                user_attributes[attr['Name']] = attr['Value']
            
            user_id = user_attributes.get('sub')
            email = user_attributes.get('email')
            role = user_attributes.get('custom:role', 'viewer')
            
            logger.info(f"Token validated for user: {email}")
            
            # Generate policy
            policy = generate_policy(user_id, 'Allow', method_arn, {
                'user_id': user_id,
                'email': email,
                'role': role
            })
            
            return policy
            
        except cognito_client.exceptions.NotAuthorizedException:
            logger.error("Invalid or expired token")
            raise Exception('Unauthorized')
        except Exception as e:
            logger.error(f"Token validation error: {str(e)}")
            raise Exception('Unauthorized')
            
    except Exception as e:
        logger.error(f"Authorization error: {str(e)}")
        # Return deny policy
        return generate_policy('user', 'Deny', method_arn)

def generate_policy(principal_id, effect, resource, context=None):
    """Generate IAM policy for API Gateway"""
    
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
    
    # Add context if provided
    if context:
        auth_response['context'] = context
    
    return auth_response