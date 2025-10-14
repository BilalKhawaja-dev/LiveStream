import {
  CognitoUserPool,
  CognitoUser,
  CognitoUserSession,
  AuthenticationDetails,
  CognitoUserAttribute,
  ISignUpResult
} from 'amazon-cognito-identity-js';
import { AuthUser, UserRole, SubscriptionTier } from './types';

export interface CognitoConfig {
  userPoolId: string;
  userPoolClientId: string;
  region: string;
}

export class CognitoAuth {
  private userPool: CognitoUserPool;

  constructor(config: CognitoConfig) {
    this.userPool = new CognitoUserPool({
      UserPoolId: config.userPoolId,
      ClientId: config.userPoolClientId
    });
  }

  async signIn(username: string, password: string): Promise<any> {
    return new Promise((resolve, reject) => {
      const authenticationDetails = new AuthenticationDetails({
        Username: username,
        Password: password
      });

      const cognitoUser = new CognitoUser({
        Username: username,
        Pool: this.userPool
      });

      cognitoUser.authenticateUser(authenticationDetails, {
        onSuccess: (session: CognitoUserSession) => {
          resolve({
            signInUserSession: session,
            challengeName: null
          });
        },
        onFailure: (error: Error) => {
          reject(error);
        },
        newPasswordRequired: (userAttributes: any, requiredAttributes: any) => {
          // Handle new password required challenge
          reject(new Error('New password required'));
        },
        mfaRequired: (challengeName: string, challengeParameters: any) => {
          // Handle MFA challenge
          reject(new Error(`MFA required: ${challengeName}`));
        }
      });
    });
  }

  async signUp(
    username: string,
    email: string,
    password: string,
    customAttributes: Record<string, string> = {}
  ): Promise<ISignUpResult> {
    return new Promise((resolve, reject) => {
      const attributeList: CognitoUserAttribute[] = [
        new CognitoUserAttribute({
          Name: 'email',
          Value: email
        })
      ];

      // Add custom attributes
      Object.entries(customAttributes).forEach(([key, value]) => {
        attributeList.push(new CognitoUserAttribute({
          Name: key,
          Value: value
        }));
      });

      this.userPool.signUp(username, password, attributeList, [], (error, result) => {
        if (error) {
          reject(error);
          return;
        }
        resolve(result!);
      });
    });
  }

  async signOut(): Promise<void> {
    const cognitoUser = this.userPool.getCurrentUser();
    if (cognitoUser) {
      cognitoUser.signOut();
    }
  }

  async getCurrentSession(): Promise<CognitoUserSession | null> {
    return new Promise((resolve) => {
      const cognitoUser = this.userPool.getCurrentUser();
      
      if (!cognitoUser) {
        resolve(null);
        return;
      }

      cognitoUser.getSession((error: Error | null, session: CognitoUserSession | null) => {
        if (error || !session) {
          resolve(null);
          return;
        }
        resolve(session);
      });
    });
  }

  async getCurrentUser(): Promise<CognitoUser | null> {
    return this.userPool.getCurrentUser();
  }

  async getUserInfo(cognitoUser: CognitoUser): Promise<AuthUser> {
    return new Promise((resolve, reject) => {
      cognitoUser.getUserAttributes((error, attributes) => {
        if (error) {
          reject(error);
          return;
        }

        if (!attributes) {
          reject(new Error('No user attributes found'));
          return;
        }

        const attributeMap: Record<string, string> = {};
        attributes.forEach(attr => {
          attributeMap[attr.getName()] = attr.getValue();
        });

        const userInfo: AuthUser = {
          username: cognitoUser.getUsername(),
          email: attributeMap['email'] || '',
          emailVerified: attributeMap['email_verified'] === 'true',
          displayName: attributeMap['custom:display_name'] || cognitoUser.getUsername(),
          role: (attributeMap['custom:role'] as UserRole) || 'viewer',
          subscriptionTier: (attributeMap['custom:subscription_tier'] as SubscriptionTier) || 'bronze',
          createdAt: attributeMap['created_at'] || new Date().toISOString(),
          lastLogin: new Date().toISOString()
        };

        resolve(userInfo);
      });
    });
  }

  async updateUserAttributes(
    cognitoUser: CognitoUser,
    updates: Partial<AuthUser>
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      const attributeList: CognitoUserAttribute[] = [];

      // Map updates to Cognito attributes
      if (updates.email) {
        attributeList.push(new CognitoUserAttribute({
          Name: 'email',
          Value: updates.email
        }));
      }

      if (updates.displayName) {
        attributeList.push(new CognitoUserAttribute({
          Name: 'custom:display_name',
          Value: updates.displayName
        }));
      }

      if (updates.role) {
        attributeList.push(new CognitoUserAttribute({
          Name: 'custom:role',
          Value: updates.role
        }));
      }

      if (updates.subscriptionTier) {
        attributeList.push(new CognitoUserAttribute({
          Name: 'custom:subscription_tier',
          Value: updates.subscriptionTier
        }));
      }

      if (attributeList.length === 0) {
        resolve();
        return;
      }

      cognitoUser.updateAttributes(attributeList, (error, result) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }

  async changePassword(
    cognitoUser: CognitoUser,
    oldPassword: string,
    newPassword: string
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      cognitoUser.changePassword(oldPassword, newPassword, (error, result) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }

  async forgotPassword(username: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const cognitoUser = new CognitoUser({
        Username: username,
        Pool: this.userPool
      });

      cognitoUser.forgotPassword({
        onSuccess: () => {
          resolve();
        },
        onFailure: (error: Error) => {
          reject(error);
        }
      });
    });
  }

  async confirmPassword(
    username: string,
    confirmationCode: string,
    newPassword: string
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      const cognitoUser = new CognitoUser({
        Username: username,
        Pool: this.userPool
      });

      cognitoUser.confirmPassword(confirmationCode, newPassword, {
        onSuccess: () => {
          resolve();
        },
        onFailure: (error: Error) => {
          reject(error);
        }
      });
    });
  }

  async resendConfirmationCode(username: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const cognitoUser = new CognitoUser({
        Username: username,
        Pool: this.userPool
      });

      cognitoUser.resendConfirmationCode((error, result) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }

  async confirmRegistration(username: string, confirmationCode: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const cognitoUser = new CognitoUser({
        Username: username,
        Pool: this.userPool
      });

      cognitoUser.confirmRegistration(confirmationCode, true, (error, result) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }
}