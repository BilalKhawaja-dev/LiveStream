import React from 'react';
import {
  Box,
  VStack,
  HStack,
  Text,
  IconButton,
  Popover,
  PopoverTrigger,
  PopoverContent,
  PopoverHeader,
  PopoverBody,
  PopoverCloseButton,
  Badge,
  Button,
  Divider,
  useColorModeValue,
} from '@chakra-ui/react';
import { FiX, FiExternalLink } from 'react-icons/fi';
import { useGlobalStore, formatRelativeTime } from '@streaming/shared';

interface NotificationCenterProps {
  children: React.ReactElement;
}

export const NotificationCenter: React.FC<NotificationCenterProps> = ({
  children,
}) => {
  const {
    notifications,
    markNotificationRead,
    clearNotifications,
    navigateWithContext,
  } = useGlobalStore();
  
  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.600');
  
  const unreadNotifications = notifications.filter(n => !n.read);
  const readNotifications = notifications.filter(n => n.read);

  const handleNotificationClick = (notification: any) => {
    markNotificationRead(notification.id);
    
    if (notification.actionUrl) {
      // Parse action URL to determine navigation
      const url = new URL(notification.actionUrl, window.location.origin);
      const pathSegments = url.pathname.split('/').filter(Boolean);
      
      if (pathSegments.length > 0) {
        const appMap: Record<string, any> = {
          viewer: 'viewer-portal',
          creator: 'creator-dashboard',
          admin: 'admin-portal',
          support: 'support-system',
          analytics: 'analytics-dashboard',
          dev: 'developer-console',
        };
        
        const targetApp = appMap[pathSegments[0]];
        if (targetApp) {
          navigateWithContext(targetApp, { 
            path: url.pathname,
            params: Object.fromEntries(url.searchParams),
          });
        }
      }
    }
  };

  const getNotificationColor = (type: string) => {
    const colors = {
      info: 'blue',
      warning: 'orange',
      error: 'red',
      success: 'green',
    };
    return colors[type as keyof typeof colors] || 'gray';
  };

  return (
    <Popover placement="bottom-end">
      <PopoverTrigger>{children}</PopoverTrigger>
      <PopoverContent w="400px" bg={bg} borderColor={borderColor}>
        <PopoverHeader>
          <HStack justify="space-between">
            <Text fontWeight="semibold">Notifications</Text>
            {notifications.length > 0 && (
              <Button
                size="xs"
                variant="ghost"
                onClick={clearNotifications}
              >
                Clear All
              </Button>
            )}
          </HStack>
        </PopoverHeader>
        <PopoverCloseButton />
        <PopoverBody p={0} maxH="400px" overflowY="auto">
          {notifications.length === 0 ? (
            <Box p={4} textAlign="center">
              <Text color="gray.500">No notifications</Text>
            </Box>
          ) : (
            <VStack spacing={0} align="stretch">
              {/* Unread notifications */}
              {unreadNotifications.length > 0 && (
                <>
                  {unreadNotifications.map((notification) => (
                    <Box
                      key={notification.id}
                      p={3}
                      borderBottomWidth={1}
                      borderColor={borderColor}
                      cursor={notification.actionUrl ? 'pointer' : 'default'}
                      onClick={() => handleNotificationClick(notification)}
                      _hover={{
                        bg: useColorModeValue('gray.50', 'gray.700'),
                      }}
                    >
                      <HStack align="start" spacing={3}>
                        <Badge
                          colorScheme={getNotificationColor(notification.type)}
                          variant="solid"
                          fontSize="xs"
                        >
                          {notification.type}
                        </Badge>
                        <VStack align="start" spacing={1} flex={1}>
                          <Text fontSize="sm" fontWeight="medium">
                            {notification.title}
                          </Text>
                          <Text fontSize="xs" color="gray.500">
                            {notification.message}
                          </Text>
                          <Text fontSize="xs" color="gray.400">
                            {formatRelativeTime(notification.timestamp)}
                          </Text>
                        </VStack>
                        <HStack spacing={1}>
                          {notification.actionUrl && (
                            <IconButton
                              aria-label="Open"
                              icon={<FiExternalLink />}
                              size="xs"
                              variant="ghost"
                            />
                          )}
                          <IconButton
                            aria-label="Dismiss"
                            icon={<FiX />}
                            size="xs"
                            variant="ghost"
                            onClick={(e) => {
                              e.stopPropagation();
                              markNotificationRead(notification.id);
                            }}
                          />
                        </HStack>
                      </HStack>
                    </Box>
                  ))}
                  
                  {readNotifications.length > 0 && (
                    <Divider />
                  )}
                </>
              )}
              
              {/* Read notifications */}
              {readNotifications.slice(0, 5).map((notification) => (
                <Box
                  key={notification.id}
                  p={3}
                  borderBottomWidth={1}
                  borderColor={borderColor}
                  opacity={0.7}
                  cursor={notification.actionUrl ? 'pointer' : 'default'}
                  onClick={() => handleNotificationClick(notification)}
                  _hover={{
                    bg: useColorModeValue('gray.50', 'gray.700'),
                  }}
                >
                  <HStack align="start" spacing={3}>
                    <Badge
                      colorScheme={getNotificationColor(notification.type)}
                      variant="outline"
                      fontSize="xs"
                    >
                      {notification.type}
                    </Badge>
                    <VStack align="start" spacing={1} flex={1}>
                      <Text fontSize="sm">
                        {notification.title}
                      </Text>
                      <Text fontSize="xs" color="gray.500">
                        {notification.message}
                      </Text>
                      <Text fontSize="xs" color="gray.400">
                        {formatRelativeTime(notification.timestamp)}
                      </Text>
                    </VStack>
                    {notification.actionUrl && (
                      <IconButton
                        aria-label="Open"
                        icon={<FiExternalLink />}
                        size="xs"
                        variant="ghost"
                      />
                    )}
                  </HStack>
                </Box>
              ))}
            </VStack>
          )}
        </PopoverBody>
      </PopoverContent>
    </Popover>
  );
};