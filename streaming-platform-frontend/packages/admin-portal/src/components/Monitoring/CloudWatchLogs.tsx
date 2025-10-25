import React, { useState, useEffect } from 'react';
import { useAuth } from '../../stubs/auth';

interface LogEntry {
  timestamp: string;
  message: string;
  level: 'INFO' | 'WARN' | 'ERROR' | 'DEBUG';
  source: string;
  requestId?: string;
}

export const CloudWatchLogs: React.FC = () => {
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterLevel, setFilterLevel] = useState('all');
  const [filterSource, setFilterSource] = useState('all');
  const [searchTerm, setSearchTerm] = useState(');
  const [autoRefresh, setAutoRefresh] = useState(false);
  const { apiBaseUrl } = useAuth();

  useEffect(() => {
    fetchLogs();
    
    let interval: NodeJS.Timeout;
    if (autoRefresh) {
      interval = setInterval(fetchLogs, 30000); // Refresh every 30 seconds
    }
    
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [autoRefresh]);

  const fetchLogs = async () => {
    try {
      setLoading(true);
      
      // Simulate CloudWatch logs - in real implementation, this would call CloudWatch API
      const mockLogs: LogEntry[] = [
        {
          timestamp: new Date().toISOString(),
          message: 'User authentication successful for user: testuser1',
          level: 'INFO',
          source: 'auth-handler',
          requestId: 'req-123456'
        },
        {
          timestamp: new Date(Date.now() - 60000).toISOString(),
          message: 'Stream started successfully: stream-789',
          level: 'INFO',
          source: 'streaming-handler',
          requestId: 'req-123457'
        },
        {
          timestamp: new Date(Date.now() - 120000).toISOString(),
          message: 'Database connection timeout - retrying',
          level: 'WARN',
          source: 'auth-handler',
          requestId: 'req-123458'
        },
        {
          timestamp: new Date(Date.now() - 180000).toISOString(),
          message: 'Failed to create MediaLive channel: InvalidParameterException',
          level: 'ERROR',
          source: 'streaming-handler',
          requestId: 'req-123459'
        },
        {
          timestamp: new Date(Date.now() - 240000).toISOString(),
          message: 'Support ticket created with AI analysis',
          level: 'INFO',
          source: 'support-handler',
          requestId: 'req-123460'
        },
        {
          timestamp: new Date(Date.now() - 300000).toISOString(),
          message: 'CloudWatch metrics retrieved successfully',
          level: 'DEBUG',
          source: 'analytics-handler',
          requestId: 'req-123461'
        }
      ];
      
      setLogs(mockLogs);
    } catch (error) {
      console.error('Error fetching logs:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredLogs = logs.filter(log => {
    const matchesLevel = filterLevel === 'all' || log.level === filterLevel;
    const matchesSource = filterSource === 'all' || log.source === filterSource;
    const matchesSearch = searchTerm === ' || 
      log.message.toLowerCase().includes(searchTerm.toLowerCase()) ||
      log.source.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (log.requestId && log.requestId.toLowerCase().includes(searchTerm.toLowerCase()));
    
    return matchesLevel && matchesSource && matchesSearch;
  });

  const getLevelBadge = (level: string) => {
    const badgeClass = level === 'ERROR' ? 'admin-badge-error' : 
                     level === 'WARN' ? 'admin-badge-warning' : 
                     level === 'INFO' ? 'admin-badge-info' : 'admin-badge admin-badge-secondary';
    return <span className={`admin-badge ${badgeClass}`}>{level}</span>;
  };

  const getLogSources = () => {
    const sources = [...new Set(logs.map(log => log.source))];
    return sources;
  };

  return (
    <div className="admin-fade-in">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">CloudWatch Logs</h1>
        <p className="text-gray-600">Monitor application logs and system events</p>
      </div>

      {/* Controls */}
      <div className="admin-card mb-6">
        <div className="admin-card-body">
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
            <div>
              <label className="admin-label">Search Logs</label>
              <input
                type="text"
                className="admin-input"
                placeholder="Search messages, sources, or request IDs..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            <div>
              <label className="admin-label">Filter by Level</label>
              <select
                className="admin-select"
                value={filterLevel}
                onChange={(e) => setFilterLevel(e.target.value)}
              >
                <option value="all">All Levels</option>
                <option value="ERROR">Error</option>
                <option value="WARN">Warning</option>
                <option value="INFO">Info</option>
                <option value="DEBUG">Debug</option>
              </select>
            </div>
            <div>
              <label className="admin-label">Filter by Source</label>
              <select
                className="admin-select"
                value={filterSource}
                onChange={(e) => setFilterSource(e.target.value)}
              >
                <option value="all">All Sources</option>
                {getLogSources().map(source => (
                  <option key={source} value={source}>{source}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="admin-label">Auto Refresh</label>
              <div className="flex items-center space-x-2 mt-2">
                <input
                  type="checkbox"
                  id="autoRefresh"
                  checked={autoRefresh}
                  onChange={(e) => setAutoRefresh(e.target.checked)}
                  className="rounded border-gray-300"
                />
                <label htmlFor="autoRefresh" className="text-sm text-gray-600">
                  Every 30s
                </label>
              </div>
            </div>
            <div className="flex items-end">
              <button
                onClick={fetchLogs}
                className="admin-btn admin-btn-primary px-4 py-2 w-full"
                disabled={loading}
              >
                {loading ? '🔄 Loading...' : '🔄 Refresh'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Log Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="admin-metric-card bg-gradient-to-r from-blue-500 to-blue-600">
          <div className="admin-metric-value">{filteredLogs.length}</div>
          <div className="admin-metric-label">Total Logs</div>
        </div>
        <div className="admin-metric-card bg-gradient-to-r from-red-500 to-red-600">
          <div className="admin-metric-value">
            {filteredLogs.filter(log => log.level === 'ERROR').length}
          </div>
          <div className="admin-metric-label">Errors</div>
        </div>
        <div className="admin-metric-card bg-gradient-to-r from-yellow-500 to-yellow-600">
          <div className="admin-metric-value">
            {filteredLogs.filter(log => log.level === 'WARN').length}
          </div>
          <div className="admin-metric-label">Warnings</div>
        </div>
        <div className="admin-metric-card bg-gradient-to-r from-green-500 to-green-600">
          <div className="admin-metric-value">
            {filteredLogs.filter(log => log.level === 'INFO').length}
          </div>
          <div className="admin-metric-label">Info Messages</div>
        </div>
      </div>

      {/* Logs Table */}
      <div className="admin-card">
        <div className="admin-card-header">
          <h2 className="text-xl font-semibold">Recent Logs</h2>
        </div>
        <div className="overflow-x-auto">
          {loading ? (
            <div className="admin-loading">
              <div className="admin-spinner"></div>
              <span className="ml-3 text-gray-600">Loading logs...</span>
            </div>
          ) : (
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Level</th>
                  <th>Source</th>
                  <th>Message</th>
                  <th>Request ID</th>
                </tr>
              </thead>
              <tbody>
                {filteredLogs.map((log, index) => (
                  <tr key={index}>
                    <td>
                      <div className="text-sm font-mono">
                        {new Date(log.timestamp).toLocaleString()}
                      </div>
                    </td>
                    <td>
                      {getLevelBadge(log.level)}
                    </td>
                    <td>
                      <span className="admin-badge admin-badge-info text-xs">
                        {log.source}
                      </span>
                    </td>
                    <td>
                      <div className="max-w-md">
                        <div className="text-sm text-gray-900 break-words">
                          {log.message}
                        </div>
                      </div>
                    </td>
                    <td>
                      {log.requestId && (
                        <span className="text-xs font-mono text-gray-500">
                          {log.requestId}
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {filteredLogs.length === 0 && !loading && (
        <div className="text-center py-8 text-gray-500">
          No logs found matching your filters.
        </div>
      )}
    </div>
  );
};