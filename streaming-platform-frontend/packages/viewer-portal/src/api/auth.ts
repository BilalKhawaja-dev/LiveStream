// Basic auth API for viewer portal
export interface User {
  id: string;
  email: string;
  subscription: 'bronze' | 'silver' | 'gold';
  isStreamer: boolean;
}

// Dummy users for development
const DUMMY_USERS: User[] = [
  { id: '1', email: 'viewer@test.com', subscription: 'bronze', isStreamer: false },
  { id: '2', email: 'streamer@test.com', subscription: 'gold', isStreamer: true },
  { id: '3', email: 'admin@test.com', subscription: 'gold', isStreamer: true },
];

export const authAPI = {
  login: async (email: string, password: string): Promise<User | null> => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const user = DUMMY_USERS.find(u => u.email === email);
    if (user && password === 'password') {
      localStorage.setItem('user', JSON.stringify(user));
      return user;
    }
    return null;
  },

  logout: async (): Promise<void> => {
    localStorage.removeItem('user');
  },

  getCurrentUser: (): User | null => {
    const stored = localStorage.getItem('user');
    return stored ? JSON.parse(stored) : null;
  },

  register: async (email: string, password: string): Promise<User> => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const newUser: User = {
      id: Date.now().toString(),
      email,
      subscription: 'bronze',
      isStreamer: false
    };
    
    localStorage.setItem('user', JSON.stringify(newUser));
    return newUser;
  }
};