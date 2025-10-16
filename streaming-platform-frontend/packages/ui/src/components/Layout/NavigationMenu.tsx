import React from 'react';
import {
  HStack,
  Button,
  Menu,
  MenuButton,
  MenuList,
  MenuItem,
  useColorModeValue,
} from '@chakra-ui/react';
import {
  FiPlay,
  FiVideo,
  FiSettings,
  FiHeadphones,
  FiBarChart,
  FiCode,
  FiChevronDown,
} from 'react-icons/fi';
// Temporary types until shared package is properly integrated
type UserRole = 'viewer' | 'creator' | 'admin' | 'support' | 'analyst' | 'developer';
type ApplicationType = 'viewer-portal' | 'creator-dashboard' | 'admin-portal' | 'support-system' | 'analytics-dashboard' | 'developer-console';

// Temporary permission check
const hasPermission = (_role: UserRole, _app: ApplicationType): boolean => {
  return true; // Simplified for now
};

// Mock store for now
const useGlobalStore = () => ({
  navigateWithContext: (_app: ApplicationType, _context?: any) => {},
});

interface NavigationMenuProps {
  currentApp: ApplicationType;
  userRole: UserRole;
}

const appConfigs = {
  'viewer-portal': {
    label: 'Watch',
    icon: FiPlay,
    permission: 'view_streams',
  },
  'creator-dashboard': {
    label: 'Create',
    icon: FiVideo,
    permission: 'create_streams',
  },
  'admin-portal': {
    label: 'Admin',
    icon: FiSettings,
    permission: 'admin_access',
  },
  'support-system': {
    label: 'Support',
    icon: FiHeadphones,
    permission: 'manage_tickets',
  },
  'analytics-dashboard': {
    label: 'Analytics',
    icon: FiBarChart,
    permission: 'view_analytics',
  },
  'developer-console': {
    label: 'Dev Tools',
    icon: FiCode,
    permission: 'debug_system',
  },
};

export const NavigationMenu: React.FC<NavigationMenuProps> = ({
  currentApp,
  userRole,
}) => {
  const { navigateWithContext } = useGlobalStore();
  const buttonBg = useColorModeValue('gray.100', 'gray.700');

  // Filter apps based on user permissions
  const availableApps = Object.entries(appConfigs).filter(([appKey, _config]) =>
    hasPermission(userRole, appKey as ApplicationType)
  );

  const handleNavigation = (app: ApplicationType) => {
    if (app !== currentApp) {
      navigateWithContext(app);
    }
  };

  // For mobile, show dropdown menu
  const isMobile = availableApps.length > 4;

  if (isMobile) {
    return (
      <Menu>
        <MenuButton
          as={Button}
          rightIcon={<FiChevronDown />}
          variant="ghost"
          size="sm"
        >
          Navigate
        </MenuButton>
        <MenuList>
          {availableApps.map(([appKey, config]) => {
            const IconComponent = config.icon;
            const isActive = appKey === currentApp;
            
            return (
              <MenuItem
                key={appKey}
                icon={<IconComponent />}
                onClick={() => handleNavigation(appKey as ApplicationType)}
                bg={isActive ? buttonBg : 'transparent'}
                fontWeight={isActive ? 'semibold' : 'normal'}
              >
                {config.label}
              </MenuItem>
            );
          })}
        </MenuList>
      </Menu>
    );
  }

  // For desktop, show horizontal buttons
  return (
    <HStack spacing={1}>
      {availableApps.map(([appKey, config]) => {
        const IconComponent = config.icon;
        const isActive = appKey === currentApp;
        
        return (
          <Button
            key={appKey}
            leftIcon={<IconComponent />}
            variant={isActive ? 'solid' : 'ghost'}
            size="sm"
            onClick={() => handleNavigation(appKey as ApplicationType)}
            bg={isActive ? 'brand.500' : 'transparent'}
            color={isActive ? 'white' : 'inherit'}
            _hover={{
              bg: isActive ? 'brand.600' : buttonBg,
            }}
          >
            {config.label}
          </Button>
        );
      })}
    </HStack>
  );
};