import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  VStack,
  HStack,
  Text,
  Card,
  CardBody,
  CardHeader,
  SimpleGrid,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  StatArrow,
  useColorModeValue,
  Select,
  Button,
  Badge,
  Progress,
  Divider,
  Alert,
  AlertIcon,
  AlertDescription,
  Spinner,
  useToast,
  Tooltip,
  IconButton,
  Menu,
  MenuButton,
  MenuList,
  MenuItem,
  Switch,
  FormControl,
  FormLabel,
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  Avatar,
} from '@chakra-ui/react';
import {
  EyeIcon,
  HeartIcon,
  ChatBubbleLeftIcon,
  CurrencyDollarIcon,
  ArrowTrendingUpIcon,
  ArrowTrendingDownIcon,
  ClockIcon,
  UserGroupIcon,
  ArrowPathIcon,
  Cog6ToothIcon,
  ChartBarIcon,
  PlayIcon,
  VideoCameraIcon,
  CalendarIcon,
} from '@heroicons/react/24/outline';
import { Line, Bar, Doughnut } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  Tooltip as ChartTooltip,
  Legend,
  ArcElement,
} from 'chart.js';
import { useAuth } from '../../stubs/auth';
import { useGlobalStore } from '../../stubs/shared';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  Title,
  ChartTooltip,
  Legend,
  ArcElement
);

interface AnalyticsData {
  overview: {
    totalViews: number;
    totalViewsChange: number;
    liveViewers: number;
    liveViewersChange: number;
    followers: number;
    followersChange: number;
    revenue: number;
    revenueChange: number;
    avgWatchTime: number;
    avgWatchTimeChange: number;
    engagement: number;
    engagementChange: number;
  };
  viewerMetrics: {
    hourlyViews: number[];
    dailyViews: number[];
    weeklyViews: number[];
    monthlyViews: number[];
    labels: string[];
  };
  demographics: {
    ageGroups: { label: string; value: number; color: string }[];
    countries: { label: string; value: number; flag: string }[];
    devices: { label: string; value: number; color: string }[];
  };
  contentPerformance: {
    topStreams: Array<{
      id: string;
      title: string;
      thumbnail: string;
      views: number;
      duration: number;
      date: Date;
      engagement: number;
    }>;
    categoryBreakdown: { label: string; value: number; color: string }[];
  };
  realtimeMetrics: {
    currentViewers: number;
    chatActivity: number;
    streamHealth: number;
    bitrate: number;
    latency: number;
  };
}

const TIME_RANGES = [
  { value: '1h', label: 'Last Hour' },
  { value: '24h', label: 'Last 24 Hours' },
  { value: '7d', label: 'Last 7 Days' },
  { value: '30d', label: 'Last 30 Days' },
  { value: '90d', label: 'Last 90 Days' },
];

