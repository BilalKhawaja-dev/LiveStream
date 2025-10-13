import React, { useState, useEffect } from 'react';
import {
  Box,
  VStack,
  HStack,
  Text,
  Card,
  CardBody,
  CardHeader,
  SimpleGrid,
  Badge,
  Progress,
  useColorModeValue,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  StatArrow,
  Alert,
  AlertIcon,
  AlertDescription,
  Button,
  Select,
} from '@chakra-ui/react';
import {
  ServerIcon,
  CpuChipIcon,
  CircleStackIcon,
  SignalIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon,
} from '@heroicons/react/24/outline';
import { Line, Bar } from 'react-chartjs-2';

interface SystemMetrics {
  services: Array<{
    name: string;
    status: 'healthy' | 'warning' | 'critical';
    uptime: number;
    responseTime: number;
    errorRate: number;
  }>;
  infrastructure: {
    cpu: number;
    memory: number;
    storage: number;
    network: number;
  };
  mediaServices: {
    mediaLive: { status: string; activeChannels: number };
    mediaStore: { status: string; storageUsed: number };
    cloudFront: { status: string; cacheHitRate: number };
  };
}

export const SystemDashboard: React.FC = () => {
  const [timeRange, setTimeRange] = useState('1h');
  const [metrics, setMetrics] = useState<SystemMetrics>({
    services: [
      { name: 'API Gateway', status: 'healthy', uptime: 99.9, responseTime: 120, errorRate: 0.1 },
      { name: 'Auth Service', status: 'healthy', uptime: 99.8, responseTime: 85, errorRate: 0.2 },
      { name: 'Stream Service', status: 'warning', uptime: 98.5, responseTime: 250, errorRate: 1.2 },
      { name: 'Database', status: 'healthy', uptime: 99.9, responseTime: 45, errorRate: 0.0 },
    ],
    infrastructure: { cpu: 65, memory: 72, storage: 45, network: 30 },
    mediaServices: {
      mediaLive: { status: 'healthy', activeChannels: 12 },
      mediaStore: { status: 'healthy', storageUsed: 85 },
      cloudFront: { status: 'healthy', cacheHitRate: 94.5 },
    },
  });

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'healthy': return 'green';
      case 'warning': return 'yellow';
      case 'critical': return 'red';
      default: return 'gray';
    }
  };

  const cpuChartData = {
    labels: ['00:00', '00:15', '00:30', '00:45', '01:00'],
    datasets: [{
      label: 'CPU Usage %',
      data: [45, 52, 65, 58, 65],
      borderColor: 'rgb(59, 130, 246)',
      backgroundColor: 'rgba(59, 130, 246, 0.1)',
      tension: 0.4,
      fill: true,
    }],
  };

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        <HStack justify="space-between">
          <Text fontSize="2xl" fontWeight="bold">System Monitoring</Text>
          <Select value={timeRange} onChange={(e) => setTimeRange(e.target.value)} w="150px">
            <option value="1h">Last Hour</option>
            <option value="24h">Last 24 Hours</option>
            <option value="7d">Last 7 Days</option>
          </Select>
        </HStack>

        {/* System Health Overview */}
        <SimpleGrid columns={{ base: 2, md: 4 }} spacing={4}>
          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>System Health</StatLabel>
            <StatNumber color="green.500">98.5%</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              Overall uptime
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Active Users</StatLabel>
            <StatNumber>2,847</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              +12% from yesterday
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Live Streams</StatLabel>
            <StatNumber>{metrics.mediaServices.mediaLive.activeChannels}</StatNumber>
            <StatHelpText>Currently active</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Response Time</StatLabel>
            <StatNumber>125ms</StatNumber>
            <StatHelpText>
              <StatArrow type="decrease" />
              Average API response
            </StatHelpText>
          </Stat>
        </SimpleGrid>

        {/* Service Status */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <HStack>
              <ServerIcon width="20px" />
              <Text fontWeight="bold">Service Status</Text>
            </HStack>
          </CardHeader>
          <CardBody>
            <SimpleGrid columns={{ base: 1, md: 2 }} spacing={4}>
              {metrics.services.map((service, index) => (
                <HStack key={index} justify="space-between" p={3} bg="gray.50" borderRadius="md">
                  <HStack>
                    <Badge colorScheme={getStatusColor(service.status)} variant="solid">
                      {service.status === 'healthy' ? <CheckCircleIcon width="12px" /> : <ExclamationTriangleIcon width="12px" />}
                    </Badge>
                    <Text fontWeight="medium">{service.name}</Text>
                  </HStack>
                  <VStack align="end" spacing={0}>
                    <Text fontSize="sm">{service.uptime}% uptime</Text>
                    <Text fontSize="xs" color="gray.500">{service.responseTime}ms avg</Text>
                  </VStack>
                </HStack>
              ))}
            </SimpleGrid>
          </CardBody>
        </Card>

        {/* Infrastructure Metrics */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6}>
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <CpuChipIcon width="20px" />
                <Text fontWeight="bold">Infrastructure Usage</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <VStack spacing={4} align="stretch">
                {Object.entries(metrics.infrastructure).map(([key, value]) => (
                  <VStack key={key} spacing={2} align="stretch">
                    <HStack justify="space-between">
                      <Text fontSize="sm" textTransform="capitalize">{key}</Text>
                      <Text fontSize="sm" fontWeight="medium">{value}%</Text>
                    </HStack>
                    <Progress
                      value={value}
                      colorScheme={value > 80 ? 'red' : value > 60 ? 'yellow' : 'green'}
                    />
                  </VStack>
                ))}
              </VStack>
            </CardBody>
          </Card>

          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <Text fontWeight="bold">CPU Usage Trend</Text>
            </CardHeader>
            <CardBody>
              <Box h="200px">
                <Line data={cpuChartData} options={{ responsive: true, maintainAspectRatio: false }} />
              </Box>
            </CardBody>
          </Card>
        </SimpleGrid>

        {/* Media Services */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <HStack>
              <SignalIcon width="20px" />
              <Text fontWeight="bold">Media Services</Text>
            </HStack>
          </CardHeader>
          <CardBody>
            <SimpleGrid columns={{ base: 1, md: 3 }} spacing={6}>
              <VStack spacing={3}>
                <Text fontWeight="medium">MediaLive</Text>
                <Badge colorScheme="green" variant="solid">HEALTHY</Badge>
                <Text fontSize="sm">{metrics.mediaServices.mediaLive.activeChannels} Active Channels</Text>
              </VStack>

              <VStack spacing={3}>
                <Text fontWeight="medium">MediaStore</Text>
                <Badge colorScheme="green" variant="solid">HEALTHY</Badge>
                <Text fontSize="sm">{metrics.mediaServices.mediaStore.storageUsed}% Storage Used</Text>
              </VStack>

              <VStack spacing={3}>
                <Text fontWeight="medium">CloudFront</Text>
                <Badge colorScheme="green" variant="solid">HEALTHY</Badge>
                <Text fontSize="sm">{metrics.mediaServices.cloudFront.cacheHitRate}% Cache Hit Rate</Text>
              </VStack>
            </SimpleGrid>
          </CardBody>
        </Card>

        {/* Alerts */}
        <VStack spacing={3} align="stretch">
          <Alert status="warning" borderRadius="md">
            <AlertIcon />
            <AlertDescription>
              Stream Service response time is above normal threshold (250ms avg)
            </AlertDescription>
          </Alert>
          
          <Alert status="info" borderRadius="md">
            <AlertIcon />
            <AlertDescription>
              Scheduled maintenance for MediaStore will begin at 02:00 UTC
            </AlertDescription>
          </Alert>
        </VStack>
      </VStack>
    </Box>
  );
};