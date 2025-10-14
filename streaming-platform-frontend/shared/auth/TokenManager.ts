export interface TokenSet {
  accessToken: string;
  idToken: string;
  refreshToken: string;
}

export class TokenManager {
  private apiBaseUrl: string;
  private refreshInterval: NodeJS.Timeout | null = null;
  private readonly STORAGE_KEYS = {
    ACCESS_TOKEN: 'streaming_access_token',
    ID_TOKEN: 'streaming_id_token',
    REFRESH_TOKEN: 'streaming_refresh_token',
    TOKEN_EXPIRY: 'streaming_token_expiry'
  };

  constructor(apiBaseUrl: string) {
    this.apiBaseUrl = apiBaseUrl;
  }

  setTokens(tokens: TokenSet): void {
    try {
      // Store tokens securely
      localStorage.setItem(this.STORAGE_KEYS.ACCESS_TOKEN, tokens.accessToken);
      localStorage.setItem(this.STORAGE_KEYS.ID_TOKEN, tokens.idToken);
      localStorage.setItem(this.STORAGE_KEYS.REFRESH_TOKEN, tokens.refreshToken);

      // Calculate and store expiry time (JWT tokens typically expire in 1 hour)
      const expiryTime = Date.now() + (55 * 60 * 1000); // 55 minutes to be safe
      localStorage.setItem(this.STORAGE_KEYS.TOKEN_EXPIRY, expiryTime.toString());
    } catch (error) {
      console.error('Error storing tokens:', error);
    }
  }

  getAccessToken(): string | null {
    try {
      return localStorage.getItem(this.STORAGE_KEYS.ACCESS_TOKEN);
    } catch (error) {
      console.error('Error retrieving access token:', error);
      return null;
    }
  }

  getIdToken(): string | null {
    try {
      return localStorage.getItem(this.STORAGE_KEYS.ID_TOKEN);
    } catch (error) {
      console.error('Error retrieving ID token:', error);
      return null;
    }
  }

  getRefreshToken(): string | null {
    try {
      return localStorage.getItem(this.STORAGE_KEYS.REFRESH_TOKEN);
    } catch (error) {
      console.error('Error retrieving refresh token:', error);
      return null;
    }
  }

  clearTokens(): void {
    try {
      Object.values(this.STORAGE_KEYS).forEach(key => {
        localStorage.removeItem(key);
      });
      
      if (this.refreshInterval) {
        clearInterval(this.refreshInterval);
        this.refreshInterval = null;
      }
    } catch (error) {
      console.error('Error clearing tokens:', error);
    }
  }

  isTokenExpired(): boolean {
    try {
      const expiryTime = localStorage.getItem(this.STORAGE_KEYS.TOKEN_EXPIRY);
      if (!expiryTime) {
        return true;
      }
      return Date.now() >= parseInt(expiryTime);
    } catch (error) {
      console.error('Error checking token expiry:', error);
      return true;
    }
  }

  shouldRefreshToken(): boolean {
    try {
      const expiryTime = localStorage.getItem(this.STORAGE_KEYS.TOKEN_EXPIRY);
      if (!expiryTime) {
        return false;
      }
      // Refresh if token expires within 5 minutes
      const refreshThreshold = Date.now() + (5 * 60 * 1000);
      return parseInt(expiryTime) <= refreshThreshold;
    } catch (error) {
      console.error('Error checking refresh threshold:', error);
      return false;
    }
  }

  async refreshTokens(): Promise<TokenSet | null> {
    try {
      const refreshToken = this.getRefreshToken();
      if (!refreshToken) {
        throw new Error('No refresh token available');
      }

      const response = await fetch(`${this.apiBaseUrl}/auth/refresh`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          refresh_token: refreshToken
        })
      });

      if (!response.ok) {
        throw new Error(`Token refresh failed: ${response.status}`);
      }

      const data = await response.json();
      
      if (data.tokens) {
        const newTokens: TokenSet = {
          accessToken: data.tokens.access_token,
          idToken: data.tokens.id_token,
          refreshToken: refreshToken // Refresh token usually doesn't change
        };

        this.setTokens(newTokens);
        return newTokens;
      }

      throw new Error('Invalid refresh response');
    } catch (error) {
      console.error('Token refresh error:', error);
      this.clearTokens();
      return null;
    }
  }

  startAutoRefresh(): NodeJS.Timeout | null {
    // Check every minute if tokens need refreshing
    this.refreshInterval = setInterval(async () => {
      if (this.shouldRefreshToken()) {
        await this.refreshTokens();
      }
    }, 60 * 1000); // 1 minute

    return this.refreshInterval;
  }

  stopAutoRefresh(): void {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
      this.refreshInterval = null;
    }
  }

  // Utility method to add auth headers to fetch requests
  getAuthHeaders(): Record<string, string> {
    const token = this.getAccessToken();
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  // Enhanced fetch wrapper with automatic token refresh
  async authenticatedFetch(url: string, options: RequestInit = {}): Promise<Response> {
    // Check if token needs refresh before making request
    if (this.shouldRefreshToken()) {
      await this.refreshTokens();
    }

    const authHeaders = this.getAuthHeaders();
    const enhancedOptions: RequestInit = {
      ...options,
      headers: {
        ...authHeaders,
        ...options.headers
      }
    };

    let response = await fetch(url, enhancedOptions);

    // If we get a 401, try refreshing the token once
    if (response.status === 401) {
      const refreshed = await this.refreshTokens();
      if (refreshed) {
        const newAuthHeaders = this.getAuthHeaders();
        enhancedOptions.headers = {
          ...newAuthHeaders,
          ...options.headers
        };
        response = await fetch(url, enhancedOptions);
      }
    }

    return response;
  }

  // Decode JWT token payload (client-side only, don't trust for security)
  decodeToken(token: string): any {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(
        atob(base64)
          .split('')
          .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
          .join('')
      );
      return JSON.parse(jsonPayload);
    } catch (error) {
      console.error('Error decoding token:', error);
      return null;
    }
  }

  // Get user info from ID token
  getUserInfoFromToken(): any {
    const idToken = this.getIdToken();
    if (!idToken) {
      return null;
    }
    return this.decodeToken(idToken);
  }

  // Check if user has specific role
  hasRole(role: string): boolean {
    const userInfo = this.getUserInfoFromToken();
    return userInfo && userInfo['custom:role'] === role;
  }

  // Check if user has specific subscription tier
  hasSubscriptionTier(tier: string): boolean {
    const userInfo = this.getUserInfoFromToken();
    return userInfo && userInfo['custom:subscription_tier'] === tier;
  }
}