export const EnhancedCreatorAnalytics: React.FC = () => {
  const { user } = useAuth();
  const { addNotification } = useGlobalStore();
  const toast = useToast();
  
  const [timeRange, setTimeRange] = useState('24h');
  const [loading, setLoading] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [lastUpdated, setLastUpdated] = useState(new Date());
  
  const [analyticsData, setAnalyticsData] = useState<AnalyticsData>({
    overview: {
      totalViews: 125430,
      totalViewsChange: 12.5,
      liveViewers: 1247,
      liveViewersChange: -3.2,
      followers: 8934,
      followersChange: 8.7,
      revenue: 2847.50,
      revenueChange: 15.3,
      avgWatchTime: 18.5,
      avgWatchTimeChange: 5.2,
      engagement: 7.8,
      engagementChange: -1.1,
    },
    viewerMetrics: {
      hourlyViews: [120, 145, 180, 220, 195, 240, 280, 320, 290, 350, 380, 420, 450, 480, 520, 490, 460, 430, 400, 380, 350, 320, 280, 250],
      dailyViews: [2400, 2650, 2890, 3120, 2980, 3340, 3680],
      weeklyViews: [18500, 19200, 20100, 18900, 21300, 22400, 23100],
      monthlyViews: [78000, 82000, 85000, 89000],
      labels: [],
    },
    demographics: {
      ageGroups: [
        { label: '13-17', value: 15, color: '#9f7aea' },
        { label: '18-24', value: 35, color: '#805ad5' },
        { label: '25-34', value: 28, color: '#6b46c1' },
        { label: '35-44', value: 15, color: '#553c9a' },
        { label: '45+', value: 7, color: '#44337a' },
      ],
      countries: [
        { label: 'United States', value: 35, flag: '🇺🇸' },
        { label: 'United Kingdom', value: 18, flag: '🇬🇧' },
        { label: 'Canada', value: 12, flag: '🇨🇦' },
        { label: 'Germany', value: 10, flag: '🇩🇪' },
        { label: 'Australia', value: 8, flag: '🇦🇺' },
        { label: 'Others', value: 17, flag: '🌍' },
      ],
      devices: [
        { label: 'Desktop', value: 45, color: '#805ad5' },
        { label: 'Mobile', value: 35, color: '#9f7aea' },
        { label: 'Tablet', value: 12, color: '#b794f6' },
        { label: 'TV/Console', value: 8, color: '#d6bcfa' },
      ],
    },
    contentPerformance: {
      topStreams: [
        {
          id: '1',
          title: 'Epic Gaming Marathon - 12 Hour Stream',
          thumbnail: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=100',
          views: 15420,
          duration: 43200,
          date: new Date('2024-01-15'),
          engagement: 8.9,
        },
        {
          id: '2',
          title: 'New Game Review & First Impressions',
          thumbnail: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=100',
          views: 8934,
          duration: 3600,
          date: new Date('2024-01-14'),
          engagement: 7.2,
        },
        {
          id: '3',
          title: 'Community Q&A Session',
          thumbnail: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=100',
          views: 6789,
          duration: 5400,
          date: new Date('2024-01-13'),
          engagement: 9.1,
        },
      ],
      categoryBreakdown: [
        { label: 'Gaming', value: 65, color: '#805ad5' },
        { label: 'Just Chatting', value: 20, color: '#9f7aea' },
        { label: 'Music', value: 10, color: '#b794f6' },
        { label: 'Art', value: 5, color: '#d6bcfa' },
      ],
    },
    realtimeMetrics: {
      currentViewers: 1247,
      chatActivity: 85,
      streamHealth: 98,
      bitrate: 4950,
      latency: 2.8,
    },
  });

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const cardBg = useColorModeValue('purple.50', 'purple.900');
  const purpleColor = useColorModeValue('purple.600', 'purple.300');

  // Generate labels based on time range
  useEffect(() => {
    const generateLabels = () => {
      const now = new Date();
      const labels: string[] = [];
      
      switch (timeRange) {
        case '1h':
          for (let i = 23; i >= 0; i--) {
            const time = new Date(now.getTime() - i * 5 * 60 * 1000);
            labels.push(time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
          }
          break;
        case '24h':
          for (let i = 23; i >= 0; i--) {
            const time = new Date(now.getTime() - i * 60 * 60 * 1000);
            labels.push(time.toLocaleTimeString([], { hour: '2-digit' }));
          }
          break;
        case '7d':
          for (let i = 6; i >= 0; i--) {
            const date = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
            labels.push(date.toLocaleDateString([], { weekday: 'short' }));
          }
          break;
        case '30d':
          for (let i = 29; i >= 0; i--) {
            const date = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
            labels.push(date.toLocaleDateString([], { month: 'short', day: 'numeric' }));
          }
          break;
        case '90d':
          for (let i = 11; i >= 0; i--) {
            const date = new Date(now.getTime() - i * 7 * 24 * 60 * 60 * 1000);
            labels.push(date.toLocaleDateString([], { month: 'short', day: 'numeric' }));
          }
          break;
      }
      
      setAnalyticsData(prev => ({
        ...prev,
        viewerMetrics: {
          ...prev.viewerMetrics,
          labels,
        },
      }));
    };
    
    generateLabels();
  }, [timeRange]);

  // Auto-refresh data
  useEffect(() => {
    if (!autoRefresh) return;
    
    const interval = setInterval(() => {
      fetchAnalyticsData();
    }, 30000); // Refresh every 30 seconds
    
    return () => clearInterval(interval);
  }, [autoRefresh, timeRange]);

  const fetchAnalyticsData = useCallback(async () => {
    setLoading(true);
    try {
      // Simulate API call to CloudWatch and Aurora
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Simulate real-time data updates
      setAnalyticsData(prev => ({
        ...prev,
        overview: {
          ...prev.overview,
          liveViewers: Math.max(0, prev.overview.liveViewers + Math.floor(Math.random() * 20) - 10),
        },
        realtimeMetrics: {
          ...prev.realtimeMetrics,
          currentViewers: Math.max(0, prev.realtimeMetrics.currentViewers + Math.floor(Math.random() * 20) - 10),
          chatActivity: Math.max(0, Math.min(100, prev.realtimeMetrics.chatActivity + Math.floor(Math.random() * 10) - 5)),
          streamHealth: Math.max(90, Math.min(100, prev.realtimeMetrics.streamHealth + Math.random() * 2 - 1)),
          bitrate: Math.max(4000, Math.min(6000, prev.realtimeMetrics.bitrate + Math.floor(Math.random() * 100) - 50)),
          latency: Math.max(1, Math.min(5, prev.realtimeMetrics.latency + Math.random() * 0.2 - 0.1)),
        },
      }));
      
      setLastUpdated(new Date());
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error fetching analytics data', error, { 
          component: 'EnhancedCreatorAnalytics',
          action: 'fetchAnalyticsData' 
        });
      });
      toast({
        title: 'Data Fetch Failed',
        description: 'Unable to fetch latest analytics data',
        status: 'error',
        duration: 5000,
      });
    } finally {
      setLoading(false);
    }
  }, [timeRange, toast]);

  const refreshData = () => {
    fetchAnalyticsData();
    addNotification({
      type: 'info',
      title: 'Data Refreshed',
      message: 'Analytics data has been updated',
    });
  };

  const getViewerData = () => {
    switch (timeRange) {
      case '1h':
        return analyticsData.viewerMetrics.hourlyViews.slice(-24);
      case '24h':
        return analyticsData.viewerMetrics.hourlyViews;
      case '7d':
        return analyticsData.viewerMetrics.dailyViews;
      case '30d':
        return analyticsData.viewerMetrics.dailyViews.slice(-30);
      case '90d':
        return analyticsData.viewerMetrics.weeklyViews;
      default:
        return analyticsData.viewerMetrics.hourlyViews;
    }
  };

  const viewerChartData = {
    labels: analyticsData.viewerMetrics.labels,
    datasets: [
      {
        label: 'Viewers',
        data: getViewerData(),
        borderColor: purpleColor,
        backgroundColor: `${purpleColor}20`,
        tension: 0.4,
        fill: true,
      },
    ],
  };

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
        grid: {
          display: false,
        },
      },
      y: {
        beginAtZero: true,
        grid: {
          color: borderColor,
        },
      },
    },
  };

  const demographicsChartData = {
    labels: analyticsData.demographics.ageGroups.map(group => group.label),
    datasets: [
      {
        data: analyticsData.demographics.ageGroups.map(group => group.value),
        backgroundColor: analyticsData.demographics.ageGroups.map(group => group.color),
        borderWidth: 0,
      },
    ],
  };

  const formatNumber = (num: number) => {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  };

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        {/* Header */}
        <HStack justify="space-between">
          <VStack align="start" spacing={1}>
            <Text fontSize="2xl" fontWeight="bold" color={purpleColor}>
              Creator Analytics
            </Text>
            <Text fontSize="sm" color="gray.500">
              Last updated: {lastUpdated.toLocaleTimeString()}
            </Text>
          </VStack>
          
          <HStack spacing={3}>
            <FormControl display="flex" alignItems="center">
              <FormLabel htmlFor="auto-refresh" mb={0} fontSize="sm">
                Auto-refresh
              </FormLabel>
              <Switch
                id="auto-refresh"
                colorScheme="purple"
                isChecked={autoRefresh}
                onChange={(e) => setAutoRefresh(e.target.checked)}
              />
            </FormControl>
            
            <Select
              value={timeRange}
              onChange={(e) => setTimeRange(e.target.value)}
              maxW="150px"
            >
              {TIME_RANGES.map(range => (
                <option key={range.value} value={range.value}>
                  {range.label}
                </option>
              ))}
            </Select>
            
            <IconButton
              aria-label="Refresh data"
              icon={<ArrowPathIcon width="16px" />}
              onClick={refreshData}
              isLoading={loading}
              colorScheme="purple"
              variant="outline"
            />
          </HStack>
        </HStack>

        {/* Overview Stats */}
        <SimpleGrid columns={{ base: 2, md: 3, lg: 6 }} spacing={4}>
          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Total Views</StatLabel>
            <StatNumber color={purpleColor}>{formatNumber(analyticsData.overview.totalViews)}</StatNumber>
            <StatHelpText>
              <StatArrow type={analyticsData.overview.totalViewsChange > 0 ? 'increase' : 'decrease'} />
              {Math.abs(analyticsData.overview.totalViewsChange)}%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Live Viewers</StatLabel>
            <StatNumber color={purpleColor}>{formatNumber(analyticsData.overview.liveViewers)}</StatNumber>
            <StatHelpText>
              <StatArrow type={analyticsData.overview.liveViewersChange > 0 ? 'increase' : 'decrease'} />
              {Math.abs(analyticsData.overview.liveViewersChange)}%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Followers</StatLabel>
            <StatNumber color={purpleColor}>{formatNumber(analyticsData.overview.followers)}</StatNumber>
            <StatHelpText>
              <StatArrow type={analyticsData.overview.followersChange > 0 ? 'increase' : 'decrease'} />
              {Math.abs(analyticsData.overview.followersChange)}%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Revenue</StatLabel>
            <StatNumber color={purpleColor}>${analyticsData.overview.revenue.toFixed(2)}</StatNumber>
            <StatHelpText>
              <StatArrow type={analyticsData.overview.revenueChange > 0 ? 'increase' : 'decrease'} />
              {Math.abs(analyticsData.overview.revenueChange)}%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Avg Watch Time</StatLabel>
            <StatNumber color={purpleColor}>{analyticsData.overview.avgWatchTime}m</StatNumber>
            <StatHelpText>
              <StatArrow type={analyticsData.overview.avgWatchTimeChange > 0 ? 'increase' : 'decrease'} />
              {Math.abs(analyticsData.overview.avgWatchTimeChange)}%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Engagement</StatLabel>
            <StatNumber color={purpleColor}>{analyticsData.overview.engagement}%</StatNumber>
            <StatHelpText>
              <StatArrow type={analyticsData.overview.engagementChange > 0 ? 'increase' : 'decrease'} />
              {Math.abs(analyticsData.overview.engagementChange)}%
            </StatHelpText>
          </Stat>
        </SimpleGrid>

        {/* Real-time Metrics */}
        <Card bg={cardBg} border="2px" borderColor={purpleColor}>
          <CardHeader>
            <HStack>
              <VideoCameraIcon width="20px" color={purpleColor} />
              <Text fontWeight="bold" color={purpleColor}>Real-time Stream Metrics</Text>
              <Badge colorScheme="green" variant="solid">LIVE</Badge>
            </HStack>
          </CardHeader>
          <CardBody>
            <SimpleGrid columns={{ base: 2, md: 5 }} spacing={4}>
              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Current Viewers</Text>
                <Text fontSize="2xl" fontWeight="bold" color={purpleColor}>
                  {analyticsData.realtimeMetrics.currentViewers}
                </Text>
              </VStack>
              
              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Chat Activity</Text>
                <Text fontSize="2xl" fontWeight="bold" color={purpleColor}>
                  {analyticsData.realtimeMetrics.chatActivity}%
                </Text>
                <Progress
                  value={analyticsData.realtimeMetrics.chatActivity}
                  colorScheme="purple"
                  size="sm"
                  w="100%"
                />
              </VStack>
              
              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Stream Health</Text>
                <Text fontSize="2xl" fontWeight="bold" color={purpleColor}>
                  {analyticsData.realtimeMetrics.streamHealth}%
                </Text>
                <Progress
                  value={analyticsData.realtimeMetrics.streamHealth}
                  colorScheme="green"
                  size="sm"
                  w="100%"
                />
              </VStack>
              
              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Bitrate</Text>
                <Text fontSize="2xl" fontWeight="bold" color={purpleColor}>
                  {analyticsData.realtimeMetrics.bitrate}
                </Text>
                <Text fontSize="xs" color="gray.500">kbps</Text>
              </VStack>
              
              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Latency</Text>
                <Text fontSize="2xl" fontWeight="bold" color={purpleColor}>
                  {analyticsData.realtimeMetrics.latency.toFixed(1)}s
                </Text>
              </VStack>
            </SimpleGrid>
          </CardBody>
        </Card>

        {/* Charts */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6}>
          {/* Viewer Trends */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <ChartBarIcon width="20px" color={purpleColor} />
                <Text fontWeight="bold" color={purpleColor}>Viewer Trends</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <Box h="300px">
                <Line data={viewerChartData} options={chartOptions} />
              </Box>
            </CardBody>
          </Card>

          {/* Demographics */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <UserGroupIcon width="20px" color={purpleColor} />
                <Text fontWeight="bold" color={purpleColor}>Age Demographics</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <Box h="300px">
                <Doughnut data={demographicsChartData} options={{ maintainAspectRatio: false }} />
              </Box>
            </CardBody>
          </Card>
        </SimpleGrid>

        {/* Top Content Performance */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <HStack>
              <ArrowTrendingUpIcon width="20px" color={purpleColor} />
              <Text fontWeight="bold" color={purpleColor}>Top Performing Content</Text>
            </HStack>
          </CardHeader>
          <CardBody>
            <Table variant="simple">
              <Thead>
                <Tr>
                  <Th>Content</Th>
                  <Th>Views</Th>
                  <Th>Duration</Th>
                  <Th>Engagement</Th>
                  <Th>Date</Th>
                </Tr>
              </Thead>
              <Tbody>
                {analyticsData.contentPerformance.topStreams.map((stream) => (
                  <Tr key={stream.id}>
                    <Td>
                      <HStack spacing={3}>
                        <Avatar size="sm" src={stream.thumbnail} />
                        <Text fontWeight="medium" noOfLines={1}>
                          {stream.title}
                        </Text>
                      </HStack>
                    </Td>
                    <Td>
                      <Text fontWeight="bold" color={purpleColor}>
                        {formatNumber(stream.views)}
                      </Text>
                    </Td>
                    <Td>{formatDuration(stream.duration)}</Td>
                    <Td>
                      <Badge colorScheme="purple" variant="subtle">
                        {stream.engagement}%
                      </Badge>
                    </Td>
                    <Td>{stream.date.toLocaleDateString()}</Td>
                  </Tr>
                ))}
              </Tbody>
            </Table>
          </CardBody>
        </Card>

        {/* Geographic Distribution */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <Text fontWeight="bold" color={purpleColor}>Geographic Distribution</Text>
          </CardHeader>
          <CardBody>
            <SimpleGrid columns={{ base: 2, md: 3, lg: 6 }} spacing={4}>
              {analyticsData.demographics.countries.map((country, index) => (
                <VStack key={index} spacing={2} p={3} bg={cardBg} borderRadius="md">
                  <Text fontSize="2xl">{country.flag}</Text>
                  <Text fontSize="sm" fontWeight="medium" textAlign="center">
                    {country.label}
                  </Text>
                  <Text fontSize="lg" fontWeight="bold" color={purpleColor}>
                    {country.value}%
                  </Text>
                </VStack>
              ))}
            </SimpleGrid>
          </CardBody>
        </Card>
      </VStack>
    </Box>
  );
};