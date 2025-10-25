import React, { useState, useEffect } from 'react';
import { useAuth } from '../../stubs/auth';
import { secureLogger } from '../../stubs/shared';

interface StreamerMetrics {
  streamerId: string;
  streamerName: string;
  totalStreams: number;
  totalViewTime: number;
  averageViewers: number;
  peakViewers: number;
  totalRevenue: number;
  subscriptionTier: string;
  lastStreamDate: string;
  engagementRate: number;
}

interface StreamerFilters {
  timeRange: '7d' | '30d' | '90d' | '1y';
  subscriptionTier: 'all' | 'bronze' | 'silver' | 'gold';
  sortBy: 'revenue' | 'viewers' | 'engagement' | 'streams';
  sortOrder: 'asc' | 'desc';
  searchQuery: string;
}

export const StreamerAnalytics: React.FC = () => {
  const { user } = useAuth();
  const [streamers, setStreamers] = useState<StreamerMetrics[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useState<StreamerFilters>({
    timeRange: '30d',
    subscriptionTier: 'all',
    sortBy: 'revenue',
    sortOrder: 'desc',
    searchQuery: ''
  });

  useEffect(() => {
    fetchStreamerAnalytics();
  }, [filters]);

  const fetchStreamerAnalytics = async () => {
    try {
      setLoading(true);
      setError(null);

      const apiBaseUrl = process.env.REACT_APP_API_BASE_URL;
      const response = await fetch(`${apiBaseUrl}/analytics/streamers`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('authToken')}`
        },
        body: JSON.stringify(filters)
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch streamer analytics: ${response.statusText}`);
      }

      const data = await response.json();
      setStreamers(data.streamers || []);

      secureLogger.info('Streamer analytics fetched', {
        userId: user?.id,
        streamerCount: data.streamers?.length || 0,
        filters
      });

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch streamer analytics';
      setError(errorMessage);
      secureLogger.error('Error fetching streamer analytics', { error: errorMessage });
    } finally {
      setLoading(false);
    }
  };

  const handleFilterChange = (key: keyof StreamerFilters, value: string) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  };

  const formatCurrency = (amount: number): string => {
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP'
    }).format(amount);
  };

  const formatDuration = (seconds: number): string => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  };

  const getTierColor = (tier: string): string => {
    switch (tier) {
      case 'gold': return 'text-yellow-600 bg-yellow-100';
      case 'silver': return 'text-gray-600 bg-gray-100';
      case 'bronze': return 'text-orange-600 bg-orange-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  };

  const getEngagementColor = (rate: number): string => {
    if (rate >= 80) return 'text-green-600';
    if (rate >= 60) return 'text-yellow-600';
    return 'text-red-600';
  };

  const filteredStreamers = streamers.filter(streamer =>
    streamer.streamerName.toLowerCase().includes(filters.searchQuery.toLowerCase())
  );

  return (
    <div className="streamer-analytics">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Streamer Analytics</h1>
        <p className="text-gray-600">Comprehensive analytics for content creators</p>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow-md p-6 mb-8">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Filters & Search</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          {/* Search */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Search Streamers</label>
            <input
              type="text"
              value={filters.searchQuery}
              onChange={(e) => handleFilterChange('searchQuery', e.target.value)}
              placeholder="Search by name..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Time Range */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Time Range</label>
            <select
              value={filters.timeRange}
              onChange={(e) => handleFilterChange('timeRange', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="7d">Last 7 Days</option>
              <option value="30d">Last 30 Days</option>
              <option value="90d">Last 90 Days</option>
              <option value="1y">Last Year</option>
            </select>
          </div>

          {/* Subscription Tier */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Subscription Tier</label>
            <select
              value={filters.subscriptionTier}
              onChange={(e) => handleFilterChange('subscriptionTier', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="all">All Tiers</option>
              <option value="bronze">Bronze</option>
              <option value="silver">Silver</option>
              <option value="gold">Gold</option>
            </select>
          </div>

          {/* Sort By */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Sort By</label>
            <select
              value={filters.sortBy}
              onChange={(e) => handleFilterChange('sortBy', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="revenue">Revenue</option>
              <option value="viewers">Average Viewers</option>
              <option value="engagement">Engagement Rate</option>
              <option value="streams">Total Streams</option>
            </select>
          </div>

          {/* Sort Order */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Sort Order</label>
            <select
              value={filters.sortOrder}
              onChange={(e) => handleFilterChange('sortOrder', e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="desc">Highest First</option>
              <option value="asc">Lowest First</option>
            </select>
          </div>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Streamers</p>
              <p className="text-2xl font-bold text-gray-900">{filteredStreamers.length}</p>
            </div>
            <div className="text-blue-500 text-3xl">👥</div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Revenue</p>
              <p className="text-2xl font-bold text-gray-900">
                {formatCurrency(filteredStreamers.reduce((sum, s) => sum + s.totalRevenue, 0))}
              </p>
            </div>
            <div className="text-green-500 text-3xl">💰</div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Avg Engagement</p>
              <p className="text-2xl font-bold text-gray-900">
                {(filteredStreamers.reduce((sum, s) => sum + s.engagementRate, 0) / Math.max(filteredStreamers.length, 1)).toFixed(1)}%
              </p>
            </div>
            <div className="text-purple-500 text-3xl">📊</div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Streams</p>
              <p className="text-2xl font-bold text-gray-900">
                {filteredStreamers.reduce((sum, s) => sum + s.totalStreams, 0)}
              </p>
            </div>
            <div className="text-red-500 text-3xl">🎥</div>
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
      {loading && (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
          <span className="ml-4 text-gray-600">Loading streamer analytics...</span>
        </div>
      )}

      {/* Streamers Table */}
      {!loading && !error && (
        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Streamer Performance</h2>
          </div>
          
          {filteredStreamers.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Streamer
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Tier
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Streams
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Avg Viewers
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Peak Viewers
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Watch Time
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Revenue
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Engagement
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Last Stream
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {filteredStreamers.map((streamer) => (
                    <tr key={streamer.streamerId} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">{streamer.streamerName}</div>
                        <div className="text-sm text-gray-500">{streamer.streamerId}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${getTierColor(streamer.subscriptionTier)}`}>
                          {streamer.subscriptionTier}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {streamer.totalStreams}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {streamer.averageViewers.toLocaleString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {streamer.peakViewers.toLocaleString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {formatDuration(streamer.totalViewTime)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {formatCurrency(streamer.totalRevenue)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`text-sm font-medium ${getEngagementColor(streamer.engagementRate)}`}>
                          {streamer.engagementRate.toFixed(1)}%
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {new Date(streamer.lastStreamDate).toLocaleDateString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="text-center py-12">
              <div className="text-gray-400 text-6xl mb-4">🎥</div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">No streamers found</h3>
              <p className="text-gray-600">Try adjusting your search or filters.</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
};