// User roles in the system
export type UserRole = 'viewer' | 'creator' | 'moderator' | 'admin' | 'developer';

// Subscription tiers
export type SubscriptionTier = 'bronze' | 'silver' | 'gold' | 'platinum';

// User information interface
export interface AuthUser {
  username: string;
  email: string;
  emailVerified: boolean;
  displayName: string;
  role: UserRole;
  subscriptionTier: SubscriptionTier;
  createdAt: string;
  lastLogin: string;
}

// Authentication state
export interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  user: AuthUser | null;
  error: string | null;
}

// Authentication context type
export interface AuthContextType extends AuthState {
  login: (username: string, password: string) => Promise<void>;
  register: (
    username: string,
    email: string,
    password: string,
    displayName?: string,
    subscriptionTier?: SubscriptionTier
  ) => Promise<void>;
  logout: () => Promise<void>;
  refreshToken: () => Promise<void>;
  updateProfile: (updates: Partial<AuthUser>) => Promise<void>;
  hasRole: (role: UserRole) => boolean;
  hasSubscription: (tier: SubscriptionTier) => boolean;
  canAccess: (requiredRole?: UserRole, requiredSubscription?: SubscriptionTier) => boolean;
  getAuthHeaders: () => Record<string, string>;
}

// Route protection configuration
export interface RouteProtection {
  requireAuth?: boolean;
  requiredRole?: UserRole;
  requiredSubscription?: SubscriptionTier;
  redirectTo?: string;
}

// Login form data
export interface LoginFormData {
  username: string;
  password: string;
  rememberMe?: boolean;
}

// Registration form data
export interface RegisterFormData {
  username: string;
  email: string;
  password: string;
  confirmPassword: string;
  displayName?: string;
  subscriptionTier?: SubscriptionTier;
  acceptTerms: boolean;
}

// Password reset form data
export interface PasswordResetFormData {
  email: string;
}

// Password confirmation form data
export interface PasswordConfirmFormData {
  confirmationCode: string;
  newPassword: string;
  confirmPassword: string;
}

// Profile update form data
export interface ProfileUpdateFormData {
  displayName?: string;
  email?: string;
  currentPassword?: string;
  newPassword?: string;
  confirmPassword?: string;
}

// API response types
export interface AuthApiResponse {
  success: boolean;
  message: string;
  data?: any;
  error?: string;
}

export interface TokenRefreshResponse {
  tokens: {
    access_token: string;
    id_token: string;
    token_type: string;
    expires_in: number;
  };
}

// Permission checking utilities
export const ROLE_HIERARCHY: Record<UserRole, number> = {
  viewer: 1,
  creator: 2,
  moderator: 3,
  admin: 4,
  developer: 5
};

export const SUBSCRIPTION_HIERARCHY: Record<SubscriptionTier, number> = {
  bronze: 1,
  silver: 2,
  gold: 3,
  platinum: 4
};

// Helper functions
export const hasRoleOrHigher = (userRole: UserRole, requiredRole: UserRole): boolean => {
  return ROLE_HIERARCHY[userRole] >= ROLE_HIERARCHY[requiredRole];
};

export const hasSubscriptionOrHigher = (
  userTier: SubscriptionTier,
  requiredTier: SubscriptionTier
): boolean => {
  return SUBSCRIPTION_HIERARCHY[userTier] >= SUBSCRIPTION_HIERARCHY[requiredTier];
};

// Route configuration for different user types
export const ROUTE_PERMISSIONS: Record<string, RouteProtection> = {
  // Public routes
  '/': { requireAuth: false },
  '/login': { requireAuth: false },
  '/register': { requireAuth: false },
  '/forgot-password': { requireAuth: false },
  
  // Viewer routes
  '/viewer': { requireAuth: true, requiredRole: 'viewer' },
  '/streams': { requireAuth: true, requiredRole: 'viewer' },
  '/profile': { requireAuth: true, requiredRole: 'viewer' },
  
  // Creator routes
  '/creator': { requireAuth: true, requiredRole: 'creator' },
  '/creator/dashboard': { requireAuth: true, requiredRole: 'creator' },
  '/creator/stream': { requireAuth: true, requiredRole: 'creator' },
  '/creator/analytics': { requireAuth: true, requiredRole: 'creator' },
  
  // Admin routes
  '/admin': { requireAuth: true, requiredRole: 'admin' },
  '/admin/users': { requireAuth: true, requiredRole: 'admin' },
  '/admin/moderation': { requireAuth: true, requiredRole: 'moderator' },
  '/admin/analytics': { requireAuth: true, requiredRole: 'admin' },
  
  // Support routes
  '/support': { requireAuth: true, requiredRole: 'viewer' },
  '/support/tickets': { requireAuth: true, requiredRole: 'viewer' },
  '/support/chat': { requireAuth: true, requiredRole: 'viewer' },
  
  // Developer routes
  '/developer': { requireAuth: true, requiredRole: 'developer' },
  '/developer/console': { requireAuth: true, requiredRole: 'developer' },
  '/developer/api': { requireAuth: true, requiredRole: 'developer' },
  
  // Premium content routes
  '/premium': { requireAuth: true, requiredSubscription: 'silver' },
  '/premium/exclusive': { requireAuth: true, requiredSubscription: 'gold' },
  '/premium/vip': { requireAuth: true, requiredSubscription: 'platinum' }
};