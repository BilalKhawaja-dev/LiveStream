import { create } from 'zustand';

interface GlobalState {
  theme: 'light' | 'dark';
  notifications: any[];
  setTheme: (theme: 'light' | 'dark') => void;
  addNotification: (notification: any) => void;
}

export const useGlobalStore = create<GlobalState>((set) => ({
  theme: 'light',
  notifications: [],
  setTheme: (theme) => set({ theme }),
  addNotification: (notification) => set((state) => ({ 
    notifications: [...state.notifications, notification] 
  })),
}));

export const secureLogger = {
  info: (message: string, data?: any, context?: any) => {
    console.log(`[INFO] ${message}`, data, context);
  },
  error: (message: string, error?: any, context?: any) => {
    console.error(`[ERROR] ${message}`, error, context);
  },
  warn: (message: string, data?: any, context?: any) => {
    console.warn(`[WARN] ${message}`, data, context);
  },
};

export interface LogContext {
  component?: string;
  userId?: string;
  action?: string;
}
