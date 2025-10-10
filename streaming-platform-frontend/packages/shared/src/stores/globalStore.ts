import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import { SharedContext, UserProfile, Notification, ApplicationType } from '../types';

interface GlobalState extends SharedContext {
  // Actions
  setUser: (user: Partial<UserProfile>) => void;
  setCurrentApp: (app: ApplicationType, contextData?: Record<string, any>) => void;
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp'>) => void;
  markNotificationRead: (id: string) => void;
  clearNotifications: () => void;
  updateGlobalState: (state: Partial<SharedContext['globalState']>) => void;
  
  // Navigation helpers
  navigateWithContext: (app: ApplicationType, contextData?: Record<string, any>) => void;
  getPreviousContext: () => Record<string, any> | undefined;
}

export const useGlobalStore = create<GlobalState>()(
  devtools(
    persist(
      (set, get) => ({
        // Initial state
        user: {
          id: '',
          role: 'viewer',
          subscription: 'bronze',
          preferences: {
            theme: 'light',
            language: 'en',
            autoplay: true,
            quality: 'auto',
          },
        },
        navigation: {
          currentApp: 'viewer-portal',
        },
        notifications: [],
        globalState: {
          isOnline: navigator.onLine,
          lastSync: new Date(),
          activeStreams: 0,
        },

        // Actions
        setUser: (userData) =>
          set((state) => ({
            user: { ...state.user, ...userData },
          })),

        setCurrentApp: (app, contextData) =>
          set((state) => ({
            navigation: {
              previousApp: state.navigation.currentApp,
              currentApp: app,
              contextData,
            },
          })),

        addNotification: (notification) =>
          set((state) => ({
            notifications: [
              {
                ...notification,
                id: crypto.randomUUID(),
                timestamp: new Date(),
                read: false,
              },
              ...state.notifications,
            ].slice(0, 50), // Keep only last 50 notifications
          })),

        markNotificationRead: (id) =>
          set((state) => ({
            notifications: state.notifications.map((n) =>
              n.id === id ? { ...n, read: true } : n
            ),
          })),

        clearNotifications: () =>
          set(() => ({
            notifications: [],
          })),

        updateGlobalState: (newState) =>
          set((state) => ({
            globalState: { ...state.globalState, ...newState },
          })),

        navigateWithContext: (app, contextData) => {
          const { setCurrentApp } = get();
          setCurrentApp(app, contextData);
          
          // Navigate using window.location for cross-app navigation
          const basePath = process.env.NODE_ENV === 'production' ? '' : ':3000';
          const appPaths = {
            'viewer-portal': '/viewer',
            'creator-dashboard': '/creator',
            'admin-portal': '/admin',
            'support-system': '/support',
            'analytics-dashboard': '/analytics',
            'developer-console': '/dev',
          };
          
          const targetPath = appPaths[app];
          if (targetPath && window.location.pathname !== targetPath) {
            window.location.href = `${window.location.origin}${basePath}${targetPath}`;
          }
        },

        getPreviousContext: () => {
          const { navigation } = get();
          return navigation.contextData;
        },
      }),
      {
        name: 'streaming-platform-global-state',
        partialize: (state) => ({
          user: state.user,
          navigation: {
            currentApp: state.navigation.currentApp,
            // Don't persist contextData as it may contain sensitive info
          },
          globalState: state.globalState,
        }),
      }
    ),
    {
      name: 'streaming-platform-store',
    }
  )
);

// Online/offline detection
if (typeof window !== 'undefined') {
  window.addEventListener('online', () => {
    useGlobalStore.getState().updateGlobalState({ isOnline: true });
  });

  window.addEventListener('offline', () => {
    useGlobalStore.getState().updateGlobalState({ isOnline: false });
  });
}