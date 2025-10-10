import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { Amplify, Auth } from 'aws-amplify';
import { useGlobalStore, UserProfile, UserRole } from '@streaming/shared';
import { authConfig, tokenConfig, mfaConfig } from './config';

// Configure Amplify
Amplify.configure({
  Auth: authConfig,
});

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: UserProfile | null;
  signIn: (username: string, password: string) => Promise<any>;
  signUp: (username: string, password: string, email: string) => Promise<any>;
  signOut: () => Promise<void>;
  confirmSignUp: (username: string, code: string) => Promise<any>;
  resendConfirmationCode: (username: string) => Promise<any>;
  forgotPassword: (username: string) => Promise<any>;
  forgotPasswordSubmit: (username: string, code: string, newPassword: string) => Promise<any>;
  changePassword: (oldPassword: string, newPassword: string) => Promise<any>;
  setupMFA: () => Promise<string>;
  confirmMFA: (code: string) => Promise<any>;
  refreshToken: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<UserProfile | null>(null);
  const { setUser: setGlobalUser, addNotification } = useGlobalStore();

  // Check authentication status on mount
  useEffect(() => {
    checkAuthState();
  }, []);

  // Set up token refresh interval
  useEffect(() => {
    if (isAuthenticated) {
      const interval = setInterval(() => {
        refreshToken();
      }, tokenConfig.tokenRefreshThreshold);

      return () => clearInterval(interval);
    }
  }, [isAuthenticated]);

  const checkAuthState = async () => {
    try {
      setIsLoading(true);
      const cognitoUser = await Auth.currentAuthenticatedUser();
      const userProfile = await getUserProfile(cognitoUser);
      
      setUser(userProfile);
      setGlobalUser(userProfile);
      setIsAuthenticated(true);
    } catch (error) {
      setIsAuthenticated(false);
      setUser(null);
    } finally {
      setIsLoading(false);
    }
  };

  const getUserProfile = async (cognitoUser: any): Promise<UserProfile> => {
    const attributes = cognitoUser.attributes;
    const groups = cognitoUser.signInUserSession?.accessToken?.payload['cognito:groups'] || [];
    
    // Determine user role from Cognito groups
    const role: UserRole = groups.includes('admin') ? 'admin' :
                          groups.includes('creator') ? 'creator' :
                          groups.includes('support') ? 'support' :
                          groups.includes('analyst') ? 'analyst' :
                          groups.includes('developer') ? 'developer' :
                          'viewer';

    // Get subscription tier from custom attributes
    const subscriptionTier = attributes['custom:subscription_tier'] || 'bronze';

    return {
      id: cognitoUser.username,
      cognitoId: attributes.sub,
      email: attributes.email,
      username: cognitoUser.username,
      role,
      subscription: {
        tier: subscriptionTier,
        status: attributes['custom:subscription_status'] || 'active',
        renewalDate: new Date(attributes['custom:subscription_renewal'] || Date.now()),
      },
      preferences: {
        theme: attributes['custom:theme'] || 'light',
        language: attributes['custom:language'] || 'en',
        notifications: {
          email: attributes['custom:notifications_email'] === 'true',
          push: attributes['custom:notifications_push'] === 'true',
          sms: attributes['custom:notifications_sms'] === 'true',
          marketing: attributes['custom:notifications_marketing'] === 'true',
        },
      },
      createdAt: new Date(attributes['custom:created_at'] || Date.now()),
      lastLogin: new Date(),
    };
  };

  const signIn = async (username: string, password: string) => {
    try {
      const cognitoUser = await Auth.signIn(username, password);
      
      // Handle MFA challenge if required
      if (cognitoUser.challengeName === 'SOFTWARE_TOKEN_MFA') {
        return { requiresMFA: true, user: cognitoUser };
      }
      
      const userProfile = await getUserProfile(cognitoUser);
      setUser(userProfile);
      setGlobalUser(userProfile);
      setIsAuthenticated(true);
      
      addNotification({
        type: 'success',
        title: 'Welcome back!',
        message: 'You have successfully signed in.',
      });
      
      return { success: true, user: userProfile };
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'Sign In Failed',
        message: error.message || 'Failed to sign in. Please try again.',
      });
      throw error;
    }
  };

  const signUp = async (username: string, password: string, email: string) => {
    try {
      const result = await Auth.signUp({
        username,
        password,
        attributes: {
          email,
          'custom:subscription_tier': 'bronze',
          'custom:subscription_status': 'active',
          'custom:created_at': new Date().toISOString(),
        },
      });
      
      addNotification({
        type: 'success',
        title: 'Account Created',
        message: 'Please check your email for verification code.',
      });
      
      return result;
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'Sign Up Failed',
        message: error.message || 'Failed to create account. Please try again.',
      });
      throw error;
    }
  };

  const signOut = async () => {
    try {
      await Auth.signOut();
      setIsAuthenticated(false);
      setUser(null);
      setGlobalUser({});
      
      addNotification({
        type: 'info',
        title: 'Signed Out',
        message: 'You have been successfully signed out.',
      });
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'Sign Out Failed',
        message: error.message || 'Failed to sign out.',
      });
      throw error;
    }
  };

  const confirmSignUp = async (username: string, code: string) => {
    try {
      const result = await Auth.confirmSignUp(username, code);
      
      addNotification({
        type: 'success',
        title: 'Account Verified',
        message: 'Your account has been verified. You can now sign in.',
      });
      
      return result;
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'Verification Failed',
        message: error.message || 'Failed to verify account.',
      });
      throw error;
    }
  };

  const resendConfirmationCode = async (username: string) => {
    try {
      await Auth.resendSignUp(username);
      
      addNotification({
        type: 'info',
        title: 'Code Sent',
        message: 'A new verification code has been sent to your email.',
      });
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'Failed to Send Code',
        message: error.message || 'Failed to send verification code.',
      });
      throw error;
    }
  };

  const forgotPassword = async (username: string) => {
    try {
      await Auth.forgotPassword(username);
      
      addNotification({
        type: 'info',
        title: 'Reset Code Sent',
        message: 'Password reset code has been sent to your email.',
      });
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'Reset Failed',
        message: error.message || 'Failed to send reset code.',
      });
      throw error;
    }
  };

  const forgotPasswordSubmit = async (username: string, code: string, newPassword: string) => {
    try {
      await Auth.forgotPasswordSubmit(username, code, newPassword);
      
      addNotification({
        type: 'success',
        title: 'Password Reset',
        message: 'Your password has been reset successfully.',
      });
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'Reset Failed',
        message: error.message || 'Failed to reset password.',
      });
      throw error;
    }
  };

  const changePassword = async (oldPassword: string, newPassword: string) => {
    try {
      const cognitoUser = await Auth.currentAuthenticatedUser();
      await Auth.changePassword(cognitoUser, oldPassword, newPassword);
      
      addNotification({
        type: 'success',
        title: 'Password Changed',
        message: 'Your password has been changed successfully.',
      });
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'Change Failed',
        message: error.message || 'Failed to change password.',
      });
      throw error;
    }
  };

  const setupMFA = async (): Promise<string> => {
    try {
      const cognitoUser = await Auth.currentAuthenticatedUser();
      const secretCode = await Auth.setupTOTP(cognitoUser);
      
      return secretCode;
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'MFA Setup Failed',
        message: error.message || 'Failed to set up MFA.',
      });
      throw error;
    }
  };

  const confirmMFA = async (code: string) => {
    try {
      const cognitoUser = await Auth.currentAuthenticatedUser();
      await Auth.verifyTotpToken(cognitoUser, code);
      await Auth.setPreferredMFA(cognitoUser, 'TOTP');
      
      addNotification({
        type: 'success',
        title: 'MFA Enabled',
        message: 'Multi-factor authentication has been enabled.',
      });
    } catch (error: any) {
      addNotification({
        type: 'error',
        title: 'MFA Confirmation Failed',
        message: error.message || 'Failed to confirm MFA setup.',
      });
      throw error;
    }
  };

  const refreshToken = async () => {
    try {
      const cognitoUser = await Auth.currentAuthenticatedUser();
      const session = await Auth.currentSession();
      
      if (session.isValid()) {
        // Token is still valid, update user profile if needed
        const userProfile = await getUserProfile(cognitoUser);
        setUser(userProfile);
        setGlobalUser(userProfile);
      }
    } catch (error) {
      // Token refresh failed, sign out user
      await signOut();
    }
  };

  const contextValue: AuthContextType = {
    isAuthenticated,
    isLoading,
    user,
    signIn,
    signUp,
    signOut,
    confirmSignUp,
    resendConfirmationCode,
    forgotPassword,
    forgotPasswordSubmit,
    changePassword,
    setupMFA,
    confirmMFA,
    refreshToken,
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};