import React from 'react';
import { AuthProvider } from '@streaming/auth';

const App: React.FC = () => {
  return (
    <AuthProvider>
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Developer Console
          </h1>
          <p className="text-gray-600">
            Developer console for system monitoring and debugging
          </p>
        </div>
      </div>
    </AuthProvider>
  );
};

export default App;