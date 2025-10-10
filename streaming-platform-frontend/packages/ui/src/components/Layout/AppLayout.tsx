import React from 'react';
import {
  Box,
  Flex,
  HStack,
  VStack,
  IconButton,
  Avatar,
  Menu,
  MenuButton,
  MenuList,
  MenuItem,
  MenuDivider,
  useColorModeValue,
  useColorMode,
  Badge,
  Text,
  Button,
} from '@chakra-ui/react';
import { FiSun, FiMoon, FiBell, FiSettings, FiLogOut } from 'react-icons/fi';
import { useGlobalStore, UserRole, ApplicationType } from '@streaming/shared';
import { NavigationMenu } from './NavigationMenu';
import { NotificationCenter } from './NotificationCenter';

interface AppLayoutProps {
  children: React.ReactNode;
  currentApp: ApplicationType;
  showNavigation?: boolean;
}

export const AppLayout: React.FC<AppLayoutProps> = ({
  children,
  currentApp,
  showNavigation = true,
}) => {
  const { colorMode, toggleColorMode } = useColorMode();
  const { user, notifications, navigateWithContext } = useGlobalStore();
  
  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  
  const unreadCount = notifications.filter(n => !n.read).length;

  const handleLogout = () => {
    // TODO: Implement logout logic
    console.log('Logout clicked');
  };

  const handleProfileSettings = () => {
    navigateWithContext('admin-portal', { section: 'profile' });
  };

  return (
    <Box minH="100vh" bg={useColorModeValue('gray.50', 'gray.900')}>
      {/* Header */}
      <Flex
        as="header"
        align="center"
        justify="space-between"
        w="full"
        px={4}
        py={3}
        bg={bg}
        borderBottomWidth={1}
        borderColor={borderColor}
        position="sticky"
        top={0}
        zIndex={1000}
      >
        {/* Logo and App Title */}
        <HStack spacing={4}>
          <Text fontSize="xl" fontWeight="bold" color="brand.500">
            StreamPlatform
          </Text>
          <Badge colorScheme="gray" variant="subtle">
            {currentApp.replace('-', ' ').toUpperCase()}
          </Badge>
        </HStack>

        {/* Navigation Menu */}
        {showNavigation && (
          <NavigationMenu currentApp={currentApp} userRole={user.role} />
        )}

        {/* Right side actions */}
        <HStack spacing={2}>
          {/* Color mode toggle */}
          <IconButton
            aria-label="Toggle color mode"
            icon={colorMode === 'light' ? <FiMoon /> : <FiSun />}
            onClick={toggleColorMode}
            variant="ghost"
            size="sm"
          />

          {/* Notifications */}
          <NotificationCenter>
            <IconButton
              aria-label="Notifications"
              icon={<FiBell />}
              variant="ghost"
              size="sm"
              position="relative"
            >
              {unreadCount > 0 && (
                <Badge
                  colorScheme="red"
                  position="absolute"
                  top="-1"
                  right="-1"
                  fontSize="xs"
                  borderRadius="full"
                >
                  {unreadCount > 99 ? '99+' : unreadCount}
                </Badge>
              )}
            </IconButton>
          </NotificationCenter>

          {/* User menu */}
          <Menu>
            <MenuButton as={Button} variant="ghost" size="sm">
              <HStack spacing={2}>
                <Avatar size="sm" name={user.id} />
                <VStack spacing={0} align="start" display={{ base: 'none', md: 'flex' }}>
                  <Text fontSize="sm" fontWeight="medium">
                    {user.id || 'User'}
                  </Text>
                  <Badge
                    size="sm"
                    variant="subscription"
                    colorScheme={user.subscription}
                  >
                    {user.subscription}
                  </Badge>
                </VStack>
              </HStack>
            </MenuButton>
            <MenuList>
              <MenuItem icon={<FiSettings />} onClick={handleProfileSettings}>
                Profile Settings
              </MenuItem>
              <MenuDivider />
              <MenuItem icon={<FiLogOut />} onClick={handleLogout}>
                Sign Out
              </MenuItem>
            </MenuList>
          </Menu>
        </HStack>
      </Flex>

      {/* Main content */}
      <Box as="main" flex={1}>
        {children}
      </Box>
    </Box>
  );
};