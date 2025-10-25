import React from 'react';

export const ErrorTracking: React.FC = () => {
  return (
    <div className="error-tracking">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Error Tracking</h1>
        <p className="text-gray-600">Monitor and debug application errors</p>
      </div>
      
      <div className="bg-white rounded-lg shadow-md p-8 text-center">
        <div className="text-6xl mb-4">🐛</div>
        <h2 className="text-xl font-semibold text-gray-900 mb-2">Error Tracking & Debugging</h2>
        <p className="text-gray-600">Error monitoring tools coming soon...</p>
      </div>
    </div>
  );
};