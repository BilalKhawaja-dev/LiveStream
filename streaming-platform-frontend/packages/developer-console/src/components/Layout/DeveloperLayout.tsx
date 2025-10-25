import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../../stubs/auth';
import { ServiceNavigationMenu } from '../../stubs/shared-components';

interface DeveloperLayoutProps {
  children: React.ReactNode;
}

export const DeveloperLayout: React.FC<DeveloperLayoutProps> = ({ children }) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { user, logout } = useAuth();
  const location = useLocation();

  const navigationItems = [
    { path: '/api', label: 'API Dashboard', icon: '📊', description: 'Monitor API performance and usage' },
    { path: '/docs', label: 'API Documentation', icon: '📚', description: 'Interactive API documentation' },
    { path: '/health', label: 'System Health', icon: '🏥', description: 'System status and health checks' },
    { path: '/errors', label: 'Error Tracking', icon: '🐛', description: 'Error logs and debugging tools' },
    { path: '/testing', label: 'API Testing', icon: '🧪', description: 'Test API endpoints and responses' },
  ];

  return (
    <div className="developer-layout">
      {/* Header */}
      <header className="developer-header fixed top-0 left-0 right-0 z-50 h-16 bg-white border-b border-gray-200">
        <div className="flex items-center justify-between h-full px-6">
          <div className="flex items-center space-x-4">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="md:hidden p-2 rounded-lg hover:bg-gray-100"
            >
              <span className="text-xl">☰</span>
            </button>
            <div className="flex items-center space-x-2">
              <span className="text-2xl">💻</span>
              <h1 className="text-xl font-bold text-blue-900">Developer Console</h1>
            </div>
          </div>
          
          <div className="flex items-center space-x-4">
            <ServiceNavigationMenu 
              variant="dropdown" 
              showIcons={true} 
              showAvailabilityStatus={true} 
            />
            <div className="text-sm text-gray-600">
              Welcome, {user?.displayName || user?.username}
            </div>
            <button
              onClick={logout}
              className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Sidebar */}
      <aside className={`developer-sidebar fixed left-0 top-16 bottom-0 w-72 bg-white border-r border-gray-200 z-40 transform transition-transform duration-300 ${
        sidebarOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'
      }`}>
        <nav className="p-4 space-y-2">
          {navigationItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              className={`block p-4 rounded-lg transition-colors ${
                location.pathname === item.path 
                  ? 'bg-blue-50 text-blue-700 border border-blue-200' 
                  : 'text-gray-700 hover:bg-gray-100'
              }`}
              onClick={() => setSidebarOpen(false)}
            >
              <div className="flex items-center space-x-3 mb-1">
                <span className="text-xl">{item.icon}</span>
                <span className="font-medium">{item.label}</span>
              </div>
              <p className="text-xs text-gray-500 ml-8">{item.description}</p>
            </Link>
          ))}
        </nav>

        {/* Quick Stats */}
        <div className="p-4 border-t border-gray-200 mt-4">
          <h3 className="text-sm font-medium text-gray-900 mb-3">Quick Stats</h3>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">API Status</span>
              <span className="text-green-600 font-medium">Healthy</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">Response Time</span>
              <span className="text-blue-600 font-medium">~120ms</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">Error Rate</span>
              <span className="text-yellow-600 font-medium">0.02%</span>
            </div>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className="developer-main-content pt-16 md:ml-72 min-h-screen bg-gray-50">
        <div className="p-6">
          {children}
        </div>
      </main>

      {/* Mobile Sidebar Overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-30 md:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}
    </div>
  );
};