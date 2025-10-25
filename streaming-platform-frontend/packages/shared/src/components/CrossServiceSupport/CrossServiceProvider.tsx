import React, { createContext, useContext, useEffect, useState } from 'react';
import { useAuth } from '../../auth/AuthProvider';
import { secureLogger } from '../../utils/secureLogger';

interface ServiceConfig {
  name: string;
  url: string;
  port: number;
  theme: 'blue' | 'purple' | 'pink';
  icon: string;
}

interface CrossServiceContextType {
  currentService: string;
  services: Record<string, ServiceConfig>;
  navigateToService: (serviceName: string, path?: string, context?: any) => void;
  preserveContext: (context: any) => void;
  getStoredContext: () => any;
  isServiceAvailable: (serviceName: string) => boolean;
}

const CrossServiceContext = createContext<CrossServiceContextType | undefined>(undefined);

const DEFAULT_SERVICES: Record<string, ServiceConfig> = {
  'viewer-portal': {
    name: 'Viewer Portal',
    url: process.env.REACT_APP_VIEWER_PORTAL_URL || `${window.location.protocol}//${window.location.hostname}:3000`,
    port: 3000,
    theme: 'purple',
    icon: '📺'
  },
  'creator-dashboard': {
    name: 'Creator Dashboard',
    url: process.env.REACT_APP_CREATOR_DASHBOARD_URL || `${window.location.protocol}//${window.location.hostname}:3001`,
    port: 3001,
    theme: 'purple',
    icon: '🎥'
  },
  'admin-portal': {
    name: 'Admin Portal',
    url: process.env.REACT_APP_ADMIN_PORTAL_URL || `${window.location.protocol}//${window.location.hostname}:3002`,
    port: 3002,
    theme: 'blue',
    icon: '⚙️'
  },
  'support-system': {
    name: 'Support System',
    url: process.env.REACT_APP_SUPPORT_SYSTEM_URL || `${window.location.protocol}//${window.location.hostname}:3003`,
    port: 3003,
    theme: 'pink',
    icon: '🎧'
  },
  'analytics-dashboard': {
    name: 'Analytics Dashboard',
    url: process.env.REACT_APP_ANALYTICS_DASHBOARD_URL || `${window.location.protocol}//${window.location.hostname}:3004`,
    port: 3004,
    theme: 'blue',
    icon: '📊'
  },
  'developer-console': {
    name: 'Developer Console',
    url: process.env.REACT_APP_DEVELOPER_CONSOLE_URL || `${window.location.protocol}//${window.location.hostname}:3005`,
    port: 3005,
    theme: 'blue',
    icon: '💻'
  }
};

interface CrossServiceProviderProps {
  children: React.ReactNode;
  currentService: string;
  customServices?: Record<string, ServiceConfig>;
}

export const CrossServiceProvider: React.FC<CrossServiceProviderProps> = ({
  children,
  currentService,
  customServices = {}
}) => {
  const { user, token } = useAuth();
  const [services] = useState<Record<string, ServiceConfig>>({
    ...DEFAULT_SERVICES,
    ...customServices
  });
  const [serviceAvailability, setServiceAvailability] = useState<Record<string, boolean>>({});

  // Check service availability on mount
  useEffect(() => {
    checkServiceAvailability();
  }, []);

  const checkServiceAvailability = async () => {
    const availability: Record<string, boolean> = {};
    
    for (const [serviceName, config] of Object.entries(services)) {
      try {
        // Simple health check - try to fetch the service
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 5000);
        
        const response = await fetch(`${config.url}/health`, {
          method: 'GET',
          signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        availability[serviceName] = response.ok;
      } catch (error) {
        availability[serviceName] = false;
      }
    }
    
    setServiceAvailability(availability);
  };

  const preserveContext = (context: any) => {
    try {
      const contextData = {
        ...context,
        timestamp: new Date().toISOString(),
        sourceService: currentService,
        userId: user?.id,
        token: token
      };
      
      sessionStorage.setItem('crossServiceContext', JSON.stringify(contextData));
      secureLogger.info('Context preserved for cross-service navigation', {
        sourceService: currentService,
        contextKeys: Object.keys(context)
      });
    } catch (error) {
      secureLogger.error('Failed to preserve context', { error });
    }
  };

  const getStoredContext = () => {
    try {
      const stored = sessionStorage.getItem('crossServiceContext');
      if (stored) {
        const context = JSON.parse(stored);
        // Clear the context after retrieval to prevent reuse
        sessionStorage.removeItem('crossServiceContext');
        return context;
      }
    } catch (error) {
      secureLogger.error('Failed to retrieve stored context', { error });
    }
    return null;
  };

  const navigateToService = (serviceName: string, path: string = '', context?: any) => {
    try {
      const service = services[serviceName];
      if (!service) {
        throw new Error(`Service ${serviceName} not found`);
      }

      if (!serviceAvailability[serviceName]) {
        secureLogger.warn('Attempting to navigate to unavailable service', { serviceName });
      }

      // Preserve context if provided
      if (context) {
        preserveContext(context);
      }

      // Construct the target URL
      const targetUrl = `${service.url}${path.startsWith('/') ? path : `/${path}`}`;
      
      // Add authentication token as query parameter if available
      const urlWithAuth = token ? 
        `${targetUrl}${targetUrl.includes('?') ? '&' : '?'}token=${encodeURIComponent(token)}` : 
        targetUrl;

      secureLogger.info('Navigating to service', {
        from: currentService,
        to: serviceName,
        path,
        hasContext: !!context
      });

      // Navigate to the service
      window.location.href = urlWithAuth;
      
    } catch (error) {
      secureLogger.error('Failed to navigate to service', {
        serviceName,
        path,
        error
      });
      
      // Fallback navigation
      alert(`Unable to navigate to ${serviceName}. Please try again later.`);
    }
  };

  const isServiceAvailable = (serviceName: string): boolean => {
    return serviceAvailability[serviceName] ?? false;
  };

  const contextValue: CrossServiceContextType = {
    currentService,
    services,
    navigateToService,
    preserveContext,
    getStoredContext,
    isServiceAvailable
  };

  return (
    <CrossServiceContext.Provider value={contextValue}>
      {children}
    </CrossServiceContext.Provider>
  );
};

export const useCrossService = (): CrossServiceContextType => {
  const context = useContext(CrossServiceContext);
  if (!context) {
    throw new Error('useCrossService must be used within a CrossServiceProvider');
  }
  return context;
};

export default CrossServiceProvider;