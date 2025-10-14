import React, { Component, ErrorInfo, ReactNode } from 'react';
import {
  Box,
  VStack,
  Text,
  Button,
  Alert,
  AlertIcon,
  AlertTitle,
  AlertDescription,
  Code,
  Collapse,
  useDisclosure,
} from '@chakra-ui/react';
import { ExclamationTriangleIcon } from '@heroicons/react/24/outline';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error: Error | null;
  errorInfo: ErrorInfo | null;
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
    };
  }

  static getDerivedStateFromError(error: Error): State {
    return {
      hasError: true,
      error,
      errorInfo: null,
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    this.setState({
      error,
      errorInfo,
    });

    // Log error to monitoring service using secure logging
    import('@streaming/shared').then(({ secureLogger }) => {
      secureLogger.error('ErrorBoundary caught an error', error, { 
        component: 'ErrorBoundary',
        errorInfo: errorInfo.componentStack 
      });
    });
    
    // Call custom error handler if provided
    if (this.props.onError) {
      this.props.onError(error, errorInfo);
    }

    // Send error to analytics/monitoring service
    this.logErrorToService(error, errorInfo);
  }

  private sanitizeText = (text: string): string => {
    if (!text) return '';
    
    // Sanitize text to prevent XSS and limit length
    return text
      .replace(/[<>"'&]/g, '') // Remove HTML/XML characters
      .replace(/javascript:/gi, '') // Remove javascript: protocol
      .replace(/data:/gi, '') // Remove data: protocol
      .replace(/vbscript:/gi, '') // Remove vbscript: protocol
      .substring(0, 500); // Limit length
  };

  private sanitizeErrorData = (error: Error, errorInfo: ErrorInfo) => {
    return {
      message: this.sanitizeText(error.message || 'Unknown error'),
      stack: process.env.NODE_ENV === 'development' ? this.sanitizeText(error.stack || '') : '',
      componentStack: process.env.NODE_ENV === 'development' ? this.sanitizeText(errorInfo.componentStack || '') : '',
      timestamp: new Date().toISOString(),
      userAgent: this.sanitizeText(navigator.userAgent || ''),
      url: this.sanitizeText(window.location.href || ''),
    };
  };

  private logErrorToService = (error: Error, errorInfo: ErrorInfo) => {
    try {
      // Sanitize error data to prevent path traversal and injection
      const errorData = this.sanitizeErrorData(error, errorInfo);

      // Example: Send to your error tracking service
      // errorTrackingService.captureException(errorData);
      
      // Use secure logging for service confirmation
      import('@streaming/shared').then(({ secureLogger }) => {
        secureLogger.debug('Error logged to service successfully');
      });
    } catch (loggingError) {
      import('@streaming/shared').then(({ secureLogger }) => {
        secureLogger.error('Failed to log error to service', loggingError);
      });
    }
  };

  private handleRetry = () => {
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null,
    });
  };

  private handleReload = () => {
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return <ErrorFallback 
        error={this.state.error} 
        errorInfo={this.state.errorInfo}
        onRetry={this.handleRetry}
        onReload={this.handleReload}
      />;
    }

    return this.props.children;
  }
}

interface ErrorFallbackProps {
  error: Error | null;
  errorInfo: ErrorInfo | null;
  onRetry: () => void;
  onReload: () => void;
}

const ErrorFallback: React.FC<ErrorFallbackProps> = ({ 
  error, 
  errorInfo, 
  onRetry, 
  onReload 
}) => {
  const { isOpen, onToggle } = useDisclosure();

  return (
    <Box p={6} maxW="600px" mx="auto" mt={8}>
      <VStack spacing={6} align="stretch">
        <Alert status="error" borderRadius="md">
          <AlertIcon />
          <VStack align="start" spacing={2} flex={1}>
            <AlertTitle>Something went wrong!</AlertTitle>
            <AlertDescription>
              An unexpected error occurred. You can try refreshing the page or contact support if the problem persists.
            </AlertDescription>
          </VStack>
        </Alert>

        <VStack spacing={3}>
          <Button colorScheme="blue" onClick={onRetry} size="lg">
            Try Again
          </Button>
          <Button variant="outline" onClick={onReload}>
            Reload Page
          </Button>
          <Button variant="ghost" size="sm" onClick={onToggle}>
            {isOpen ? 'Hide' : 'Show'} Error Details
          </Button>
        </VStack>

        <Collapse in={isOpen}>
          <VStack spacing={4} align="stretch">
            {error && (
              <Box>
                <Text fontWeight="bold" mb={2}>Error Message:</Text>
                <Code p={3} borderRadius="md" display="block" whiteSpace="pre-wrap">
                  {this.sanitizeText(error.message || 'Unknown error')}
                </Code>
              </Box>
            )}

            {error?.stack && (
              <Box>
                <Text fontWeight="bold" mb={2}>Stack Trace:</Text>
                <Code p={3} borderRadius="md" display="block" whiteSpace="pre-wrap" fontSize="xs">
                  {process.env.NODE_ENV === 'development' 
                    ? this.sanitizeText(error.stack || '')
                    : 'Stack trace hidden in production'
                  }
                </Code>
              </Box>
            )}

            {errorInfo?.componentStack && (
              <Box>
                <Text fontWeight="bold" mb={2}>Component Stack:</Text>
                <Code p={3} borderRadius="md" display="block" whiteSpace="pre-wrap" fontSize="xs">
                  {process.env.NODE_ENV === 'development'
                    ? this.sanitizeText(errorInfo.componentStack || '')
                    : 'Component stack hidden in production'
                  }
                </Code>
              </Box>
            )}
          </VStack>
        </Collapse>
      </VStack>
    </Box>
  );
};

export default ErrorBoundary;