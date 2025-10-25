import React from 'react';

export const ServiceNavigationMenu: React.FC<{ currentService?: string }> = ({ currentService }) => {
  return (
    <nav style={{ padding: '1rem', backgroundColor: '#f0f0f0', marginBottom: '1rem' }}>
      <div style={{ display: 'flex', gap: '1rem' }}>
        <a href="/viewer-portal/" style={{ textDecoration: 'none', color: currentService === 'viewer-portal' ? '#007bff' : '#333' }}>
          Viewer Portal
        </a>
        <a href="/creator-dashboard/" style={{ textDecoration: 'none', color: currentService === 'creator-dashboard' ? '#007bff' : '#333' }}>
          Creator Dashboard
        </a>
        <a href="/admin-portal/" style={{ textDecoration: 'none', color: currentService === 'admin-portal' ? '#007bff' : '#333' }}>
          Admin Portal
        </a>
        <a href="/developer-console/" style={{ textDecoration: 'none', color: currentService === 'developer-console' ? '#007bff' : '#333' }}>
          Developer Console
        </a>
        <a href="/analytics-dashboard/" style={{ textDecoration: 'none', color: currentService === 'analytics-dashboard' ? '#007bff' : '#333' }}>
          Analytics Dashboard
        </a>
        <a href="/support-system/" style={{ textDecoration: 'none', color: currentService === 'support-system' ? '#007bff' : '#333' }}>
          Support System
        </a>
      </div>
    </nav>
  );
};

export const CrossServiceProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return <div>{children}</div>;
};

export const SupportButton: React.FC = () => {
  return (
    <button 
      style={{ 
        position: 'fixed', 
        bottom: '20px', 
        right: '20px', 
        backgroundColor: '#007bff', 
        color: 'white', 
        border: 'none', 
        borderRadius: '50%', 
        width: '60px', 
        height: '60px', 
        cursor: 'pointer' 
      }}
      onClick={() => window.open('/support-system/', '_blank')}
    >
      ?
    </button>
  );
};
