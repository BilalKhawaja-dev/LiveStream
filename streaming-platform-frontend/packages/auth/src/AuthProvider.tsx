import React, { createContext, useContext, useState, useEffect } from 'react';

interface User {
  id: string;
  username: string;
  email: string;
  role: string;
}

interface AuthContextType {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  isLoading: boolean;
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
        });
      } catch (error) {
        // Use secure logging to prevent log injection
        import('@streaming/shared').then(({ secureLogger }) => {
          secureLogger.error('Auth check failed', error, { component: 'AuthProvider', action: 'checkAuth' });
        });
      } finally {
        setIsLoading(false);
      }
    };

    checkAuth();
  }, []);

  const login = async (email: string, password: string) => {
    setIsLoading(true);
    try {
      // Mock login
      setUser({
        id: '1',
        username: 'testuser',
        email,
        role: 'creator',
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('@streaming/shared').then(({ secureLogger }) => {
        secureLogger.error('Login failed', error, { component: 'AuthProvider', action: 'login' });
      });
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
  };

  const value = {
    user,
    login,
    logout,
    isLoading,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};