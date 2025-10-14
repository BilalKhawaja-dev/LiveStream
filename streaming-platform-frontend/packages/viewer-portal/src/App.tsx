import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth, withAuth } from '../../shared/auth';
import { LoginForm, RegisterForm } from '../../shared/auth';
import './App.css';

// Environment configuration
const cognitoConfig = {
  userPoolId: process.env.REACT_APP_COGNITO_USER_POOL_ID || '',
  userPoolClientId: process.env.REACT_APP_COGNITO_USER_POOL_CLIENT_ID || '',
  region: process.env.REACT_APP_AWS_REGION || 'us-east-1'
};

const apiBaseUrl = process.env.REACT_APP_API_BASE_URL || 'https://api.streaming-platform.com';

// Components
const HomePage: React.FC = () => {
  const { user, logout } = useAuth();

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold text-gray-900">
                Streaming Platform
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-gray-700">
                Welcome, {user?.displayName || user?.username}!
              </span>
              <span className="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-800 rounded-full">
                {user?.subscriptionTier}
              </span>
              <button
                onClick={logout}
                className="text-gray-500 hover:text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="border-4 border-dashed border-gray-200 rounded-lg h-96 flex items-center justify-center">
            <div className="text-center">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">
                Welcome to the Viewer Portal
              </h2>
              <p className="text-gray-600 mb-4">
                Your role: <span className="font-semibold">{user?.role}</span>
              </p>
              <p className="text-gray-600 mb-4">
                Subscription: <span className="font-semibold">{user?.subscriptionTier}</span>
              </p>
              <div className="space-y-2">
                <div className="bg-green-100 text-green-800 px-4 py-2 rounded-md">
                  ✓ Authentication working
                </div>
                <div className="bg-blue-100 text-blue-800 px-4 py-2 rounded-md">
                  ✓ User context loaded
                </div>
                <div className="bg-purple-100 text-purple-800 px-4 py-2 rounded-md">
                  ✓ Role-based access control active
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

const StreamsPage: React.FC = () => {
  const { user, hasSubscription } = useAuth();

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-gray-900 mb-6">Live Streams</h1>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {/* Free streams */}
          <div className="bg-white rounded-lg shadow-md p-6">
            <h3 className="text-lg font-semibold mb-2">Free Stream 1</h3>
            <p className="text-gray-600 mb-4">Available to all users</p>
            <button className="w-full bg-blue-500 text-white py-2 px-4 rounded hover:bg-blue-600">
              Watch Now
            </button>
          </div>

          {/* Premium streams */}
          <div className={`bg-white rounded-lg shadow-md p-6 ${!hasSubscription('silver') ? 'opacity-50' : ''}`}>
            <h3 className="text-lg font-semibold mb-2">Premium Stream 1</h3>
            <p className="text-gray-600 mb-4">Silver tier and above</p>
            <button 
              className="w-full bg-yellow-500 text-white py-2 px-4 rounded hover:bg-yellow-600 disabled:opacity-50"
              disabled={!hasSubscription('silver')}
            >
              {hasSubscription('silver') ? 'Watch Now' : 'Upgrade Required'}
            </button>
          </div>

          <div className={`bg-white rounded-lg shadow-md p-6 ${!hasSubscription('gold') ? 'opacity-50' : ''}`}>
            <h3 className="text-lg font-semibold mb-2">VIP Stream 1</h3>
            <p className="text-gray-600 mb-4">Gold tier and above</p>
            <button 
              className="w-full bg-yellow-600 text-white py-2 px-4 rounded hover:bg-yellow-700 disabled:opacity-50"
              disabled={!hasSubscription('gold')}
            >
              {hasSubscription('gold') ? 'Watch Now' : 'Upgrade Required'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

const ProfilePage: React.FC = () => {
  const { user, updateProfile, isLoading } = useAuth();
  const [editing, setEditing] = React.useState(false);
  const [displayName, setDisplayName] = React.useState(user?.displayName || '');

  const handleSave = async () => {
    try {
      await updateProfile({ displayName });
      setEditing(false);
    } catch (error) {
      console.error('Profile update failed:', error);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold text-gray-900 mb-6">Profile</h1>
        
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">Username</label>
              <p className="mt-1 text-sm text-gray-900">{user?.username}</p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Email</label>
              <p className="mt-1 text-sm text-gray-900">{user?.email}</p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Display Name</label>
              {editing ? (
                <div className="mt-1 flex space-x-2">
                  <input
                    type="text"
                    value={displayName}
                    onChange={(e) => setDisplayName(e.target.value)}
                    className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  />
                  <button
                    onClick={handleSave}
                    disabled={isLoading}
                    className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50"
                  >
                    Save
                  </button>
                  <button
                    onClick={() => setEditing(false)}
                    className="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400"
                  >
                    Cancel
                  </button>
                </div>
              ) : (
                <div className="mt-1 flex justify-between items-center">
                  <p className="text-sm text-gray-900">{user?.displayName}</p>
                  <button
                    onClick={() => setEditing(true)}
                    className="text-blue-500 hover:text-blue-600 text-sm"
                  >
                    Edit
                  </button>
                </div>
              )}
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Role</label>
              <p className="mt-1 text-sm text-gray-900 capitalize">{user?.role}</p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Subscription</label>
              <p className="mt-1 text-sm text-gray-900 capitalize">{user?.subscriptionTier}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const AuthPage: React.FC = () => {
  const [isLogin, setIsLogin] = React.useState(true);

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        {isLogin ? (
          <LoginForm
            onSuccess={() => window.location.href = '/'}
            onRegisterClick={() => setIsLogin(false)}
          />
        ) : (
          <RegisterForm
            onSuccess={() => {
              alert('Registration successful! Please check your email to verify your account.');
              setIsLogin(true);
            }}
            onLoginClick={() => setIsLogin(true)}
          />
        )}
      </div>
    </div>
  );
};

// Protected components
const ProtectedHomePage = withAuth(HomePage, 'viewer');
const ProtectedStreamsPage = withAuth(StreamsPage, 'viewer');
const ProtectedProfilePage = withAuth(ProfilePage, 'viewer');

const AppContent: React.FC = () => {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <Routes>
      <Route 
        path="/auth" 
        element={isAuthenticated ? <Navigate to="/" replace /> : <AuthPage />} 
      />
      <Route 
        path="/" 
        element={isAuthenticated ? <ProtectedHomePage /> : <Navigate to="/auth" replace />} 
      />
      <Route 
        path="/streams" 
        element={isAuthenticated ? <ProtectedStreamsPage /> : <Navigate to="/auth" replace />} 
      />
      <Route 
        path="/profile" 
        element={isAuthenticated ? <ProtectedProfilePage /> : <Navigate to="/auth" replace />} 
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

const App: React.FC = () => {
  return (
    <AuthProvider cognitoConfig={cognitoConfig} apiBaseUrl={apiBaseUrl}>
      <Router>
        <AppContent />
      </Router>
    </AuthProvider>
  );
};

export default App;