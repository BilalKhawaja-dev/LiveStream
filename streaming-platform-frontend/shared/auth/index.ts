// Main exports
export { AuthProvider, useAuth, withAuth } from './AuthProvider';
export { CognitoAuth } from './CognitoAuth';
export { TokenManager } from './TokenManager';

// Components
export { LoginForm } from './components/LoginForm';
export { RegisterForm } from './components/RegisterForm';

// Types
export type {
  UserRole,
  SubscriptionTier,
  AuthUser,
  AuthState,
  AuthContextType,
  RouteProtection,
  LoginFormData,
  RegisterFormData,
  PasswordResetFormData,
  PasswordConfirmFormData,
  ProfileUpdateFormData,
  AuthApiResponse,
  TokenRefreshResponse
} from './types';

// Utilities
export {
  ROLE_HIERARCHY,
  SUBSCRIPTION_HIERARCHY,
  ROUTE_PERMISSIONS,
  hasRoleOrHigher,
  hasSubscriptionOrHigher
} from './types';