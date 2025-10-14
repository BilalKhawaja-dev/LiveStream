/**
 * Secure logging utility to prevent log injection attacks
 */

interface LogContext {
  userId?: string;
  sessionId?: string;
  component?: string;
  action?: string;
  timestamp?: string;
}

class SecureLogger {
  private static instance: SecureLogger;
  private isDevelopment = process.env.NODE_ENV === 'development';

  private constructor() {}

  static getInstance(): SecureLogger {
    if (!SecureLogger.instance) {
      SecureLogger.instance = new SecureLogger();
    }
    return SecureLogger.instance;
  }

  /**
   * Sanitize log message to prevent injection attacks
   */
  private sanitizeMessage(message: any): string {
    if (typeof message === 'string') {
      // Remove potential injection patterns
      return message
        .replace(/[\r\n\t]/g, ' ') // Remove line breaks and tabs
        .replace(/[<>]/g, '') // Remove HTML tags
        .replace(/javascript:/gi, '') // Remove javascript: protocol
        .replace(/data:/gi, '') // Remove data: protocol
        .replace(/vbscript:/gi, '') // Remove vbscript: protocol
        .substring(0, 1000); // Limit message length
    }
    
    if (message instanceof Error) {
      return this.sanitizeMessage(message.message);
    }
    
    try {
      return this.sanitizeMessage(JSON.stringify(message));
    } catch {
      return '[Unserializable object]';
    }
  }

  /**
   * Sanitize error object for safe logging
   */
  private sanitizeError(error: any): Record<string, any> {
    if (error instanceof Error) {
      return {
        name: this.sanitizeMessage(error.name),
        message: this.sanitizeMessage(error.message),
        stack: this.isDevelopment ? this.sanitizeMessage(error.stack || '') : '[Stack trace hidden in production]'
      };
    }
    
    if (typeof error === 'object' && error !== null) {
      const sanitized: Record<string, any> = {};
      Object.keys(error).forEach(key => {
        if (typeof error[key] === 'string' || typeof error[key] === 'number') {
          sanitized[key] = this.sanitizeMessage(error[key]);
        }
      });
      return sanitized;
    }
    
    return { error: this.sanitizeMessage(error) };
  }

  /**
   * Create structured log entry
   */
  private createLogEntry(level: string, message: string, context?: LogContext, error?: any) {
    const entry = {
      timestamp: new Date().toISOString(),
      level: level.toUpperCase(),
      message: this.sanitizeMessage(message),
      ...(context && {
        context: {
          userId: context.userId ? this.sanitizeMessage(context.userId) : undefined,
          sessionId: context.sessionId ? this.sanitizeMessage(context.sessionId) : undefined,
          component: context.component ? this.sanitizeMessage(context.component) : undefined,
          action: context.action ? this.sanitizeMessage(context.action) : undefined,
        }
      }),
      ...(error && { error: this.sanitizeError(error) })
    };

    return entry;
  }

  /**
   * Send log to external service (in production)
   */
  private async sendToService(logEntry: any) {
    if (!this.isDevelopment) {
      try {
        // In production, send to your logging service
        // Example: await fetch('/api/logs', { method: 'POST', body: JSON.stringify(logEntry) });
        console.log('[SECURE LOG]', JSON.stringify(logEntry));
      } catch (error) {
        // Fallback to console if service fails
        console.error('[LOG SERVICE ERROR]', error);
      }
    }
  }

  /**
   * Log info message
   */
  info(message: string, context?: LogContext) {
    const entry = this.createLogEntry('info', message, context);
    
    if (this.isDevelopment) {
      console.info('[INFO]', entry.message, context ? JSON.stringify(entry.context) : '');
    }
    
    this.sendToService(entry);
  }

  /**
   * Log warning message
   */
  warn(message: string, context?: LogContext) {
    const entry = this.createLogEntry('warn', message, context);
    
    if (this.isDevelopment) {
      console.warn('[WARN]', entry.message, context ? JSON.stringify(entry.context) : '');
    }
    
    this.sendToService(entry);
  }

  /**
   * Log error message
   */
  error(message: string, error?: any, context?: LogContext) {
    const entry = this.createLogEntry('error', message, context, error);
    
    if (this.isDevelopment) {
      console.error('[ERROR]', entry.message, JSON.stringify(entry.error), context ? JSON.stringify(entry.context) : '');
    }
    
    this.sendToService(entry);
  }

  /**
   * Log debug message (development only)
   */
  debug(message: string, data?: any, context?: LogContext) {
    if (this.isDevelopment) {
      const entry = this.createLogEntry('debug', message, context, data);
      console.debug('[DEBUG]', entry.message, JSON.stringify(data), context ? JSON.stringify(entry.context) : '');
    }
  }

  /**
   * Log security event
   */
  security(message: string, context?: LogContext & { severity?: 'low' | 'medium' | 'high' | 'critical' }) {
    const entry = this.createLogEntry('security', message, context);
    
    // Always log security events
    console.warn('[SECURITY]', entry.message, JSON.stringify(entry.context));
    
    // Send to security monitoring service
    this.sendToService({
      ...entry,
      type: 'security',
      severity: context?.severity || 'medium'
    });
  }
}

// Export singleton instance
export const secureLogger = SecureLogger.getInstance();

// Export types
export type { LogContext };