import json
import boto3
import stripe
import os
import logging
import uuid
from datetime import datetime
from typing import Dict, Any, Optional

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, os.environ.get('LOG_LEVEL', 'INFO')))

# Initialize AWS clients
rds_client = boto3.client('rds-data')
cognito_client = boto3.client('cognito-idp')
sns_client = boto3.client('sns')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Payment processing handler for streaming platform
    Handles Stripe payments, subscriptions, and webhooks
    """
    
    try:
        # Initialize Stripe
        stripe_secret = get_stripe_secret()
        stripe.api_key = stripe_secret['secret_key']
        
        # Parse the request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        headers = event.get('headers', {})
        
        logger.info(f"Processing {http_method} request to {path}")
        
        # Route to appropriate handler
        if path.endswith('/stripe/create-payment-intent') and http_method == 'POST':
            return handle_create_payment_intent(body)
        elif path.endswith('/stripe/create-subscription') and http_method == 'POST':
            return handle_create_subscription(body)
        elif path.endswith('/stripe/cancel-subscription') and http_method == 'POST':
            return handle_cancel_subscription(body)
        elif path.endswith('/webhooks/stripe') and http_method == 'POST':
            return handle_stripe_webhook(body, headers)
        elif path.endswith('/refunds') and http_method == 'POST':
            return handle_create_refund(body)
        elif '/payments/' in path and http_method == 'GET':
            user_id = path.split('/payments/')[-1]
            return handle_get_payment_history(user_id)
        else:
            return create_response(400, {'error': 'Invalid endpoint or method'})
            
    except Exception as e:
        logger.error(f"Payment handler error: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_create_payment_intent(body: Dict[str, Any]) -> Dict[str, Any]:
    """Create Stripe payment intent for one-time payments"""
    
    try:
        user_id = body.get('user_id')
        amount = body.get('amount')  # Amount in pence (GBP)
        currency = body.get('currency', 'gbp')
        description = body.get('description', 'Streaming platform payment')
        
        if not user_id or not amount:
            return create_response(400, {'error': 'User ID and amount required'})
        
        # Create payment intent
        payment_intent = stripe.PaymentIntent.create(
            amount=int(amount),
            currency=currency,
            description=description,
            metadata={
                'user_id': user_id,
                'platform': 'streaming-platform'
            }
        )
        
        # Store payment record in database
        transaction_id = str(uuid.uuid4())
        
        sql = """
        INSERT INTO payment_transactions (
            id, user_id, stripe_payment_intent_id, amount, currency, 
            type, status, description, created_at
        ) VALUES (
            :transaction_id, :user_id, :payment_intent_id, :amount, :currency,
            'donation', 'pending', :description, NOW()
        )
        """
        
        parameters = [
            {'name': 'transaction_id', 'value': {'stringValue': transaction_id}},
            {'name': 'user_id', 'value': {'stringValue': user_id}},
            {'name': 'payment_intent_id', 'value': {'stringValue': payment_intent.id}},
            {'name': 'amount', 'value': {'doubleValue': amount / 100}},  # Convert to pounds
            {'name': 'currency', 'value': {'stringValue': currency.upper()}},
            {'name': 'description', 'value': {'stringValue': description}}
        ]
        
        rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        return create_response(200, {
            'client_secret': payment_intent.client_secret,
            'payment_intent_id': payment_intent.id,
            'transaction_id': transaction_id
        })
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error: {str(e)}")
        return create_response(400, {'error': f'Payment error: {str(e)}'})
    except Exception as e:
        logger.error(f"Create payment intent error: {str(e)}")
        return create_response(500, {'error': 'Failed to create payment intent'})

def handle_create_subscription(body: Dict[str, Any]) -> Dict[str, Any]:
    """Create Stripe subscription for recurring payments"""
    
    try:
        user_id = body.get('user_id')
        tier = body.get('tier')  # bronze, silver, gold
        payment_method_id = body.get('payment_method_id')
        
        if not user_id or not tier or not payment_method_id:
            return create_response(400, {'error': 'User ID, tier, and payment method required'})
        
        # Define subscription tiers
        tier_prices = {
            'bronze': {'amount': 999, 'quality': '720p'},    # £9.99
            'silver': {'amount': 1999, 'quality': '1080p'},  # £19.99
            'gold': {'amount': 3999, 'quality': '4k'}        # £39.99
        }
        
        if tier not in tier_prices:
            return create_response(400, {'error': 'Invalid subscription tier'})
        
        # Get or create Stripe customer
        customer = get_or_create_stripe_customer(user_id)
        
        # Attach payment method to customer
        stripe.PaymentMethod.attach(
            payment_method_id,
            customer=customer.id
        )
        
        # Create or get price object
        price = get_or_create_price(tier, tier_prices[tier]['amount'])
        
        # Create subscription
        subscription = stripe.Subscription.create(
            customer=customer.id,
            items=[{'price': price.id}],
            default_payment_method=payment_method_id,
            metadata={
                'user_id': user_id,
                'tier': tier,
                'platform': 'streaming-platform'
            }
        )
        
        # Update user subscription in Cognito
        cognito_client.admin_update_user_attributes(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            Username=user_id,
            UserAttributes=[
                {'Name': 'custom:subscription_tier', 'Value': tier},
                {'Name': 'custom:subscription_status', 'Value': 'active'}
            ]
        )
        
        # Store subscription record
        transaction_id = str(uuid.uuid4())
        
        sql = """
        INSERT INTO payment_transactions (
            id, user_id, stripe_subscription_id, amount, currency,
            type, status, description, metadata, created_at
        ) VALUES (
            :transaction_id, :user_id, :subscription_id, :amount, 'GBP',
            'subscription', 'succeeded', :description, :metadata, NOW()
        )
        """
        
        parameters = [
            {'name': 'transaction_id', 'value': {'stringValue': transaction_id}},
            {'name': 'user_id', 'value': {'stringValue': user_id}},
            {'name': 'subscription_id', 'value': {'stringValue': subscription.id}},
            {'name': 'amount', 'value': {'doubleValue': tier_prices[tier]['amount'] / 100}},
            {'name': 'description', 'value': {'stringValue': f'{tier.title()} subscription'}},
            {'name': 'metadata', 'value': {'stringValue': json.dumps({'tier': tier, 'quality': tier_prices[tier]['quality']})}}
        ]
        
        rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        # Send notification
        send_payment_notification(user_id, 'subscription_created', {
            'tier': tier,
            'amount': tier_prices[tier]['amount'] / 100,
            'subscription_id': subscription.id
        })
        
        return create_response(200, {
            'subscription_id': subscription.id,
            'status': subscription.status,
            'tier': tier,
            'amount': tier_prices[tier]['amount'] / 100,
            'transaction_id': transaction_id
        })
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe subscription error: {str(e)}")
        return create_response(400, {'error': f'Subscription error: {str(e)}'})
    except Exception as e:
        logger.error(f"Create subscription error: {str(e)}")
        return create_response(500, {'error': 'Failed to create subscription'})

def handle_cancel_subscription(body: Dict[str, Any]) -> Dict[str, Any]:
    """Cancel Stripe subscription"""
    
    try:
        user_id = body.get('user_id')
        subscription_id = body.get('subscription_id')
        
        if not user_id or not subscription_id:
            return create_response(400, {'error': 'User ID and subscription ID required'})
        
        # Cancel subscription
        subscription = stripe.Subscription.modify(
            subscription_id,
            cancel_at_period_end=True
        )
        
        # Update user subscription status in Cognito
        cognito_client.admin_update_user_attributes(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            Username=user_id,
            UserAttributes=[
                {'Name': 'custom:subscription_status', 'Value': 'cancelled'}
            ]
        )
        
        # Send notification
        send_payment_notification(user_id, 'subscription_cancelled', {
            'subscription_id': subscription_id,
            'cancel_at': subscription.cancel_at
        })
        
        return create_response(200, {
            'subscription_id': subscription_id,
            'status': 'cancelled',
            'cancel_at': subscription.cancel_at
        })
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe cancellation error: {str(e)}")
        return create_response(400, {'error': f'Cancellation error: {str(e)}'})
    except Exception as e:
        logger.error(f"Cancel subscription error: {str(e)}")
        return create_response(500, {'error': 'Failed to cancel subscription'})

def handle_stripe_webhook(body: Dict[str, Any], headers: Dict[str, Any]) -> Dict[str, Any]:
    """Handle Stripe webhook events"""
    
    try:
        # Verify webhook signature
        webhook_secret = get_stripe_webhook_secret()
        signature = headers.get('stripe-signature')
        
        try:
            event = stripe.Webhook.construct_event(
                json.dumps(body), signature, webhook_secret
            )
        except ValueError:
            return create_response(400, {'error': 'Invalid payload'})
        except stripe.error.SignatureVerificationError:
            return create_response(400, {'error': 'Invalid signature'})
        
        # Handle different event types
        if event['type'] == 'payment_intent.succeeded':
            handle_payment_succeeded(event['data']['object'])
        elif event['type'] == 'payment_intent.payment_failed':
            handle_payment_failed(event['data']['object'])
        elif event['type'] == 'invoice.payment_succeeded':
            handle_subscription_payment_succeeded(event['data']['object'])
        elif event['type'] == 'invoice.payment_failed':
            handle_subscription_payment_failed(event['data']['object'])
        elif event['type'] == 'customer.subscription.deleted':
            handle_subscription_deleted(event['data']['object'])
        
        return create_response(200, {'received': True})
        
    except Exception as e:
        logger.error(f"Webhook error: {str(e)}")
        return create_response(500, {'error': 'Webhook processing failed'})

def handle_payment_succeeded(payment_intent: Dict[str, Any]) -> None:
    """Handle successful payment"""
    
    try:
        # Update payment status in database
        sql = """
        UPDATE payment_transactions 
        SET status = 'succeeded', updated_at = NOW()
        WHERE stripe_payment_intent_id = :payment_intent_id
        """
        
        parameters = [
            {'name': 'payment_intent_id', 'value': {'stringValue': payment_intent['id']}}
        ]
        
        rds_client.execute_statement(
            resourceArn=os.environ['AURORA_CLUSTER_ARN'],
            secretArn=os.environ['AURORA_SECRET_ARN'],
            database='streaming_platform',
            sql=sql,
            parameters=parameters
        )
        
        # Send notification
        user_id = payment_intent['metadata'].get('user_id')
        if user_id:
            send_payment_notification(user_id, 'payment_succeeded', {
                'amount': payment_intent['amount'] / 100,
                'currency': payment_intent['currency']
            })
        
    except Exception as e:
        logger.error(f"Handle payment succeeded error: {str(e)}")

def get_or_create_stripe_customer(user_id: str) -> Any:
    """Get existing Stripe customer or create new one"""
    
    try:
        # Try to find existing customer
        customers = stripe.Customer.list(
            metadata={'user_id': user_id},
            limit=1
        )
        
        if customers.data:
            return customers.data[0]
        
        # Get user email from Cognito
        user_response = cognito_client.admin_get_user(
            UserPoolId=os.environ['COGNITO_USER_POOL_ID'],
            Username=user_id
        )
        
        user_attributes = {attr['Name']: attr['Value'] for attr in user_response['UserAttributes']}
        email = user_attributes.get('email')
        
        # Create new customer
        customer = stripe.Customer.create(
            email=email,
            metadata={'user_id': user_id}
        )
        
        return customer
        
    except Exception as e:
        logger.error(f"Get or create customer error: {str(e)}")
        raise

def get_or_create_price(tier: str, amount: int) -> Any:
    """Get existing price or create new one"""
    
    try:
        # Try to find existing price
        prices = stripe.Price.list(
            metadata={'tier': tier},
            limit=1
        )
        
        if prices.data:
            return prices.data[0]
        
        # Create new price
        price = stripe.Price.create(
            unit_amount=amount,
            currency='gbp',
            recurring={'interval': 'month'},
            product_data={
                'name': f'{tier.title()} Subscription',
                'metadata': {'tier': tier}
            },
            metadata={'tier': tier}
        )
        
        return price
        
    except Exception as e:
        logger.error(f"Get or create price error: {str(e)}")
        raise

def send_payment_notification(user_id: str, event_type: str, data: Dict[str, Any]) -> None:
    """Send payment notification via SNS"""
    
    try:
        message = {
            'user_id': user_id,
            'event_type': event_type,
            'data': data,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        sns_client.publish(
            TopicArn=os.environ['SNS_TOPIC_ARN'],
            Message=json.dumps(message),
            Subject=f'Payment {event_type.replace("_", " ").title()}'
        )
        
    except Exception as e:
        logger.error(f"Send notification error: {str(e)}")

def get_stripe_secret() -> Dict[str, Any]:
    """Get Stripe secrets from Secrets Manager"""
    
    try:
        response = secrets_client.get_secret_value(SecretId=os.environ['STRIPE_SECRET_KEY_ARN'])
        return json.loads(response['SecretString'])
    except Exception as e:
        logger.error(f"Failed to get Stripe secret: {str(e)}")
        raise

def get_stripe_webhook_secret() -> str:
    """Get Stripe webhook secret from Secrets Manager"""
    
    try:
        response = secrets_client.get_secret_value(SecretId=os.environ['STRIPE_WEBHOOK_SECRET_ARN'])
        secret_data = json.loads(response['SecretString'])
        return secret_data['webhook_secret']
    except Exception as e:
        logger.error(f"Failed to get Stripe webhook secret: {str(e)}")
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