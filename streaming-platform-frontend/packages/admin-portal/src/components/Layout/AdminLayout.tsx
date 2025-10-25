import React, { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../../stubs/auth';
import { ServiceNavigationMenu } from '../../stubs/shared-components';

interface AdminLayoutProps {
  children: React.ReactNode;
}

export const AdminLayout: React.FC<AdminLayoutProps> = ({ children }) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { user, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();

  const navigationItems = [
    { path: '/dashboard', label: 'Dashboard', icon: '📊' },
    { path: '/users', label: 'User Management', icon: '👥' },
    { path: '/monitoring/logs', label: 'CloudWatch Logs', icon: '📋' },
    { path: '/monitoring/performance', label: 'Performance Metrics', icon: '⚡' },
  ];

  const handleSupportRedirect = () => {
    // Redirect to support system with admin context
    const supportUrl = `${window.location.origin.replace(':3002', ':3005')}/support?source=admin&context=${encodeURIComponent(JSON.stringify({
      application: 'admin-portal',
      user_id: user?.id,
      current_page: location.pathname,
      timestamp: new Date().toISOString()
    }))}`;
    window.open(supportUrl, '_blank');
  };

  return (
    <div className="admin-layout">
      {/* Header */}
      <header className="admin-header fixed top-0 left-0 right-0 z-50 h-16">
        <div className="flex items-center justify-between h-full px-6">
          <div className="flex items-center space-x-4">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="md:hidden p-2 rounded-lg hover:bg-gray-100"
            >
              <span className="text-xl">☰</span>
            </button>
            <h1 className="text-xl font-bold text-blue-900">Admin Portal</h1>
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
              className="admin-btn admin-btn-secondary px-4 py-2 text-sm"
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Sidebar */}
      <aside className={`admin-sidebar fixed left-0 top-16 bottom-0 w-64 z-40 ${sidebarOpen ? 'open' : ''}`}>
        <nav className="p-4 space-y-2">
          {navigationItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              className={`admin-nav-item flex items-center space-x-3 px-4 py-3 text-sm font-medium ${
                location.pathname === item.path ? 'active' : ''
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
      <main className="admin-main-content pt-16 md:ml-64">
        <div className="p-6">
          {children}
        </div>
      </main>

      {/* Support Button */}
      <button
        onClick={handleSupportRedirect}
        className="admin-support-btn"
        title="Get Support"
      >
        <span className="text-xl">💬</span>
      </button>

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