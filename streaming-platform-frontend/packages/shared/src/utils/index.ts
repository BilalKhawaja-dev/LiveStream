import { format, formatDistanceToNow } from 'date-fns';
import { SubscriptionTier, UserRole } from '../types';

// Date utilities
export const formatDate = (date: Date | string, formatStr = 'PPP') => {
  const dateObj = typeof date === 'string' ? new Date(date) : date;
  return format(dateObj, formatStr);
};

export const formatRelativeTime = (date: Date | string) => {
  const dateObj = typeof date === 'string' ? new Date(date) : date;
  return formatDistanceToNow(dateObj, { addSuffix: true });
};

// Subscription utilities
export const getSubscriptionFeatures = (tier: SubscriptionTier) => {
  const features = {
    bronze: {
      quality: '720p',
      streams: 1,
      storage: '10GB',
      support: 'Community',
      price: 9.99,
    },
    silver: {
      quality: '1080p',
      streams: 3,
      storage: '50GB',
      support: 'Email',
      price: 19.99,
    },
    gold: {
      quality: '4K',
      streams: 10,
      storage: '200GB',
      support: 'Priority',
      price: 39.99,
    },
  };
  
  return features[tier];
};

export const canAccessFeature = (userTier: SubscriptionTier, requiredTier: SubscriptionTier) => {
  const tierLevels = { bronze: 1, silver: 2, gold: 3 };
  return tierLevels[userTier] >= tierLevels[requiredTier];
};

// Role utilities
export const getRolePermissions = (role: UserRole) => {
  const permissions = {
    viewer: ['view_streams', 'chat', 'subscribe'],
    creator: ['view_streams', 'chat', 'subscribe', 'create_streams', 'manage_content', 'view_analytics'],
    admin: ['*'], // All permissions
    support: ['view_users', 'manage_tickets', 'view_logs', 'moderate_content'],
    analyst: ['view_analytics', 'export_data', 'create_reports'],
    developer: ['view_logs', 'debug_system', 'manage_deployments', 'view_metrics'],
  };
  
  return permissions[role] || [];
};

export const hasPermission = (userRole: UserRole, permission: string) => {
  const permissions = getRolePermissions(userRole);
  return permissions.includes('*') || permissions.includes(permission);
};

// URL utilities
export const buildApiUrl = (endpoint: string, params?: Record<string, any>) => {
  const baseUrl = process.env.REACT_APP_API_BASE_URL || 'https://api.streaming-platform.com';
  const url = new URL(endpoint, baseUrl);
  
  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        url.searchParams.append(key, String(value));
      }
    });
  }
  
  return url.toString();
};

// Error handling utilities
export const getErrorMessage = (error: any): string => {
  if (typeof error === 'string') return error;
  if (error?.message) return error.message;
  if (error?.error?.message) return error.error.message;
  return 'An unexpected error occurred';
};

export const isNetworkError = (error: any): boolean => {
  return (
    error?.code === 'NETWORK_ERROR' ||
    error?.message?.includes('fetch') ||
    error?.message?.includes('network') ||
    !navigator.onLine
  );
};

// Validation utilities
export const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

export const validatePassword = (password: string): { valid: boolean; errors: string[] } => {
  const errors: string[] = [];
  
  if (password.length < 8) {
    errors.push('Password must be at least 8 characters long');
  }
  
  if (!/[A-Z]/.test(password)) {
    errors.push('Password must contain at least one uppercase letter');
  }
  
  if (!/[a-z]/.test(password)) {
    errors.push('Password must contain at least one lowercase letter');
  }
  
  if (!/\d/.test(password)) {
    errors.push('Password must contain at least one number');
  }
  
  if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
    errors.push('Password must contain at least one special character');
  }
  
  return { valid: errors.length === 0, errors };
};

// Stream utilities
export const getStreamQualityUrl = (streamData: any, userTier: SubscriptionTier): string => {
  const qualityUrls = streamData.quality || {};
  
  switch (userTier) {
    case 'gold':
      return qualityUrls.gold || qualityUrls.silver || qualityUrls.bronze;
    case 'silver':
      return qualityUrls.silver || qualityUrls.bronze;
    case 'bronze':
    default:
      return qualityUrls.bronze;
  }
};

export const formatViewerCount = (count: number): string => {
  try {
    if (typeof count !== 'number' || isNaN(count)) {
      // Use secure logging to prevent log injection
      import('./secureLogger').then(({ secureLogger }) => {
        secureLogger.warn('Invalid count provided to formatViewerCount', { 
          component: 'formatViewerCount',
          providedValue: typeof count 
        });
      });
      return '0';
    }
    
    if (count < 1000) return count.toString();
    if (count < 1000000) return `${(count / 1000).toFixed(1)}K`;
    return `${(count / 1000000).toFixed(1)}M`;
  } catch (error) {
    // Use secure logging to prevent log injection
    import('./secureLogger').then(({ secureLogger }) => {
      secureLogger.error('formatViewerCount error', error, { component: 'formatViewerCount' });
    });
    return '0';
  }
};

export const formatCurrency = (amount: number, currency = 'GBP'): string => {
  try {
    if (typeof amount !== 'number' || isNaN(amount)) {
      // Use secure logging to prevent log injection
      import('./secureLogger').then(({ secureLogger }) => {
        secureLogger.warn('Invalid amount provided to formatCurrency', { 
          component: 'formatCurrency',
          providedValue: typeof amount 
        });
      });
      return '£0.00';
    }

    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency,
    }).format(amount);
  } catch (error) {
    // Use secure logging to prevent log injection
    import('./secureLogger').then(({ secureLogger }) => {
      secureLogger.error('formatCurrency error', error, { component: 'formatCurrency' });
    });
    return `${currency} ${amount.toFixed(2)}`;
  }
};

export const safeParseJSON = <T = any>(jsonString: string, fallback: T): T => {
  try {
    return JSON.parse(jsonString);
  } catch (error) {
    // Use secure logging instead of direct console
    import('./secureLogger').then(({ secureLogger }) => {
      secureLogger.warn('Failed to parse JSON', { action: 'safeParseJSON' });
    });
    return fallback;
  }
};

// Storage utilities
export const getStorageItem = <T>(key: string, defaultValue: T): T => {
  try {
    const item = localStorage.getItem(key);
    return item ? JSON.parse(item) : defaultValue;
  } catch {
    return defaultValue;
  }
};

export const setStorageItem = <T>(key: string, value: T): void => {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (error) {
    // Use secure logging to prevent log injection
    import('./secureLogger').then(({ secureLogger }) => {
      secureLogger.warn('Failed to save to localStorage', { 
        component: 'setStorageItem',
        key: key?.substring(0, 50) // Limit key length for security
      });
    });
  }
};

// Debounce utility
export const debounce = <T extends (...args: any[]) => any>(
  func: T,
  wait: number
): ((...args: Parameters<T>) => void) => {
  let timeout: NodeJS.Timeout;
  
  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
};

// Throttle utility
export const throttle = <T extends (...args: any[]) => any>(
  func: T,
  limit: number
): ((...args: Parameters<T>) => void) => {
  let inThrottle: boolean;
  
  return (...args: Parameters<T>) => {
    if (!inThrottle) {
      func(...args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
};