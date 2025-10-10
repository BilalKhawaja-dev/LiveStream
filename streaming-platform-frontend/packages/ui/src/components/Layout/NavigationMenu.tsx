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
  FiBarChart3,
  FiCode,
  FiChevronDown,
} from 'react-icons/fi';
import { useGlobalStore, UserRole, ApplicationType, hasPermission } from '@streaming/shared';

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
    icon: FiBarChart3,
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
  const availableApps = Object.entries(appConfigs).filter(([_, config]) =>
    hasPermission(userRole, config.permission)
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