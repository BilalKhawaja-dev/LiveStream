import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { CognitoAuth } from './CognitoAuth';
import { TokenManager } from './TokenManager';
import { UserRole, SubscriptionTier, AuthUser, AuthState, AuthContextType } from './types';

// Create Auth Context
const AuthContext = createContext<AuthContextType | undefined>(undefined);

// Auth Provider Props
interface AuthProviderProps {
  children: React.ReactNode;
  cognitoConfig: {
    userPoolId: string;
    userPoolClientId: string;
    region: string;
  };
  apiBaseUrl: string;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({
  children,
  cognitoConfig,
  apiBaseUrl
}) => {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
    user: null,
    error: null
  });

  const cognitoAuth = new CognitoAuth(cognitoConfig);
  const tokenManager = new TokenManager(apiBaseUrl);

  // Initialize authentication state
  useEffect(() => {
    initializeAuth();
  }, []);

  // Set up token refresh interval
  useEffect(() => {
    if (authState.isAuthenticated) {
      const refreshInterval = tokenManager.startAutoRefresh();
      return () => {
        if (refreshInterval) {
          clearInterval(refreshInterval);
        }
      };
    }
  }, [authState.isAuthenticated]);

  const initializeAuth = async () => {
    try {
      setAuthState(prev => ({ ...prev, isLoading: true, error: null }));

      // Check for existing session
      const session = await cognitoAuth.getCurrentSession();
      
      if (session && session.isValid()) {
        const user = await cognitoAuth.getCurrentUser();
        const userInfo = await cognitoAuth.getUserInfo(user);
        
        // Store tokens
        tokenManager.setTokens({
          accessToken: session.getAccessToken().getJwtToken(),
          idToken: session.getIdToken().getJwtToken(),
          refreshToken: session.getRefreshToken().getToken()
        });

        setAuthState({
          isAuthenticated: true,
          isLoading: false,
          user: userInfo,
          error: null
        });
      } else {
        setAuthState({
          isAuthenticated: false,
          isLoading: false,
          user: null,
          error: null
        });
      }
    } catch (error) {
      console.error('Auth initialization error:', error);
      setAuthState({
        isAuthenticated: false,
        isLoading: false,
        user: null,
        error: error instanceof Error ? error.message : 'Authentication initialization failed'
      });
    }
  };

  const login = async (username: string, password: string): Promise<void> => {
    try {
      setAuthState(prev => ({ ...prev, isLoading: true, error: null }));

      const result = await cognitoAuth.signIn(username, password);
      
      if (result.challengeName) {
        // Handle MFA or other challenges
        throw new Error(`Authentication challenge required: ${result.challengeName}`);
      }

      const user = await cognitoAuth.getCurrentUser();
      const userInfo = await cognitoAuth.getUserInfo(user);
      
      // Store tokens
      tokenManager.setTokens({
        accessToken: result.signInUserSession.getAccessToken().getJwtToken(),
        idToken: result.signInUserSession.getIdToken().getJwtToken(),
        refreshToken: result.signInUserSession.getRefreshToken().getToken()
      });

      setAuthState({
        isAuthenticated: true,
        isLoading: false,
        user: userInfo,
        error: null
      });
    } catch (error) {
      console.error('Login error:', error);
      setAuthState(prev => ({
        ...prev,
        isLoading: false,
        error: error instanceof Error ? error.message : 'Login failed'
      }));
      throw error;
    }
  };

  const register = async (
    username: string,
    email: string,
    password: string,
    displayName?: string,
    subscriptionTier: SubscriptionTier = 'bronze'
  ): Promise<void> => {
    try {
      setAuthState(prev => ({ ...prev, isLoading: true, error: null }));

      await cognitoAuth.signUp(username, email, password, {
        'custom:display_name': displayName || username,
        'custom:subscription_tier': subscriptionTier,
        'custom:role': 'viewer'
      });

      // Note: User will need to verify email before they can sign in
      setAuthState(prev => ({
        ...prev,
        isLoading: false,
        error: null
      }));
    } catch (error) {
      console.error('Registration error:', error);
      setAuthState(prev => ({
        ...prev,
        isLoading: false,
        error: error instanceof Error ? error.message : 'Registration failed'
      }));
      throw error;
    }
  };

  const logout = async (): Promise<void> => {
    try {
      setAuthState(prev => ({ ...prev, isLoading: true, error: null }));

      await cognitoAuth.signOut();
      tokenManager.clearTokens();

      setAuthState({
        isAuthenticated: false,
        isLoading: false,
        user: null,
        error: null
      });
    } catch (error) {
      console.error('Logout error:', error);
      // Even if logout fails, clear local state
      tokenManager.clearTokens();
      setAuthState({
        isAuthenticated: false,
        isLoading: false,
        user: null,
        error: error instanceof Error ? error.message : 'Logout failed'
      });
    }
  };

  const refreshToken = async (): Promise<void> => {
    try {
      const newTokens = await tokenManager.refreshTokens();
      
      if (newTokens) {
        // Update user info if needed
        const user = await cognitoAuth.getCurrentUser();
        if (user) {
          const userInfo = await cognitoAuth.getUserInfo(user);
          setAuthState(prev => ({
            ...prev,
            user: userInfo
          }));
        }
      }
    } catch (error) {
      console.error('Token refresh error:', error);
      // If refresh fails, log out the user
      await logout();
    }
  };

  const updateProfile = async (updates: Partial<AuthUser>): Promise<void> => {
    try {
      setAuthState(prev => ({ ...prev, isLoading: true, error: null }));

      const user = await cognitoAuth.getCurrentUser();
      if (!user) {
        throw new Error('No authenticated user');
      }

      await cognitoAuth.updateUserAttributes(user, updates);
      
      // Refresh user info
      const updatedUserInfo = await cognitoAuth.getUserInfo(user);
      
      setAuthState(prev => ({
        ...prev,
        isLoading: false,
        user: updatedUserInfo,
        error: null
      }));
    } catch (error) {
      console.error('Profile update error:', error);
      setAuthState(prev => ({
        ...prev,
        isLoading: false,
        error: error instanceof Error ? error.message : 'Profile update failed'
      }));
      throw error;
    }
  };

  const hasRole = useCallback((role: UserRole): boolean => {
    return authState.user?.role === role;
  }, [authState.user?.role]);

  const hasSubscription = useCallback((tier: SubscriptionTier): boolean => {
    const tierHierarchy: Record<SubscriptionTier, number> = {
      bronze: 1,
      silver: 2,
      gold: 3,
      platinum: 4
    };
    
    const userTier = authState.user?.subscriptionTier || 'bronze';
    return tierHierarchy[userTier] >= tierHierarchy[tier];
  }, [authState.user?.subscriptionTier]);

  const canAccess = useCallback((requiredRole?: UserRole, requiredSubscription?: SubscriptionTier): boolean => {
    if (!authState.isAuthenticated) {
      return false;
    }

    if (requiredRole && !hasRole(requiredRole)) {
      return false;
    }

    if (requiredSubscription && !hasSubscription(requiredSubscription)) {
      return false;
    }

    return true;
  }, [authState.isAuthenticated, hasRole, hasSubscription]);

  const getAuthHeaders = useCallback((): Record<string, string> => {
    const token = tokenManager.getAccessToken();
    return token ? { Authorization: `Bearer ${token}` } : {};
  }, []);

  const contextValue: AuthContextType = {
    ...authState,
    login,
    register,
    logout,
    refreshToken,
    updateProfile,
    hasRole,
    hasSubscription,
    canAccess,
    getAuthHeaders
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
};

// Custom hook to use auth context
export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

// Higher-order component for route protection
export const withAuth = <P extends object>(
  Component: React.ComponentType<P>,
  requiredRole?: UserRole,
  requiredSubscription?: SubscriptionTier
) => {
  return (props: P) => {
    const { isAuthenticated, isLoading, canAccess } = useAuth();

    if (isLoading) {
      return (
        <div className="flex items-center justify-center min-h-screen">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500"></div>
        </div>
      );
    }

    if (!isAuthenticated || !canAccess(requiredRole, requiredSubscription)) {
      return (
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-center">
            <h1 className="text-2xl font-bold text-gray-900 mb-4">Access Denied</h1>
            <p className="text-gray-600 mb-4">
              You don't have permission to access this page.
            </p>
            <button
              onClick={() => window.location.href = '/login'}
              className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
            >
              Go to Login
            </button>
          </div>
        </div>
      );
    }

    return <Component {...props} />;
  };
};