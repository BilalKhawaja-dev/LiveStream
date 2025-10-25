import React, { createContext, useContext, useState, useEffect } from 'react';

interface User {
  id: string;
  username: string;
  email: string;
  role: string;
  displayName?: string;
  subscriptionTier?: string;
}

interface AuthContextType {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  isLoading: boolean;
  isAuthenticated: boolean;
  hasSubscription: (tier: string) => boolean;
  updateProfile: (data: Partial<User>) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: React.ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check for existing session
    const checkAuth = async () => {
      try {
        // TODO: Replace with real Cognito integration
        // For now, check localStorage for existing session
        const savedUser = localStorage.getItem('currentUser');
        if (savedUser) {
          setUser(JSON.parse(savedUser));
        }
      } catch (error) {
        // Use secure logging to prevent log injection
        console.error('Auth check failed:', error);
      } finally {
        setIsLoading(false);
      }
    };

    checkAuth();
  }, []);

  const login = async (email: string, password: string) => {
    setIsLoading(true);
    try {
      // Call the backend API for authentication
      const response = await fetch(`${process.env.REACT_APP_API_BASE_URL}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username: email, password }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Login failed');
      }

      const authData = await response.json();
      
      // Store tokens
      localStorage.setItem('accessToken', authData.access_token);
      localStorage.setItem('refreshToken', authData.refresh_token);
      
      // Create user object from auth data
      const user: User = {
        id: authData.user?.id || email,
        username: authData.user?.username || email,
        email: authData.user?.email || email,
        role: authData.user?.role || 'viewer',
        displayName: authData.user?.displayName || email,
        subscriptionTier: authData.user?.subscription_tier || 'bronze',
      };
      
      setUser(user);
      localStorage.setItem('currentUser', JSON.stringify(user));
    } catch (error) {
      // Use secure logging to prevent log injection
      console.error('Login failed:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = async () => {
    try {
      const accessToken = localStorage.getItem('accessToken');
      if (accessToken) {
        // Call logout endpoint
        await fetch(`${process.env.REACT_APP_API_BASE_URL}/auth/logout`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
          },
          body: JSON.stringify({ access_token: accessToken }),
        });
      }
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      // Clear local storage
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('currentUser');
      setUser(null);
    }
  };

  const hasSubscription = (tier: string): boolean => {
    if (!user?.subscriptionTier) return false;
    
    const tiers = ['bronze', 'silver', 'gold'];
    const userTierIndex = tiers.indexOf(user.subscriptionTier);
    const requiredTierIndex = tiers.indexOf(tier);
    
    return userTierIndex >= requiredTierIndex;
  };

  const updateProfile = async (data: Partial<User>): Promise<void> => {
    if (!user) throw new Error('No user logged in');
    
    setIsLoading(true);
    try {
      // Mock profile update
      await new Promise(resolve => setTimeout(resolve, 500));
      setUser({ ...user, ...data });
    } catch (error) {
      console.error('Profile update failed:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const value = {
    user,
    login,
    logout,
    isLoading,
    isAuthenticated: !!user,
    hasSubscription,
    updateProfile,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};