// Shared types for the streaming platform

export type UserRole = 'viewer' | 'creator' | 'admin' | 'support' | 'analyst' | 'developer';

export type SubscriptionTier = 'bronze' | 'silver' | 'gold';

export type ApplicationType = 
  | 'viewer-portal'
  | 'creator-dashboard' 
  | 'admin-portal'
  | 'support-system'
  | 'analytics-dashboard'
  | 'developer-console';

export interface UserProfile {
  id: string;
  cognitoId: string;
  email: string;
  username: string;
  role: UserRole;
  subscription: {
    tier: SubscriptionTier;
    status: 'active' | 'cancelled' | 'expired';
    renewalDate: Date;
  };
  preferences: {
    theme: 'light' | 'dark';
    language: string;
    notifications: NotificationSettings;
  };
  createdAt: Date;
  lastLogin: Date;
}

export interface NotificationSettings {
  email: boolean;
  push: boolean;
  sms: boolean;
  marketing: boolean;
}

export interface SharedContext {
  user: {
    id: string;
    role: UserRole;
    subscription: SubscriptionTier | {
      tier: SubscriptionTier;
      status: 'active' | 'cancelled' | 'expired';
      renewalDate: Date;
    };
    preferences: UserPreferences;
  };
  navigation: {
    currentApp: ApplicationType;
    previousApp?: ApplicationType;
    contextData?: Record<string, any>;
  };
  notifications: Notification[];
  globalState: {
    isOnline: boolean;
    lastSync: Date;
    activeStreams: number;
  };
}

export interface UserPreferences {
  theme: 'light' | 'dark';
  language: string;
  autoplay: boolean;
  quality: 'auto' | 'high' | 'medium' | 'low';
}

export interface Notification {
  id: string;
  type: 'info' | 'warning' | 'error' | 'success';
  title: string;
  message: string;
  timestamp: Date;
  read: boolean;
  actionUrl?: string;
}

export interface StreamData {
  id: string;
  creatorId: string;
  title: string;
  description: string;
  category: string;
  status: 'live' | 'scheduled' | 'ended';
  mediaLiveChannelId: string;
  mediaStoreEndpoint: string;
  viewerCount: number;
  quality: {
    bronze: string; // 720p URL
    silver: string; // 1080p URL
    gold: string;   // 4K URL
  };
  startTime: Date;
  endTime?: Date;
  metrics: StreamMetrics;
}

export interface StreamMetrics {
  totalViews: number;
  peakViewers: number;
  averageViewTime: number;
  chatMessages: number;
  likes: number;
  shares: number;
}

export interface SupportTicket {
  id: string;
  userId: string;
  creatorId?: string;
  type: 'technical' | 'billing' | 'content' | 'account';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  status: 'open' | 'in_progress' | 'resolved' | 'closed';
  subject: string;
  description: string;
  assignedTo?: string;
  context: {
    userAgent: string;
    url: string;
    streamId?: string;
    errorLogs?: string[];
  };
  aiSuggestions?: string[];
  createdAt: Date;
  updatedAt: Date;
  resolvedAt?: Date;
}

export interface APIResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  meta?: {
    total?: number;
    page?: number;
    limit?: number;
  };
}