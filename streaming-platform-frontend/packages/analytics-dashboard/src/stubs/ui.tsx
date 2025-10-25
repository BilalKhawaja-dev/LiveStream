import React, { ReactNode, Component, ErrorInfo } from 'react';

interface ErrorBoundaryState {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends Component<
  { children: ReactNode; fallback?: ReactNode },
  ErrorBoundaryState
> {
  constructor(props: { children: ReactNode; fallback?: ReactNode }) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || (
        <div style={{ padding: '20px', textAlign: 'center' }}>
          <h2>Something went wrong.</h2>
          <p>Please refresh the page or try again later.</p>
        </div>
      );
    }

    return this.props.children;
  }
}

export const AppLayout: React.FC<{ children: ReactNode }> = ({ children }) => {
  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f5f5f5' }}>
      <header style={{ 
        backgroundColor: '#fff', 
        padding: '1rem', 
        borderBottom: '1px solid #e0e0e0',
        marginBottom: '2rem'
      }}>
        <h1 style={{ margin: 0, color: '#333' }}>Streaming Platform</h1>
      </header>
      <main style={{ padding: '0 2rem' }}>
        {children}
      </main>
    </div>
  );
};
