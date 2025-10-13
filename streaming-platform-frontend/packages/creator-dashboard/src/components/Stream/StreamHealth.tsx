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
  Progress,
  Badge,
  Alert,
  AlertIcon,
  AlertDescription,
  useColorModeValue,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  StatArrow,
  Divider,
  Button,
  Tooltip,
  Icon,
} from '@chakra-ui/react';
import {
  SignalIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon,
  XCircleIcon,
  ClockIcon,
  CpuChipIcon,
  ServerIcon,
} from '@heroicons/react/24/outline';
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip as ChartTooltip,
  Legend,
} from 'chart.js';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  ChartTooltip,
  Legend
);

interface HealthMetric {
  name: string;
  value: number;
  unit: string;
  status: 'excellent' | 'good' | 'warning' | 'critical';
  threshold: {
    excellent: number;
    good: number;
    warning: number;
  };
  history: number[];
}

interface StreamHealthData {
  overall: 'excellent' | 'good' | 'warning' | 'critical';
  metrics: {
    bitrate: HealthMetric;
    framerate: HealthMetric;
    droppedFrames: HealthMetric;
    bandwidth: HealthMetric;
    latency: HealthMetric;
    cpu: HealthMetric;
    memory: HealthMetric;
    networkStability: HealthMetric;
  };
  alerts: Array<{
    id: string;
    type: 'error' | 'warning' | 'info';
    message: string;
    timestamp: Date;
    resolved: boolean;
  }>;
  recommendations: string[];
}

