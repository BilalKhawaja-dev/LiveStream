# Streaming Platform Frontend Suite

A comprehensive frontend ecosystem for a live streaming platform with 6 interconnected React applications.

## 🏗️ Architecture

This monorepo contains:

### 📱 Applications
- **Viewer Portal** (`/viewer`) - Customer-facing streaming interface
- **Creator Dashboard** (`/creator`) - Stream management and analytics
- **Admin Portal** (`/admin`) - Platform administration
- **Support System** (`/support`) - Customer service with AI integration
- **Analytics Dashboard** (`/analytics`) - Business intelligence
- **Developer Console** (`/dev`) - System monitoring and debugging

### 📦 Shared Packages
- **@streaming/shared** - Common types, utilities, and global state
- **@streaming/ui** - Shared UI components and theme
- **@streaming/auth** - Authentication service with Cognito integration
- **@streaming/api** - API client and data fetching utilities

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- npm 9+
- Docker (for containerized development)

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd streaming-platform-frontend

# Install dependencies
npm install

# Bootstrap packages
npm run bootstrap

# Start all applications in development mode
npm run dev
```

### Individual Application Development
```bash
# Start specific application
cd apps/viewer-portal
npm run dev

# Or use Docker Compose for full environment
docker-compose -f docker-compose.dev.yml up viewer-portal
```

## 🔧 Development

### Environment Setup
1. Copy `.env.example` to `.env`
2. Configure AWS Cognito credentials
3. Set API endpoints and feature flags

### Available Scripts
- `npm run dev` - Start all apps in development mode
- `npm run build` - Build all applications
- `npm run test` - Run tests across all packages
- `npm run lint` - Lint all code
- `npm run type-check` - TypeScript type checking

### Docker Development
```bash
# Start all services
docker-compose -f docker-compose.dev.yml up

# Start specific service
docker-compose -f docker-compose.dev.yml up viewer-portal

# Build and start
docker-compose -f docker-compose.dev.yml up --build
```

## 🌐 Application URLs (Development)

- **Viewer Portal**: http://localhost:3001
- **Creator Dashboard**: http://localhost:3002  
- **Admin Portal**: http://localhost:3003
- **Support System**: http://localhost:3004
- **Analytics Dashboard**: http://localhost:3005
- **Developer Console**: http://localhost:3006

## 🔗 Cross-Application Navigation

Applications are interconnected with context preservation:

```typescript
import { useGlobalStore } from '@streaming/shared';

const { navigateWithContext } = useGlobalStore();

// Navigate with context data
navigateWithContext('support-system', { 
  ticketId: '12345',
  userId: 'user-456' 
});
```

## 🎨 UI Components

Shared components from `@streaming/ui`:

```typescript
import { AppLayout, theme } from '@streaming/ui';
import { ChakraProvider } from '@chakra-ui/react';

function App() {
  return (
    <ChakraProvider theme={theme}>
      <AppLayout currentApp="viewer-portal">
        {/* Your app content */}
      </AppLayout>
    </ChakraProvider>
  );
}
```

## 🔐 Authentication

AWS Cognito integration with role-based access:

```typescript
import { AuthProvider, useAuth } from '@streaming/auth';

// Wrap your app
<AuthProvider>
  <App />
</AuthProvider>

// Use in components
const { user, signIn, signOut } = useAuth();
```

## 📊 State Management

Global state with Zustand:

```typescript
import { useGlobalStore } from '@streaming/shared';

const { 
  user, 
  notifications, 
  addNotification,
  navigateWithContext 
} = useGlobalStore();
```

## 🧪 Testing

```bash
# Run all tests
npm run test

# Test specific package
cd packages/shared
npm test

# Test specific app
cd apps/viewer-portal
npm test
```

## 📦 Building for Production

```bash
# Build all applications
npm run build

# Build Docker images
npm run docker:build

# Push to ECR
npm run docker:push
```

## 🚀 Deployment

Each application is containerized and deployed to ECS:

```bash
# Deploy all applications
npm run deploy

# Deploy specific application
cd apps/viewer-portal
npm run deploy
```

## 🔧 Configuration

### Environment Variables
See `.env.example` for all available configuration options.

### AWS Services Integration
- **Cognito** - Authentication and user management
- **MediaLive/MediaStore** - Video streaming
- **DynamoDB** - User data and sessions
- **Aurora** - Application data
- **Athena** - Analytics queries
- **S3** - File storage
- **CloudWatch** - Logging and monitoring

## 📚 Documentation

- [Architecture Guide](docs/architecture.md)
- [Development Guide](docs/development.md)
- [Deployment Guide](docs/deployment.md)
- [API Documentation](docs/api.md)
- [Component Library](packages/ui/storybook)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details