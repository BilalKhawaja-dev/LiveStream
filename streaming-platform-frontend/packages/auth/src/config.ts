// AWS Cognito configuration
export const authConfig = {
  region: process.env.REACT_APP_AWS_REGION || 'eu-west-2',
  userPoolId: process.env.REACT_APP_COGNITO_USER_POOL_ID || '',
  userPoolWebClientId: process.env.REACT_APP_COGNITO_CLIENT_ID || '',
  identityPoolId: process.env.REACT_APP_COGNITO_IDENTITY_POOL_ID || '',
  mandatorySignIn: true,
  authenticationFlowType: 'USER_SRP_AUTH',
  oauth: {
    domain: process.env.REACT_APP_COGNITO_DOMAIN || '',
    scope: ['email', 'openid', 'profile'],
    redirectSignIn: process.env.REACT_APP_OAUTH_REDIRECT_SIGNIN || 'http://localhost:3000/',
    redirectSignOut: process.env.REACT_APP_OAUTH_REDIRECT_SIGNOUT || 'http://localhost:3000/',
    responseType: 'code',
  },
};

// JWT token configuration
export const tokenConfig = {
  accessTokenExpiry: 12 * 60 * 60 * 1000, // 12 hours in milliseconds
  refreshTokenExpiry: 30 * 24 * 60 * 60 * 1000, // 30 days in milliseconds
  tokenRefreshThreshold: 5 * 60 * 1000, // Refresh 5 minutes before expiry
};

// MFA configuration
export const mfaConfig = {
  requiredForRoles: ['creator', 'admin', 'support', 'developer'],
  optionalForRoles: ['viewer', 'analyst'],
  totpIssuer: 'StreamingPlatform',
};