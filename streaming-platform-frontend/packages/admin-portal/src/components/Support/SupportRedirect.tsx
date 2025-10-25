import React, { useEffect } from 'react';
import { useAuth } from '../../stubs/auth';

export const SupportRedirect: React.FC = () => {
  const { user } = useAuth();

  useEffect(() => {
    // Redirect to support system with admin context
    const supportUrl = `${window.location.origin.replace(':3002', ':3005')}/support?source=admin&context=${encodeURIComponent(JSON.stringify({
      application: 'admin-portal',
      user_id: user?.id,
      user_role: user?.role,
      current_page: '/support',
      timestamp: new Date().toISOString(),
      admin_context: {
        accessing_from: 'admin_portal',
        permissions: ['user_management', 'system_monitoring', 'cloudwatch_access']
      }
    }))}`;
    
    window.location.href = supportUrl;
  }, [user]);

  return (
    <div className="min-h-screen bg-blue-50 flex items-center justify-center">
      <div className="text-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500 mx-auto mb-4"></div>
        <h2 className="text-2xl font-bold text-blue-900 mb-2">Redirecting to Support</h2>
        <p className="text-blue-600">Taking you to the support system with admin context...</p>
      </div>
    </div>
  );
};