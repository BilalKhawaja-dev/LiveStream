// Validate environment variables
const validateConfig = () => {
  const requiredEnvVars = {
    region: process.env.REACT_APP_AWS_REGION || 'eu-west-2',
    userPoolId: process.env.REACT_APP_USER_POOL_ID || 'eu-west-2_example',
    userPoolWebClientId: process.env.REACT_APP_USER_POOL_CLIENT_ID || 'example-client-id',
  };

  // Validate region format
  if (!/^[a-z]{2}-[a-z]+-\d+$/.test(requiredEnvVars.region)) {
    throw new Error('Invalid AWS region format');
  }

  // Validate user pool ID format
  if (!/^[a-z]{2}-[a-z]+-\d+_[a-zA-Z0-9]+$/.test(requiredEnvVars.userPoolId)) {
    console.warn('User Pool ID format may be invalid');
  }

  return requiredEnvVars;
};

export const authConfig = validateConfig();

export const tokenConfig = {
  accessTokenExpiry: parseInt(process.env.REACT_APP_ACCESS_TOKEN_EXPIRY || '3600', 10), // 1 hour
  refreshTokenExpiry: parseInt(process.env.REACT_APP_REFRESH_TOKEN_EXPIRY || '86400', 10), // 24 hours
};

export const mfaConfig = {
  enabled: process.env.REACT_APP_MFA_ENABLED !== 'false',
  methods: (process.env.REACT_APP_MFA_METHODS || 'SMS,TOTP').split(','),
};