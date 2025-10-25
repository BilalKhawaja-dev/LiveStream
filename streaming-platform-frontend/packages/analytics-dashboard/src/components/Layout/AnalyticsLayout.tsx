import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../../stubs/auth';
import { ServiceNavigationMenu } from '../../stubs/shared-components';

interface AnalyticsLayoutProps {
  children: React.ReactNode;
}

export const AnalyticsLayout: React.FC<AnalyticsLayoutProps> = ({ children }) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { user, logout } = useAuth();
  const location = useLocation();

  const navigationItems = [
    { path: '/cloudwatch', label: 'CloudWatch Metrics', icon: '📊', roles: ['analyst', 'admin', 'creator'] },
    { path: '/streamers', label: 'Streamer Analytics', icon: '🎥', roles: ['analyst', 'admin', 'creator'] },
    { path: '/revenue', label: 'Revenue Analytics', icon: '💰', roles: ['analyst', 'admin'] },
    { path: '/engagement', label: 'User Engagement', icon: '👥', roles: ['analyst', 'admin'] },
    { path: '/realtime', label: 'Real-time Metrics', icon: '⚡', roles: ['analyst', 'admin', 'creator'] },
  ];

  const accessibleItems = navigationItems.filter(item => 
    item.roles.includes(user?.role || ')
  );

  return (
    <div className="analytics-layout">
      {/* Header */}
      <header className="analytics-header fixed top-0 left-0 right-0 z-50 h-16 bg-white border-b border-gray-200">
        <div className="flex items-center justify-between h-full px-6">
          <div className="flex items-center space-x-4">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="md:hidden p-2 rounded-lg hover:bg-gray-100"
            >
              <span className="text-xl">☰</span>
            </button>
            <h1 className="text-xl font-bold text-blue-900">Analytics Dashboard</h1>
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
      <aside className={`analytics-sidebar fixed left-0 top-16 bottom-0 w-64 bg-white border-r border-gray-200 z-40 transform transition-transform duration-300 ${
        sidebarOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'
      }`}>
        <nav className="p-4 space-y-2">
          {accessibleItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              className={`flex items-center space-x-3 px-4 py-3 text-sm font-medium rounded-lg transition-colors ${
                location.pathname === item.path 
                  ? 'bg-blue-50 text-blue-700 border border-blue-200' 
                  : 'text-gray-700 hover:bg-gray-100'
              }`}
              onClick={() => setSidebarOpen(false)}
            >
              <span className="text-lg">{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>
      </aside>

      {/* Main Content */}
      <main className="analytics-main-content pt-16 md:ml-64 min-h-screen bg-gray-50">
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