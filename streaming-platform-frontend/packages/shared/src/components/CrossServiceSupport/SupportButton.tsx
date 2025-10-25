import React, { useState } from 'react';
import { useAuth } from '../../auth/AuthProvider';
import { secureLogger } from '../../utils/secureLogger';

interface SupportButtonProps {
  context?: {
    service: string;
    page: string;
    userId?: string;
    additionalData?: Record<string, any>;
  };
  variant?: 'floating' | 'inline' | 'header';
  theme?: 'blue' | 'purple' | 'pink';
  size?: 'small' | 'medium' | 'large';
}

interface SupportContext {
  service: string;
  page: string;
  userId?: string;
  userRole?: string;
  timestamp: string;
  sessionId?: string;
  additionalData?: Record<string, any>;
}

export const SupportButton: React.FC<SupportButtonProps> = ({
  context = { service: 'unknown', page: 'unknown' },
  variant = 'floating',
  theme = 'blue',
  size = 'medium'
}) => {
  const { user, isAuthenticated } = useAuth();
  const [isLoading, setIsLoading] = useState(false);

  const handleSupportClick = async () => {
    try {
      setIsLoading(true);
      
      // Prepare support context
      const supportContext: SupportContext = {
        service: context.service,
        page: context.page,
        userId: user?.id || context.userId,
        userRole: user?.role,
        timestamp: new Date().toISOString(),
        sessionId: sessionStorage.getItem('sessionId') || undefined,
        additionalData: {
          ...context.additionalData,
          userAgent: navigator.userAgent,
          url: window.location.href,
          referrer: document.referrer
        }
      };

      // Log support button click
      secureLogger.info('Support button clicked', {
        context: supportContext,
        authenticated: isAuthenticated
      });

      // Store context in sessionStorage for the support system
      sessionStorage.setItem('supportContext', JSON.stringify(supportContext));
      
      // Determine support system URL based on environment
      const supportBaseUrl = process.env.REACT_APP_SUPPORT_URL || 
                            `${window.location.protocol}//${window.location.hostname}:3003`;
      
      // Create support URL with context
      const supportUrl = `${supportBaseUrl}?context=${encodeURIComponent(JSON.stringify(supportContext))}`;
      
      // Open support system in new tab
      const supportWindow = window.open(supportUrl, '_blank', 'width=1200,height=800');
      
      if (!supportWindow) {
        // Fallback if popup blocked
        window.location.href = supportUrl;
      }
      
    } catch (error) {
      secureLogger.error('Error opening support system', { error });
      // Fallback to basic support URL
      window.open('/support', '_blank');
    } finally {
      setIsLoading(false);
    }
  };

  const getButtonStyles = () => {
    const baseStyles = 'transition-all duration-200 font-medium rounded-lg shadow-lg hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-offset-2';
    
    const themeStyles = {
      blue: 'bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-500',
      purple: 'bg-purple-600 hover:bg-purple-700 text-white focus:ring-purple-500',
      pink: 'bg-pink-600 hover:bg-pink-700 text-white focus:ring-pink-500'
    };
    
    const sizeStyles = {
      small: 'px-3 py-1.5 text-sm',
      medium: 'px-4 py-2 text-base',
      large: 'px-6 py-3 text-lg'
    };
    
    const variantStyles = {
      floating: 'fixed bottom-6 right-6 z-50 rounded-full p-3',
      inline: 'inline-flex items-center',
      header: 'inline-flex items-center'
    };
    
    return `${baseStyles} ${themeStyles[theme]} ${sizeStyles[size]} ${variantStyles[variant]}`;
  };

  const getButtonContent = () => {
    if (variant === 'floating') {
      return (
        <div className="flex items-center justify-center">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
          </svg>
        </div>
      );
    }
    
    return (
      <div className="flex items-center space-x-2">
        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
        </svg>
        <span>Support</span>
      </div>
    );
  };

  return (
    <button
      onClick={handleSupportClick}
      disabled={isLoading}
      className={getButtonStyles()}
      title="Get Support"
      aria-label="Open support system"
    >
      {isLoading ? (
        <div className="flex items-center space-x-2">
          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
          {variant !== 'floating' && <span>Loading...</span>}
        </div>
      ) : (
        getButtonContent()
      )}
    </button>
  );
};

export default SupportButton;