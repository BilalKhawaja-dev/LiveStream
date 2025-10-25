import React, { useState, useEffect } from 'react';
import { useAuth } from '../../stubs/auth';
import { secureLogger } from '../../stubs/shared';

interface MetricData {
  timestamp: string;
  value: number;
  unit: string;
}

interface CloudWatchMetric {
  name: string;
  namespace: string;
  dimensions: Record<string, string>;
  data: MetricData[];
  description: string;
}

interface FilterOptions {
  timeRange: '1h' | '6h' | '24h' | '7d' | '30d';
  namespace: string;
  streamerFilter: string;
  metricType: 'all' | 'performance' | 'engagement' | 'errors';
}

export const CloudWatchDashboard: React.FC = () => {
  const { user } = useAuth();
  const [metrics, setMetrics] = useState<CloudWatchMetric[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useState<FilterOptions>({
    timeRange: '24h',
    namespace: 'StreamingPlatform/Analytics',
    streamerFilter: ',
    metricType: 'all'
  });

  const availableNamespaces = [
    'StreamingPlatform/Analytics',
    'AWS/Lambda',
    'AWS/ApiGateway',
    'AWS/DynamoDB',
    'AWS/S3',
    'AWS/CloudFront',
    'AWS/MediaLive'
  ];

  const metricTypes = [
    { value: 'all', label: 'All Metrics' },
    { value: 'performance', label: 'Performance' },
    { value: 'engagement', label: 'User Engagement' },
    { value: 'errors', label: 'Errors & Issues' }
  ];

  useEffect(() => {
    fetchCloudWatchMetrics();
  }, [filters]);

  const fetchCloudWatchMetrics = async () => {
    try {
      setLoading(true);
      setError(null);

      const apiBaseUrl = process.env.REACT_APP_API_BASE_URL;
      const response = await fetch(`${apiBaseUrl}/analytics/cloudwatch-metrics`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('authToken')}`
        },
        body: JSON.stringify({
          timeRange: filters.timeRange,
          namespace: filters.namespace,
          streamerFilter: filters.streamerFilter,
          metricType: filters.metricType
        })
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch metrics: ${response.statusText}`);
      }

      const data = await response.json();
      setMetrics(data.metrics || []);

      secureLogger.info('CloudWatch metrics fetched', {
        userId: user?.id,
        namespace: filters.namespace,
        metricCount: data.metrics?.length || 0
      });

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch CloudWatch metrics';
      setError(errorMessage);
      secureLogger.error('Error fetching CloudWatch metrics', { error: errorMessage });
    } finally {
      setLoading(false);
    }
  };

  const handleFilterChange = (key: keyof FilterOptions, value: string) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  };

  const formatValue = (value: number, unit: string): string => {
    if (unit === 'Percent') {
      return `${value.toFixed(2)}%`;
    } else if (unit === 'Count') {
      return value.toLocaleString();
    } else if (unit === 'Seconds') {
      return `${value.toFixed(2)}s`;
    } else if (unit === 'Bytes') {
      const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
      const i = Math.floor(Math.log(value) / Math.log(1024));
      return `${(value / Math.pow(1024, i)).toFixed(2)} ${sizes[i]}`;
    }
    return `${value.toFixed(2)} ${unit}`;
  };

  const getMetricColor = (metricName: string): string => {
    if (metricName.toLowerCase().includes('error')) return 'text-red-600';
    if (metricName.toLowerCase().includes('success')) return 'text-green-600';
    if (metricName.toLowerCase().includes('latency')) return 'text-yellow-600';
    return 'text-blue-600';
  };

  const renderMetricCard = (metric: CloudWatchMetric) => {
    const latestValue = metric.data[metric.data.length - 1];
    const previousValue = metric.data[metric.data.length - 2];
    const trend = latestValue && previousValue ? 
      ((latestValue.value - previousValue.value) / previousValue.value) * 100 : 0;

    return (
      <div key={`${metric.namespace}-${metric.name}`} className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-gray-900">{metric.name}</h3>
          <span className={`text-2xl font-bold ${getMetricColor(metric.name)}`}>
            {latestValue ? formatValue(latestValue.value, latestValue.unit) : 'N/A'}
          </span>
        </div>
        
        <p className="text-sm text-gray-600 mb-4">{metric.description}</p>
        
        {trend !== 0 && (
          <div className={`flex items-center text-sm ${trend > 0 ? 'text-green-600' : 'text-red-600'}`}>
            <span className="mr-1">
              {trend > 0 ? '↗' : '↘'}
            </span>
            <span>{Math.abs(trend).toFixed(2)}% from previous period</span>
          </div>
        )}
        
        <div className="mt-4">
          <div className="text-xs text-gray-500 mb-2">Namespace: {metric.namespace}</div>
          {Object.entries(metric.dimensions).length > 0 && (
            <div className="text-xs text-gray-500">
              Dimensions: {Object.entries(metric.dimensions).map(([key, value]) => `${key}=${value}`).join(', ')}
            </div>
          )}
        </div>
        
        {/* Simple sparkline representation */}
        <div className="mt-4 h-16 bg-gray-50 rounded flex items-end space-x-1 p-2">
          {metric.data.slice(-10).map((point, index) => {
            const maxValue = Math.max(...metric.data.map(d => d.value));
            const height = maxValue > 0 ? (point.value / maxValue) * 100 : 0;
            return (
              <div
                key={index}
                className="bg-blue-500 rounded-sm flex-1"
                style={{ height: `${height}%` }}
                title={`${formatValue(point.value, point.unit)} at ${new Date(point.timestamp).toLocaleTimeString()}`}
              />
            );
          })}
        </div>
      </div>
    );
  };

  return (
    <div className="cloudwatch-dashboard">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">CloudWatch Metrics Dashboard</h1>
        <p className="text-gray-600">Monitor real-time performance and system metrics</p>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow-md p-6 mb-8">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Filters</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* Time Range Filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Time Range</label>
            <select
              value={filters.timeRange}
              onChange={(e) => handleFilterChange('timeRange', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="1h">Last Hour</option>
              <option value="6h">Last 6 Hours</option>
              <option value="24h">Last 24 Hours</option>
              <option value="7d">Last 7 Days</option>
              <option value="30d">Last 30 Days</option>
            </select>
          </div>

          {/* Namespace Filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Namespace</label>
            <select
              value={filters.namespace}
              onChange={(e) => handleFilterChange('namespace', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {availableNamespaces.map(ns => (
                <option key={ns} value={ns}>{ns}</option>
              ))}
            </select>
          </div>

          {/* Streamer Filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Streamer Filter</label>
            <input
              type="text"
              value={filters.streamerFilter}
              onChange={(e) => handleFilterChange('streamerFilter', e.target.value)}
              placeholder="Filter by streamer name..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Metric Type Filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Metric Type</label>
            <select
              value={filters.metricType}
              onChange={(e) => handleFilterChange('metricType', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {metricTypes.map(type => (
                <option key={type.value} value={type.value}>{type.label}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="mt-4 flex justify-end">
          <button
            onClick={fetchCloudWatchMetrics}
            disabled={loading}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            {loading ? 'Refreshing...' : 'Refresh Metrics'}
          </button>
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
      {loading && (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
          <span className="ml-4 text-gray-600">Loading CloudWatch metrics...</span>
        </div>
      )}

      {/* Metrics Grid */}
      {!loading && !error && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {metrics.length > 0 ? (
            metrics.map(renderMetricCard)
          ) : (
            <div className="col-span-full text-center py-12">
              <div className="text-gray-400 text-6xl mb-4">📊</div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">No metrics found</h3>
              <p className="text-gray-600">Try adjusting your filters or check back later.</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
};