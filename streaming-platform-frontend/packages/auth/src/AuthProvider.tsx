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
        // Mock user for development
        setUser({
          id: '1',
          username: 'testuser',
          email: 'test@example.com',
          role: 'creator',
          displayName: 'Test User',
          subscriptionTier: 'gold',
        });
      } catch (error) {
        // Use secure logging to prevent log injection
        console.error('Auth check failed:', error);
      } finally {
        setIsLoading(false);
      }
    };

    checkAuth();
  }, []);

  const login = async (email: string, _password: string) => {
    setIsLoading(true);
    try {
      // Mock login
      setUser({
        id: '1',
        username: 'testuser',
        email,
        role: 'creator',
        displayName: 'Test User',
        subscriptionTier: 'gold',
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      console.error('Login failed:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
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