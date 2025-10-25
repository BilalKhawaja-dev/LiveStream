// Basic auth API for viewer portal
export interface User {
  id: string;
  email: string;
  subscription: 'bronze' | 'silver' | 'gold';
  isStreamer: boolean;
}

import { CognitoIdentityProviderClient, InitiateAuthCommand, SignUpCommand, GetUserCommand, GlobalSignOutCommand } from '@aws-sdk/client-cognito-identity-provider';
import { DynamoDBClient, GetItemCommand, PutItemCommand } from '@aws-sdk/client-dynamodb';

const cognitoClient = new CognitoIdentityProviderClient({ region: 'us-east-1' });
const dynamoClient = new DynamoDBClient({ region: 'us-east-1' });
const CLIENT_ID = process.env.REACT_APP_COGNITO_CLIENT_ID || 'your-client-id';

export const authAPI = {
  login: async (email: string, password: string): Promise<User | null> => {
    try {
      const command = new InitiateAuthCommand({
        ClientId: CLIENT_ID,
        AuthFlow: 'USER_PASSWORD_AUTH',
        AuthParameters: {
          USERNAME: email,
          PASSWORD: password
        }
      });
      
      const response = await cognitoClient.send(command);
      const accessToken = response.AuthenticationResult?.AccessToken;
      
      if (accessToken) {
        localStorage.setItem('accessToken', accessToken);
        return await authAPI.getCurrentUser();
      }
      return null;
    } catch (error) {
      console.error('Login error:', error);
      return null;
    }
  },

  logout: async (): Promise<void> => {
    try {
      const token = localStorage.getItem('accessToken');
      if (token) {
        await cognitoClient.send(new GlobalSignOutCommand({ AccessToken: token }));
      }
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      localStorage.removeItem('accessToken');
    }
  },

  getCurrentUser: async (): Promise<User | null> => {
    try {
      const token = localStorage.getItem('accessToken');
      if (!token) return null;
      
      const command = new GetUserCommand({ AccessToken: token });
      const response = await cognitoClient.send(command);
      
      const userId = response.UserAttributes?.find(attr => attr.Name === 'sub')?.Value || '';
      const email = response.UserAttributes?.find(attr => attr.Name === 'email')?.Value || '';
      
      // Get user profile from DynamoDB
      const userProfile = await dynamoClient.send(new GetItemCommand({
        TableName: 'streaming-users',
        Key: { user_id: { S: userId } }
      }));
      
      return {
        id: userId,
        email,
        subscription: (userProfile.Item?.subscription?.S as any) || 'bronze',
        isStreamer: userProfile.Item?.is_streamer?.BOOL || false
      };
    } catch (error) {
      console.error('Get user error:', error);
      localStorage.removeItem('accessToken');
      return null;
    }
  },

  register: async (email: string, password: string): Promise<User> => {
    const command = new SignUpCommand({
      ClientId: CLIENT_ID,
      Username: email,
      Password: password,
      UserAttributes: [
        { Name: 'email', Value: email }
      ]
    });
    
    const response = await cognitoClient.send(command);
    const userId = response.UserSub || '';
    
    // Create user profile in DynamoDB
    await dynamoClient.send(new PutItemCommand({
      TableName: 'streaming-users',
      Item: {
        user_id: { S: userId },
        email: { S: email },
        subscription: { S: 'bronze' },
        is_streamer: { BOOL: false },
        created_at: { S: new Date().toISOString() }
      }
    }));
    
    return {
      id: userId,
      email,
      subscription: 'bronze',
      isStreamer: false
    };
  }
};