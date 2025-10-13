export const authConfig = {
  region: 'us-east-1',
  userPoolId: 'us-east-1_example',
  userPoolWebClientId: 'example-client-id',
};

export const tokenConfig = {
  accessTokenExpiry: 3600, // 1 hour
  refreshTokenExpiry: 86400, // 24 hours
};

export const mfaConfig = {
  enabled: true,
  methods: ['SMS', 'TOTP'],
};