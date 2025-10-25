import React, { useState, useEffect } from 'react';
import { useAuth } from '../../stubs/auth';

interface DashboardData {
  overview: {
    total_users: number;
    active_streams: number;
    total_views: number;
    active_users_24h: number;
  };
  recent_streams: Array<{
    stream_id: string;
    title: string;
    status: string;
    viewers: number;
    started_at: string;
    streamer: string;
    streamer_display_name?: string;
  }>;
  top_categories: Array<{
    name: string;
    stream_count: number;
    viewers: number;
  }>;
  system_health: {
    overall: string;
    database: string;
    api: string;
    recent_errors: number;
  };
}

export const SystemDashboard: React.FC = () => {
  const [dashboardData, setDashboardData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const { apiBaseUrl } = useAuth();

  useEffect(() => {
    fetchDashboardData();
    
    // Auto-refresh every 30 seconds
    const interval = setInterval(fetchDashboardData, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchDashboardData = async () => {
    try {
      const response = await fetch(`${apiBaseUrl}/analytics/dashboard`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
        },
      });
      
      if (response.ok) {
        const data = await response.json();
        setDashboardData(data);
      }
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatNumber = (num: number) => {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  };

  const getHealthBadge = (health: string) => {
    const badgeClass = health === 'healthy' ? 'admin-badge-success' : 
                     health === 'degraded' ? 'admin-badge-warning' : 'admin-badge-error';
    return <span className={`admin-badge ${badgeClass}`}>{health}</span>;
  };

  const getStatusBadge = (status: string) => {
    const badgeClass = status === 'live' ? 'admin-badge-success' : 
                     status === 'ended' ? 'admin-badge-info' : 'admin-badge-warning';
    return <span className={`admin-badge ${badgeClass}`}>{status}</span>;
  };

  if (loading) {
    return (
      <div className="admin-loading">
        <div className="admin-spinner"></div>
        <span className="ml-3 text-gray-600">Loading dashboard...</span>
      </div>
    );
  }

  return (
    <div className="admin-fade-in">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">System Dashboard</h1>
        <p className="text-gray-600">Overview of platform performance and activity</p>
      </div>

      {/* Overview Metrics */}
      {dashboardData && (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <div className="admin-metric-card bg-gradient-to-r from-blue-500 to-blue-600">
              <div className="admin-metric-value">
                {formatNumber(dashboardData.overview.total_users)}
              </div>
              <div className="admin-metric-label">Total Users</div>
            </div>
            <div className="admin-metric-card bg-gradient-to-r from-green-500 to-green-600">
              <div className="admin-metric-value">
                {dashboardData.overview.active_streams}
              </div>
              <div className="admin-metric-label">Active Streams</div>
            </div>
            <div className="admin-metric-card bg-gradient-to-r from-purple-500 to-purple-600">
              <div className="admin-metric-value">
                {formatNumber(dashboardData.overview.total_views)}
              </div>
              <div className="admin-metric-label">Total Views</div>
            </div>
            <div className="admin-metric-card bg-gradient-to-r from-orange-500 to-orange-600">
              <div className="admin-metric-value">
                {formatNumber(dashboardData.overview.active_users_24h)}
              </div>
              <div className="admin-metric-label">Active Users (24h)</div>
            </div>
          </div>

          {/* System Health */}
          <div className="admin-card mb-6">
            <div className="admin-card-header">
              <h2 className="text-xl font-semibold flex items-center">
                System Health
                <span className="ml-3">{getHealthBadge(dashboardData.system_health.overall)}</span>
              </h2>
            </div>
            <div className="admin-card-body">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="text-center p-4 bg-gray-50 rounded-lg">
                  <div className="text-sm text-gray-600 mb-2">Database</div>
                  {getHealthBadge(dashboardData.system_health.database)}
                </div>
                <div className="text-center p-4 bg-gray-50 rounded-lg">
                  <div className="text-sm text-gray-600 mb-2">API</div>
                  {getHealthBadge(dashboardData.system_health.api)}
                </div>
                <div className="text-center p-4 bg-gray-50 rounded-lg">
                  <div className="text-sm text-gray-600 mb-2">Recent Errors</div>
                  <div className="text-lg font-semibold text-gray-900">
                    {dashboardData.system_health.recent_errors}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Recent Activity */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Recent Streams */}
            <div className="admin-card">
              <div className="admin-card-header">
                <h3 className="text-lg font-semibold">Recent Streams</h3>
              </div>
              <div className="admin-card-body">
                {dashboardData.recent_streams.length > 0 ? (
                  <div className="space-y-3">
                    {dashboardData.recent_streams.slice(0, 5).map((stream) => (
                      <div key={stream.stream_id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                        <div>
                          <div className="font-medium text-gray-900">{stream.title}</div>
                          <div className="text-sm text-gray-500">
                            by {stream.streamer_display_name || stream.streamer}
                          </div>
                        </div>
                        <div className="text-right">
                          <div>{getStatusBadge(stream.status)}</div>
                          <div className="text-sm text-gray-500 mt-1">
                            {stream.viewers} viewers
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-center text-gray-500 py-4">
                    No recent streams
                  </div>
                )}
              </div>
            </div>

            {/* Top Categories */}
            <div className="admin-card">
              <div className="admin-card-header">
                <h3 className="text-lg font-semibold">Top Categories</h3>
              </div>
              <div className="admin-card-body">
                {dashboardData.top_categories.length > 0 ? (
                  <div className="space-y-3">
                    {dashboardData.top_categories.slice(0, 5).map((category) => (
                      <div key={category.name} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                        <div>
                          <div className="font-medium text-gray-900">{category.name}</div>
                          <div className="text-sm text-gray-500">
                            {category.stream_count} streams
                          </div>
                        </div>
                        <div className="text-right">
                          <div className="font-semibold text-blue-600">
                            {formatNumber(category.viewers)}
                          </div>
                          <div className="text-sm text-gray-500">viewers</div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-center text-gray-500 py-4">
                    No category data
                  </div>
                )}
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
};