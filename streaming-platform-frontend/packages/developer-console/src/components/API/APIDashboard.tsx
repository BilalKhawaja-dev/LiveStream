import React, { useState, useEffect } from 'react';
import { useAuth } from '../../stubs/auth';
import { secureLogger } from '../../stubs/shared';

interface APIEndpoint {
  path: string;
  method: string;
  description: string;
  responseTime: number;
  successRate: number;
  requestCount: number;
  errorCount: number;
  lastError?: string;
  status: 'healthy' | 'warning' | 'error';
}

interface APIMetrics {
  totalRequests: number;
  averageResponseTime: number;
  errorRate: number;
  uptime: number;
  endpoints: APIEndpoint[];
}

export const APIDashboard: React.FC = () => {
  const { user } = useAuth();
  const [metrics, setMetrics] = useState<APIMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [timeRange, setTimeRange] = useState<'1h' | '24h' | '7d'>('24h');
  const [refreshInterval, setRefreshInterval] = useState<number>(30000); // 30 seconds

  useEffect(() => {
    fetchAPIMetrics();
    const interval = setInterval(fetchAPIMetrics, refreshInterval);
    return () => clearInterval(interval);
  }, [timeRange, refreshInterval]);

  const fetchAPIMetrics = async () => {
    try {
      setError(null);
      
      const apiBaseUrl = process.env.REACT_APP_API_BASE_URL;
      const response = await fetch(`${apiBaseUrl}/developer/api-metrics`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('authToken')}`
        },
        body: JSON.stringify({ timeRange })
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch API metrics: ${response.statusText}`);
      }

      const data = await response.json();
      setMetrics(data);

      secureLogger.info('API metrics fetched', {
        userId: user?.id,
        timeRange,
        endpointCount: data.endpoints?.length || 0
      });

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch API metrics';
      setError(errorMessage);
      secureLogger.error('Error fetching API metrics', { error: errorMessage });
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string): string => {
    switch (status) {
      case 'healthy': return 'text-green-600 bg-green-100';
      case 'warning': return 'text-yellow-600 bg-yellow-100';
      case 'error': return 'text-red-600 bg-red-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  };

  const getStatusIcon = (status: string): string => {
    switch (status) {
      case 'healthy': return '✅';
      case 'warning': return '⚠️';
      case 'error': return '❌';
      default: return '❓';
    }
  };

  const formatResponseTime = (ms: number): string => {
    if (ms < 1000) return `${ms.toFixed(0)}ms`;
    return `${(ms / 1000).toFixed(2)}s`;
  };

  const formatUptime = (percentage: number): string => {
    return `${percentage.toFixed(2)}%`;
  };

  return (
    <div className="api-dashboard">
      <div className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 mb-2">API Dashboard</h1>
            <p className="text-gray-600">Monitor API performance and usage metrics</p>
          </div>
          
          <div className="flex items-center space-x-4">
            <select
              value={timeRange}
              onChange={(e) => setTimeRange(e.target.value as '1h' | '24h' | '7d')}
              className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="1h">Last Hour</option>
              <option value="24h">Last 24 Hours</option>
              <option value="7d">Last 7 Days</option>
            </select>
            
            <button
              onClick={fetchAPIMetrics}
              disabled={loading}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
            >
              {loading ? 'Refreshing...' : 'Refresh'}
            </button>
          </div>
        </div>
      </div>

      {/* Error State */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-8">
          <div className="flex items-center">
            <span className="text-red-500 mr-2">⚠️</span>
            <span className="text-red-700">{error}</span>
          </div>
        </div>
      )}

      {/* Loading State */}
      {loading && !metrics && (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
          <span className="ml-4 text-gray-600">Loading API metrics...</span>
        </div>
      )}

      {/* Metrics Overview */}
      {metrics && (
        <>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div className="bg-white rounded-lg shadow-md p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Total Requests</p>
                  <p className="text-2xl font-bold text-gray-900">{metrics.totalRequests.toLocaleString()}</p>
                </div>
                <div className="text-blue-500 text-3xl">📊</div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow-md p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Avg Response Time</p>
                  <p className="text-2xl font-bold text-gray-900">{formatResponseTime(metrics.averageResponseTime)}</p>
                </div>
                <div className="text-green-500 text-3xl">⚡</div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow-md p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Error Rate</p>
                  <p className="text-2xl font-bold text-gray-900">{(metrics.errorRate * 100).toFixed(2)}%</p>
                </div>
                <div className="text-red-500 text-3xl">🚨</div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow-md p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Uptime</p>
                  <p className="text-2xl font-bold text-gray-900">{formatUptime(metrics.uptime)}</p>
                </div>
                <div className="text-purple-500 text-3xl">🔄</div>
              </div>
            </div>
          </div>

          {/* Endpoints Table */}
          <div className="bg-white rounded-lg shadow-md overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">API Endpoints</h2>
            </div>
            
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Endpoint
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Method
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Requests
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Success Rate
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Avg Response
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Errors
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {metrics.endpoints.map((endpoint, index) => (
                    <tr key={`${endpoint.method}-${endpoint.path}`} className="hover:bg-gray-50">
                      <td className="px-6 py-4">
                        <div>
                          <div className="text-sm font-medium text-gray-900">{endpoint.path}</div>
                          <div className="text-sm text-gray-500">{endpoint.description}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded ${
                          endpoint.method === 'GET' ? 'bg-blue-100 text-blue-800' :
                          endpoint.method === 'POST' ? 'bg-green-100 text-green-800' :
                          endpoint.method === 'PUT' ? 'bg-yellow-100 text-yellow-800' :
                          endpoint.method === 'DELETE' ? 'bg-red-100 text-red-800' :
                          'bg-gray-100 text-gray-800'
                        }`}>
                          {endpoint.method}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center">
                          <span className="mr-2">{getStatusIcon(endpoint.status)}</span>
                          <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded ${getStatusColor(endpoint.status)}`}>
                            {endpoint.status}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {endpoint.requestCount.toLocaleString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <div className="flex items-center">
                          <span className={`font-medium ${
                            endpoint.successRate >= 99 ? 'text-green-600' :
                            endpoint.successRate >= 95 ? 'text-yellow-600' :
                            'text-red-600'
                          }`}>
                            {(endpoint.successRate * 100).toFixed(1)}%
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {formatResponseTime(endpoint.responseTime)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">{endpoint.errorCount}</div>
                        {endpoint.lastError && (
                          <div className="text-xs text-red-600 truncate max-w-xs" title={endpoint.lastError}>
                            {endpoint.lastError}
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Auto-refresh Settings */}
          <div className="mt-8 bg-white rounded-lg shadow-md p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Auto-refresh Settings</h3>
            <div className="flex items-center space-x-4">
              <label className="text-sm font-medium text-gray-700">Refresh Interval:</label>
              <select
                value={refreshInterval}
                onChange={(e) => setRefreshInterval(Number(e.target.value))}
                className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value={10000}>10 seconds</option>
                <option value={30000}>30 seconds</option>
                <option value={60000}>1 minute</option>
                <option value={300000}>5 minutes</option>
              </select>
              <span className="text-sm text-gray-500">
                Last updated: {new Date().toLocaleTimeString()}
              </span>
            </div>
          </div>
        </>
      )}
    </div>
  );
};