export const StreamHealth: React.FC = () => {
  const [healthData, setHealthData] = useState<StreamHealthData>({
    overall: 'good',
    metrics: {
      bitrate: {
        name: 'Bitrate',
        value: 4850,
        unit: 'kbps',
        status: 'good',
        threshold: { excellent: 4900, good: 4500, warning: 4000 },
        history: [4800, 4820, 4850, 4830, 4850, 4870, 4850],
      },
      framerate: {
        name: 'Framerate',
        value: 29.8,
        unit: 'fps',
        status: 'excellent',
        threshold: { excellent: 29, good: 28, warning: 25 },
        history: [30, 29.9, 29.8, 29.7, 29.8, 29.9, 29.8],
      },
      droppedFrames: {
        name: 'Dropped Frames',
        value: 0.2,
        unit: '%',
        status: 'excellent',
        threshold: { excellent: 0.5, good: 1, warning: 2 },
        history: [0.1, 0.2, 0.1, 0.3, 0.2, 0.1, 0.2],
      },
      bandwidth: {
        name: 'Bandwidth Usage',
        value: 5.2,
        unit: 'Mbps',
        status: 'good',
        threshold: { excellent: 6, good: 5, warning: 4 },
        history: [5.1, 5.2, 5.3, 5.1, 5.2, 5.4, 5.2],
      },
      latency: {
        name: 'Stream Latency',
        value: 2.8,
        unit: 'sec',
        status: 'good',
        threshold: { excellent: 2, good: 3, warning: 5 },
        history: [2.9, 2.8, 2.7, 2.8, 2.9, 2.8, 2.8],
      },
      cpu: {
        name: 'CPU Usage',
        value: 65,
        unit: '%',
        status: 'good',
        threshold: { excellent: 50, good: 70, warning: 85 },
        history: [62, 64, 65, 67, 65, 63, 65],
      },
      memory: {
        name: 'Memory Usage',
        value: 58,
        unit: '%',
        status: 'excellent',
        threshold: { excellent: 60, good: 75, warning: 90 },
        history: [55, 57, 58, 59, 58, 56, 58],
      },
      networkStability: {
        name: 'Network Stability',
        value: 98.5,
        unit: '%',
        status: 'excellent',
        threshold: { excellent: 98, good: 95, warning: 90 },
        history: [98.2, 98.5, 98.7, 98.3, 98.5, 98.8, 98.5],
      },
    },
    alerts: [
      {
        id: '1',
        type: 'warning',
        message: 'Bitrate slightly below optimal range',
        timestamp: new Date(Date.now() - 5 * 60 * 1000),
        resolved: false,
      },
      {
        id: '2',
        type: 'info',
        message: 'Stream quality automatically adjusted for network conditions',
        timestamp: new Date(Date.now() - 15 * 60 * 1000),
        resolved: true,
      },
    ],
    recommendations: [
      'Consider increasing bitrate to 5000 kbps for better quality',
      'Monitor CPU usage during peak hours',
      'Network connection is stable - good for streaming',
    ],
  });

  const [isLive, setIsLive] = useState(true);

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const cardBg = useColorModeValue('gray.50', 'gray.700');

  useEffect(() => {
    let interval: NodeJS.Timeout;
    
    if (isLive) {
      interval = setInterval(() => {
        updateHealthMetrics();
      }, 5000);
    }
    
    return () => {
      if (interval) {
        clearInterval(interval);
      }
    };
  }, [isLive]);

  const updateHealthMetrics = () => {
    setHealthData(prev => {
      const newData = { ...prev };
      
      // Simulate metric updates
      Object.keys(newData.metrics).forEach(key => {
        const metric = newData.metrics[key as keyof typeof newData.metrics];
        const variation = (Math.random() - 0.5) * 0.1;
        const newValue = metric.value * (1 + variation);
        
        // Update value and history
        metric.value = Math.max(0, newValue);
        metric.history = [...metric.history.slice(1), metric.value];
        
        // Update status based on thresholds
        if (key === 'droppedFrames') {
          // Lower is better for dropped frames
          if (metric.value <= metric.threshold.excellent) {
            metric.status = 'excellent';
          } else if (metric.value <= metric.threshold.good) {
            metric.status = 'good';
          } else if (metric.value <= metric.threshold.warning) {
            metric.status = 'warning';
          } else {
            metric.status = 'critical';
          }
        } else {
          // Higher is better for other metrics
          if (metric.value >= metric.threshold.excellent) {
            metric.status = 'excellent';
          } else if (metric.value >= metric.threshold.good) {
            metric.status = 'good';
          } else if (metric.value >= metric.threshold.warning) {
            metric.status = 'warning';
          } else {
            metric.status = 'critical';
          }
        }
      });
      
      // Calculate overall health
      const statuses = Object.values(newData.metrics).map(m => m.status);
      const criticalCount = statuses.filter(s => s === 'critical').length;
      const warningCount = statuses.filter(s => s === 'warning').length;
      
      if (criticalCount > 0) {
        newData.overall = 'critical';
      } else if (warningCount > 2) {
        newData.overall = 'warning';
      } else if (warningCount > 0) {
        newData.overall = 'good';
      } else {
        newData.overall = 'excellent';
      }
      
      return newData;
    });
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'excellent': return 'green';
      case 'good': return 'blue';
      case 'warning': return 'yellow';
      case 'critical': return 'red';
      default: return 'gray';
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'excellent': return CheckCircleIcon;
      case 'good': return CheckCircleIcon;
      case 'warning': return ExclamationTriangleIcon;
      case 'critical': return XCircleIcon;
      default: return SignalIcon;
    }
  };

  const createChartData = (metric: HealthMetric) => ({
    labels: metric.history.map((_, index) => `${index * 5}s ago`).reverse(),
    datasets: [
      {
        label: metric.name,
        data: metric.history,
        borderColor: `var(--chakra-colors-${getStatusColor(metric.status)}-500)`,
        backgroundColor: `var(--chakra-colors-${getStatusColor(metric.status)}-100)`,
        tension: 0.4,
        fill: true,
      },
    ],
  });

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        display: false,
      },
    },
    scales: {
      x: {
        display: false,
      },
      y: {
        display: false,
      },
    },
    elements: {
      point: {
        radius: 0,
      },
    },
  };

  if (!isLive) {
    return (
      <Box textAlign="center" py={8}>
        <Text fontSize="lg" color="gray.500">
          Stream health monitoring is available when live
        </Text>
      </Box>
    );
  }

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        {/* Overall Health Status */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <HStack justify="space-between">
              <Text fontSize="xl" fontWeight="bold">Stream Health</Text>
              <HStack>
                <Icon
                  as={getStatusIcon(healthData.overall)}
                  color={`${getStatusColor(healthData.overall)}.500`}
                  w={6}
                  h={6}
                />
                <Badge
                  colorScheme={getStatusColor(healthData.overall)}
                  variant="solid"
                  fontSize="md"
                  px={3}
                  py={1}
                >
                  {healthData.overall.toUpperCase()}
                </Badge>
              </HStack>
            </HStack>
          </CardHeader>
        </Card>

        {/* Key Metrics Grid */}
        <SimpleGrid columns={{ base: 2, md: 4 }} spacing={4}>
          {Object.entries(healthData.metrics).map(([key, metric]) => (
            <Card key={key} bg={cardBg} border="1px" borderColor={borderColor}>
              <CardBody>
                <VStack spacing={3} align="stretch">
                  <HStack justify="space-between">
                    <Text fontSize="sm" fontWeight="medium">{metric.name}</Text>
                    <Badge
                      colorScheme={getStatusColor(metric.status)}
                      variant="subtle"
                      size="sm"
                    >
                      {metric.status}
                    </Badge>
                  </HStack>
                  
                  <Text fontSize="2xl" fontWeight="bold">
                    {typeof metric.value === 'number' ? metric.value.toFixed(1) : metric.value}
                    <Text as="span" fontSize="sm" color="gray.500" ml={1}>
                      {metric.unit}
                    </Text>
                  </Text>
                  
                  {/* Mini Chart */}
                  <Box h="40px">
                    <Line data={createChartData(metric)} options={chartOptions} />
                  </Box>
                  
                  {/* Threshold Indicator */}
                  <Progress
                    value={key === 'droppedFrames' ? 
                      Math.max(0, 100 - (metric.value / metric.threshold.warning) * 100) :
                      (metric.value / metric.threshold.excellent) * 100
                    }
                    colorScheme={getStatusColor(metric.status)}
                    size="sm"
                  />
                </VStack>
              </CardBody>
            </Card>
          ))}
        </SimpleGrid>

        {/* Detailed Performance Stats */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6}>
          {/* System Performance */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <CpuChipIcon width="20px" />
                <Text fontWeight="bold">System Performance</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <VStack spacing={4} align="stretch">
                <VStack spacing={2} align="stretch">
                  <HStack justify="space-between">
                    <Text fontSize="sm">CPU Usage</Text>
                    <Text fontSize="sm" fontWeight="medium">
                      {healthData.metrics.cpu.value.toFixed(1)}%
                    </Text>
                  </HStack>
                  <Progress
                    value={healthData.metrics.cpu.value}
                    colorScheme={getStatusColor(healthData.metrics.cpu.status)}
                  />
                </VStack>
                
                <VStack spacing={2} align="stretch">
                  <HStack justify="space-between">
                    <Text fontSize="sm">Memory Usage</Text>
                    <Text fontSize="sm" fontWeight="medium">
                      {healthData.metrics.memory.value.toFixed(1)}%
                    </Text>
                  </HStack>
                  <Progress
                    value={healthData.metrics.memory.value}
                    colorScheme={getStatusColor(healthData.metrics.memory.status)}
                  />
                </VStack>
                
                <VStack spacing={2} align="stretch">
                  <HStack justify="space-between">
                    <Text fontSize="sm">Network Stability</Text>
                    <Text fontSize="sm" fontWeight="medium">
                      {healthData.metrics.networkStability.value.toFixed(1)}%
                    </Text>
                  </HStack>
                  <Progress
                    value={healthData.metrics.networkStability.value}
                    colorScheme={getStatusColor(healthData.metrics.networkStability.status)}
                  />
                </VStack>
              </VStack>
            </CardBody>
          </Card>

          {/* Stream Quality */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <SignalIcon width="20px" />
                <Text fontWeight="bold">Stream Quality</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <SimpleGrid columns={2} spacing={4}>
                <Stat>
                  <StatLabel>Bitrate</StatLabel>
                  <StatNumber fontSize="lg">
                    {healthData.metrics.bitrate.value.toFixed(0)} kbps
                  </StatNumber>
                  <StatHelpText>
                    <StatArrow type="increase" />
                    Target: 5000 kbps
                  </StatHelpText>
                </Stat>
                
                <Stat>
                  <StatLabel>Framerate</StatLabel>
                  <StatNumber fontSize="lg">
                    {healthData.metrics.framerate.value.toFixed(1)} fps
                  </StatNumber>
                  <StatHelpText>
                    <StatArrow type="increase" />
                    Target: 30 fps
                  </StatHelpText>
                </Stat>
                
                <Stat>
                  <StatLabel>Dropped Frames</StatLabel>
                  <StatNumber fontSize="lg">
                    {healthData.metrics.droppedFrames.value.toFixed(2)}%
                  </StatNumber>
                  <StatHelpText>
                    <StatArrow type="decrease" />
                    Last 5 minutes
                  </StatHelpText>
                </Stat>
                
                <Stat>
                  <StatLabel>Latency</StatLabel>
                  <StatNumber fontSize="lg">
                    {healthData.metrics.latency.value.toFixed(1)}s
                  </StatNumber>
                  <StatHelpText>
                    <StatArrow type="decrease" />
                    End-to-end
                  </StatHelpText>
                </Stat>
              </SimpleGrid>
            </CardBody>
          </Card>
        </SimpleGrid>

        {/* Alerts and Recommendations */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6}>
          {/* Active Alerts */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <Text fontWeight="bold">Active Alerts</Text>
            </CardHeader>
            <CardBody>
              <VStack spacing={3} align="stretch">
                {healthData.alerts.filter(alert => !alert.resolved).length === 0 ? (
                  <Text color="gray.500" textAlign="center" py={4}>
                    No active alerts
                  </Text>
                ) : (
                  healthData.alerts
                    .filter(alert => !alert.resolved)
                    .map(alert => (
                      <Alert key={alert.id} status={alert.type} borderRadius="md">
                        <AlertIcon />
                        <VStack align="start" spacing={1} flex={1}>
                          <AlertDescription>{alert.message}</AlertDescription>
                          <Text fontSize="xs" color="gray.500">
                            {alert.timestamp.toLocaleTimeString()}
                          </Text>
                        </VStack>
                      </Alert>
                    ))
                )}
              </VStack>
            </CardBody>
          </Card>

          {/* Recommendations */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <Text fontWeight="bold">Recommendations</Text>
            </CardHeader>
            <CardBody>
              <VStack spacing={3} align="stretch">
                {healthData.recommendations.map((recommendation, index) => (
                  <HStack key={index} align="start" spacing={3}>
                    <Box
                      w={2}
                      h={2}
                      bg="blue.500"
                      borderRadius="full"
                      mt={2}
                      flexShrink={0}
                    />
                    <Text fontSize="sm">{recommendation}</Text>
                  </HStack>
                ))}
              </VStack>
            </CardBody>
          </Card>
        </SimpleGrid>
      </VStack>
    </Box>
  );
};