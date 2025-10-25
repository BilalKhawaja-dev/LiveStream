import React, { useState, useEffect } from 'react';
import { useAuth } from '../../stubs/auth';

interface User {
  user_id: string;
  username: string;
  email: string;
  display_name?: string;
  role: string;
  subscription_tier: string;
  subscription_status: string;
  created_at: string;
  total_streams?: number;
  active_streams?: number;
  total_views?: number;
}

export const UserManagement: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterRole, setFilterRole] = useState('all');
  const [filterTier, setFilterTier] = useState('all');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [showEditModal, setShowEditModal] = useState(false);
  const { apiBaseUrl } = useAuth();

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${apiBaseUrl}/users`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
        },
      });
      
      if (response.ok) {
        const data = await response.json();
        setUsers(data.users || []);
      } else {
        console.error('Failed to fetch users');
      }
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateUserSubscription = async (userId: string, newTier: string) => {
    try {
      const response = await fetch(`${apiBaseUrl}/users/subscription`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('access_token')}`,
        },
        body: JSON.stringify({
          user_id: userId,
          subscription_tier: newTier,
        }),
      });

      if (response.ok) {
        // Refresh users list
        await fetchUsers();
        setShowEditModal(false);
        setSelectedUser(null);
      } else {
        console.error('Failed to update subscription');
      }
    } catch (error) {
      console.error('Error updating subscription:', error);
    }
  };

  const filteredUsers = users.filter(user => {
    const matchesSearch = 
      user.username.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (user.display_name && user.display_name.toLowerCase().includes(searchTerm.toLowerCase()));
    
    const matchesRole = filterRole === 'all' || user.role === filterRole;
    const matchesTier = filterTier === 'all' || user.subscription_tier === filterTier;
    
    return matchesSearch && matchesRole && matchesTier;
  });

  const getStatusBadge = (status: string) => {
    const badgeClass = status === 'active' ? 'admin-badge-success' : 
                     status === 'cancelled' ? 'admin-badge-warning' : 'admin-badge-error';
    return <span className={`admin-badge ${badgeClass}`}>{status}</span>;
  };

  const getTierBadge = (tier: string) => {
    const badgeClass = tier === 'gold' ? 'admin-badge-warning' : 
                     tier === 'silver' ? 'admin-badge-info' : 'admin-badge-success';
    return <span className={`admin-badge ${badgeClass}`}>{tier}</span>;
  };

  if (loading) {
    return (
      <div className="admin-loading">
        <div className="admin-spinner"></div>
        <span className="ml-3 text-gray-600">Loading users...</span>
      </div>
    );
  }

  return (
    <div className="admin-fade-in">
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">User Management</h1>
        <p className="text-gray-600">Manage users, subscriptions, and view streaming statistics</p>
      </div>

      {/* Filters and Search */}
      <div className="admin-card mb-6">
        <div className="admin-card-body">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div>
              <label className="admin-label">Search Users</label>
              <input
                type="text"
                className="admin-input"
                placeholder="Search by username, email, or display name..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            <div>
              <label className="admin-label">Filter by Role</label>
              <select
                className="admin-select"
                value={filterRole}
                onChange={(e) => setFilterRole(e.target.value)}
              >
                <option value="all">All Roles</option>
                <option value="viewer">Viewer</option>
                <option value="creator">Creator</option>
                <option value="admin">Admin</option>
                <option value="support">Support</option>
              </select>
            </div>
            <div>
              <label className="admin-label">Filter by Tier</label>
              <select
                className="admin-select"
                value={filterTier}
                onChange={(e) => setFilterTier(e.target.value)}
              >
                <option value="all">All Tiers</option>
                <option value="bronze">Bronze</option>
                <option value="silver">Silver</option>
                <option value="gold">Gold</option>
              </select>
            </div>
            <div className="flex items-end">
              <button
                onClick={fetchUsers}
                className="admin-btn admin-btn-primary px-4 py-2 w-full"
              >
                🔄 Refresh
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Users Table */}
      <div className="admin-card">
        <div className="admin-card-header">
          <h2 className="text-xl font-semibold">Users ({filteredUsers.length})</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="admin-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Role</th>
                <th>Subscription</th>
                <th>Status</th>
                <th>Streaming Stats</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map((user) => (
                <tr key={user.user_id}>
                  <td>
                    <div>
                      <div className="font-medium text-gray-900">{user.username}</div>
                      <div className="text-sm text-gray-500">{user.email}</div>
                      {user.display_name && (
                        <div className="text-sm text-gray-400">{user.display_name}</div>
                      )}
                    </div>
                  </td>
                  <td>
                    <span className="admin-badge admin-badge-info capitalize">{user.role}</span>
                  </td>
                  <td>
                    {getTierBadge(user.subscription_tier)}
                  </td>
                  <td>
                    {getStatusBadge(user.subscription_status)}
                  </td>
                  <td>
                    <div className="text-sm">
                      <div>Streams: {user.total_streams || 0}</div>
                      <div>Active: {user.active_streams || 0}</div>
                      <div>Views: {user.total_views || 0}</div>
                    </div>
                  </td>
                  <td>
                    <div className="text-sm text-gray-500">
                      {new Date(user.created_at).toLocaleDateString()}
                    </div>
                  </td>
                  <td>
                    <button
                      onClick={() => {
                        setSelectedUser(user);
                        setShowEditModal(true);
                      }}
                      className="admin-btn admin-btn-secondary px-3 py-1 text-sm"
                    >
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Edit User Modal */}
      {showEditModal && selectedUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <h3 className="text-lg font-semibold mb-4">Edit User: {selectedUser.username}</h3>
            
            <div className="space-y-4">
              <div>
                <label className="admin-label">Subscription Tier</label>
                <select
                  className="admin-select"
                  defaultValue={selectedUser.subscription_tier}
                  onChange={(e) => {
                    if (e.target.value !== selectedUser.subscription_tier) {
                      updateUserSubscription(selectedUser.user_id, e.target.value);
                    }
                  }}
                >
                  <option value="bronze">Bronze</option>
                  <option value="silver">Silver</option>
                  <option value="gold">Gold</option>
                </select>
              </div>
              
              <div className="bg-gray-50 p-4 rounded-lg">
                <h4 className="font-medium mb-2">User Information</h4>
                <div className="text-sm space-y-1">
                  <div><strong>Email:</strong> {selectedUser.email}</div>
                  <div><strong>Role:</strong> {selectedUser.role}</div>
                  <div><strong>Status:</strong> {selectedUser.subscription_status}</div>
                  <div><strong>Created:</strong> {new Date(selectedUser.created_at).toLocaleDateString()}</div>
                </div>
              </div>
            </div>
            
            <div className="flex justify-end space-x-3 mt-6">
              <button
                onClick={() => {
                  setShowEditModal(false);
                  setSelectedUser(null);
                }}
                className="admin-btn admin-btn-secondary px-4 py-2"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};