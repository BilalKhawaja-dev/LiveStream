import React, { useState, useEffect } from 'react';
import { useAuth } from '../../stubs/auth';

interface SystemMetrics {
  lambda_avg_duration_ms: number;
  lambda_error_count: number;
  api_avg_latency_ms: number;
  api_error_count: number;
  db_avg_connections: number;
  system_health: string;
}

interface StreamMetrics {
  active: number;
  total_24h: number;
  completed_24h: number;
  average_duration_minutes: number;
}

interface ViewerMetrics {
  current: number;
  peak_24h: number;
  average_24h: number;
  total_unique_viewers: number;
}

export const PerformanceMetrics: React.FC = () => {
  const [systemMetrics, setSystemMetrics] = useState<SystemMetrics | null>(null);
  const [streamMetrics, setStreamMetrics] = useState<StreamMetrics | null>(null);
  const [viewerMetrics, setViewerMetrics] = useState<ViewerMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState('24h');
  const [autoRefresh, setAutoRefresh] = useState(false);
  const { apiBaseUrl } = useAuth();

  useEffect(() => {
    fetchMetrics();
    
    let interval: NodeJS.Timeout;
    if (autoRefresh) {
      interval = setInterval(fetchMetrics, 60000); // Refresh every minute
    }
    
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [timeRange, autoRefresh]);

  const fetchMetrics = async () => {
    try {
      setLoading(true);
      
      // Fetch system metrics
      const systemResponse = await fetch(`${apiBaseUrl}/analytics/metrics?type=system&range=${timeRange}`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
        },
      });
      
      if (systemResponse.ok) {
        const systemData = await systemResponse.json();
        setSystemMetrics(systemData.system);
      }

      // Fetch stream metrics
      const streamResponse = await fetch(`${apiBaseUrl}/analytics/metrics?type=streams&range=${timeRange}`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
        },
      });
      
      if (streamResponse.ok) {
        const streamData = await streamResponse.json();
        setStreamMetrics(streamData.streams);
      }

      // Fetch viewer metrics
      const viewerResponse = await fetch(`${apiBaseUrl}/analytics/metrics?type=viewers&range=${timeRange}`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
        },
      });
      
      if (viewerResponse.ok) {
        const viewerData = await viewerResponse.json();
        setViewerMetrics(viewerData.viewers);
      }
      
    } catch (error) {
      console.error('Error fetching metrics:', error);
    } finally {
      setLoading(false);
    }
  };

  const getHealthBadge = (health: string) => {
    const badgeClass = health === 'healthy' ? 'admin-badge-success' : 
                     health === 'degraded' ? 'admin-badge-warning' : 'admin-badge-error';
    return <span className={`admin-badge ${badgeClass}`}>{health}</span>;
  };

  const formatNumber = (num: number) => {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  };

  if (loading && !systemMetrics) {
    return (
      <div className="admin-loading">
        <div className="admin-spinner"></div>
        <span className="ml-3 text-gray-600">Loading performance metrics...</span>
      </div>
    );
  }

  return (
    <div className="admin-fade-in">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Performance Metrics</h1>
        <p className="text-gray-600">Monitor system performance and streaming statistics</p>
      </div>

      {/* Controls */}
      <div className="admin-card mb-6">
        <div className="admin-card-body">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="admin-label">Time Range</label>
              <select
                className="admin-select"
                value={timeRange}
                onChange={(e) => setTimeRange(e.target.value)}
              >
                <option value="1h">Last Hour</option>
                <option value="24h">Last 24 Hours</option>
                <option value="7d">Last 7 Days</option>
                <option value="30d">Last 30 Days</option>
              </select>
            </div>
            <div>
              <label className="admin-label">Auto Refresh</label>
              <div className="flex items-center space-x-2 mt-2">
                <input
                  type="checkbox"
                  id="autoRefreshMetrics"
                  checked={autoRefresh}
                  onChange={(e) => setAutoRefresh(e.target.checked)}
                  className="rounded border-gray-300"
                />
                <label htmlFor="autoRefreshMetrics" className="text-sm text-gray-600">
                  Every minute
                </label>
              </div>
            </div>
            <div className="flex items-end">
              <button
                onClick={fetchMetrics}
                className="admin-btn admin-btn-primary px-4 py-2 w-full"
                disabled={loading}
              >
                {loading ? '🔄 Loading...' : '🔄 Refresh'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* System Health Overview */}
      {systemMetrics && (
        <div className="admin-card mb-6">
          <div className="admin-card-header">
            <h2 className="text-xl font-semibold flex items-center">
              System Health
              <span className="ml-3">{getHealthBadge(systemMetrics.system_health)}</span>
            </h2>
          </div>
          <div className="admin-card-body">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="text-center">
                <div className="text-2xl font-bold text-blue-600">
                  {systemMetrics.lambda_avg_duration_ms.toFixed(1)}ms
                </div>
                <div className="text-sm text-gray-600">Avg Lambda Duration</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-green-600">
                  {systemMetrics.api_avg_latency_ms.toFixed(1)}ms
                </div>
                <div className="text-sm text-gray-600">Avg API Latency</div>
              </div>
              <div className="text-center">
                <div className="text-2xl font-bold text-purple-600">
                  {systemMetrics.db_avg_connections.toFixed(1)}
                </div>
                <div className="text-sm text-gray-600">Avg DB Connections</div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Performance Metrics Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        {/* Lambda Metrics */}
        <div className="admin-metric-card bg-gradient-to-r from-blue-500 to-blue-600">
          <div className="admin-metric-value">
            {systemMetrics?.lambda_error_count || 0}
          </div>
          <div className="admin-metric-label">Lambda Errors</div>
        </div>

        {/* API Metrics */}
        <div className="admin-metric-card bg-gradient-to-r from-green-500 to-green-600">
          <div className="admin-metric-value">
            {systemMetrics?.api_error_count || 0}
          </div>
          <div className="admin-metric-label">API Errors</div>
        </div>

        {/* Current Viewers */}
        <div className="admin-metric-card bg-gradient-to-r from-purple-500 to-purple-600">
          <div className="admin-metric-value">
            {formatNumber(viewerMetrics?.current || 0)}
          </div>
          <div className="admin-metric-label">Current Viewers</div>
        </div>

        {/* Active Streams */}
        <div className="admin-metric-card bg-gradient-to-r from-orange-500 to-orange-600">
          <div className="admin-metric-value">
            {streamMetrics?.active || 0}
          </div>
          <div className="admin-metric-label">Active Streams</div>
        </div>
      </div>

      {/* Detailed Metrics */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Streaming Performance */}
        <div className="admin-card">
          <div className="admin-card-header">
            <h3 className="text-lg font-semibold">Streaming Performance</h3>
          </div>
          <div className="admin-card-body">
            {streamMetrics ? (
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Active Streams</span>
                  <span className="font-semibold text-lg">{streamMetrics.active}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Total Streams (24h)</span>
                  <span className="font-semibold text-lg">{streamMetrics.total_24h}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Completed Streams (24h)</span>
                  <span className="font-semibold text-lg">{streamMetrics.completed_24h}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Avg Duration</span>
                  <span className="font-semibold text-lg">
                    {streamMetrics.average_duration_minutes.toFixed(1)}m
                  </span>
                </div>
              </div>
            ) : (
              <div className="text-center text-gray-500">No streaming data available</div>
            )}
          </div>
        </div>

        {/* Viewer Analytics */}
        <div className="admin-card">
          <div className="admin-card-header">
            <h3 className="text-lg font-semibold">Viewer Analytics</h3>
          </div>
          <div className="admin-card-body">
            {viewerMetrics ? (
              <div className="space-y-4">
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Current Viewers</span>
                  <span className="font-semibold text-lg">{formatNumber(viewerMetrics.current)}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Peak Viewers (24h)</span>
                  <span className="font-semibold text-lg">{formatNumber(viewerMetrics.peak_24h)}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Average Viewers (24h)</span>
                  <span className="font-semibold text-lg">{formatNumber(viewerMetrics.average_24h)}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Unique Viewers</span>
                  <span className="font-semibold text-lg">{formatNumber(viewerMetrics.total_unique_viewers)}</span>
                </div>
              </div>
            ) : (
              <div className="text-center text-gray-500">No viewer data available</div>
            )}
          </div>
        </div>
      </div>

      {/* System Status Indicators */}
      <div className="admin-card mt-6">
        <div className="admin-card-header">
          <h3 className="text-lg font-semibold">System Status</h3>
        </div>
        <div className="admin-card-body">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="text-center p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-600 mb-2">Database</div>
              {getHealthBadge('healthy')}
            </div>
            <div className="text-center p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-600 mb-2">API Gateway</div>
              {getHealthBadge(systemMetrics?.api_error_count && systemMetrics.api_error_count > 10 ? 'degraded' : 'healthy')}
            </div>
            <div className="text-center p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-600 mb-2">Lambda Functions</div>
              {getHealthBadge(systemMetrics?.lambda_error_count && systemMetrics.lambda_error_count > 5 ? 'degraded' : 'healthy')}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};