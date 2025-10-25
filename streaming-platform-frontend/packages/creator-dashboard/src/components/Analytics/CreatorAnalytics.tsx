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
  Select,
  Button,
  Badge,
  Divider,
  useColorModeValue,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  StatArrow,
  Progress,
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  Avatar,
  Tooltip,
  Icon,
} from '@chakra-ui/react';
import {
  EyeIcon,
  HeartIcon,
  ChatBubbleLeftIcon,
  UserGroupIcon,
  CurrencyDollarIcon,
  ArrowTrendingUpIcon,
  ArrowTrendingDownIcon,
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
  ArcElement,
  Title,
  Tooltip as ChartTooltip,
  Legend,
} from 'chart.js';
import { useAuth } from '../../stubs/auth';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  ChartTooltip,
  Legend
);

interface AnalyticsData {
  overview: {
    totalViews: number;
    totalFollowers: number;
    totalRevenue: number;
    avgViewDuration: number;
    engagementRate: number;
    growthRate: number;
  };
  viewerMetrics: {
    daily: number[];
    weekly: number[];
    monthly: number[];
    labels: string[];
  };
  revenueMetrics: {
    subscriptions: number;
    donations: number;
    sponsorships: number;
    merchandise: number;
    total: number;
    history: Array<{
      date: string;
      amount: number;
      source: string;
    }>;
  };
  contentPerformance: Array<{
    id: string;
    title: string;
    thumbnail: string;
    views: number;
    likes: number;
    comments: number;
    duration: number;
    revenue: number;
    date: Date;
  }>;
  audienceInsights: {
    demographics: {
      ageGroups: Array<{ range: string; percentage: number }>;
      genders: Array<{ type: string; percentage: number }>;
      locations: Array<{ country: string; percentage: number }>;
    };
    engagement: {
      peakHours: Array<{ hour: number; viewers: number }>;
      retentionRate: number[];
      chatActivity: number[];
    };
  };
}

const TIME_RANGES = [
  { value: '7d', label: 'Last 7 days' },
  { value: '30d', label: 'Last 30 days' },
  { value: '90d', label: 'Last 3 months' },
  { value: '1y', label: 'Last year' },
];

export const CreatorAnalytics: React.FC = () => {
  const { user } = useAuth();
  const [timeRange, setTimeRange] = useState('30d');
  const [loading, setLoading] = useState(false);
  const [analyticsData, setAnalyticsData] = useState<AnalyticsData>({
    overview: {
      totalViews: 125430,
      totalFollowers: 8920,
      totalRevenue: 2847.50,
      avgViewDuration: 18.5,
      engagementRate: 7.2,
      growthRate: 12.8,
    },
    viewerMetrics: {
      daily: [1200, 1350, 1180, 1420, 1650, 1890, 2100, 1950, 1780, 1920, 2200, 2350, 2180, 2400],
      weekly: [8500, 9200, 8800, 9600, 10200, 11100, 10800],
      monthly: [32000, 35000, 38000, 42000],
      labels: ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6', 'Week 7'],
    },
    revenueMetrics: {
      subscriptions: 1850.00,
      donations: 650.50,
      sponsorships: 300.00,
      merchandise: 47.00,
      total: 2847.50,
      history: [
        { date: '2024-01-01', amount: 125.50, source: 'Subscriptions' },
        { date: '2024-01-02', amount: 45.00, source: 'Donations' },
        { date: '2024-01-03', amount: 200.00, source: 'Sponsorship' },
      ],
    },
    contentPerformance: [
      {
        id: '1',
        title: 'Epic Gaming Marathon - 12 Hour Stream',
        thumbnail: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=100',
        views: 15420,
        likes: 892,
        comments: 234,
        duration: 43200,
        revenue: 285.50,
        date: new Date('2024-01-15'),
      },
      {
        id: '2',
        title: 'New Game Review & First Impressions',
        thumbnail: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=100',
        views: 8934,
        likes: 567,
        comments: 123,
        duration: 3600,
        revenue: 145.20,
        date: new Date('2024-01-14'),
      },
    ],
    audienceInsights: {
      demographics: {
        ageGroups: [
          { range: '13-17', percentage: 15 },
          { range: '18-24', percentage: 35 },
          { range: '25-34', percentage: 30 },
          { range: '35-44', percentage: 15 },
          { range: '45+', percentage: 5 },
        ],
        genders: [
          { type: 'Male', percentage: 65 },
          { type: 'Female', percentage: 32 },
          { type: 'Other', percentage: 3 },
        ],
        locations: [
          { country: 'United Kingdom', percentage: 45 },
          { country: 'United States', percentage: 25 },
          { country: 'Canada', percentage: 12 },
          { country: 'Australia', percentage: 8 },
          { country: 'Other', percentage: 10 },
        ],
      },
      engagement: {
        peakHours: [
          { hour: 0, viewers: 120 },
          { hour: 6, viewers: 80 },
          { hour: 12, viewers: 200 },
          { hour: 18, viewers: 450 },
          { hour: 20, viewers: 680 },
          { hour: 22, viewers: 520 },
        ],
        retentionRate: [100, 85, 72, 65, 58, 52, 48, 45, 42, 40],
        chatActivity: [50, 120, 200, 350, 280, 180, 90],
      },
    },
  });

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const cardBg = useColorModeValue('gray.50', 'gray.700');

  useEffect(() => {
    loadAnalyticsData();
  }, [timeRange]);

  const loadAnalyticsData = async () => {
    setLoading(true);
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));
      // Data would be fetched based on timeRange
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error loading analytics', error, { 
          component: 'CreatorAnalytics',
          action: 'loadAnalyticsData' 
        });
      });
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
    }).format(amount);
  };

  const formatNumber = (num: number) => {
    if (num >= 1000000) {
      return `${(num / 1000000).toFixed(1)}M`;
    } else if (num >= 1000) {
      return `${(num / 1000).toFixed(1)}K`;
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

  // Chart configurations
  const viewerChartData = {
    labels: analyticsData.viewerMetrics.labels,
    datasets: [
      {
        label: 'Viewers',
        data: analyticsData.viewerMetrics.weekly,
        borderColor: 'rgb(59, 130, 246)',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        tension: 0.4,
        fill: true,
      },
    ],
  };

  const revenueChartData = {
    labels: ['Subscriptions', 'Donations', 'Sponsorships', 'Merchandise'],
    datasets: [
      {
        data: [
          analyticsData.revenueMetrics.subscriptions,
          analyticsData.revenueMetrics.donations,
          analyticsData.revenueMetrics.sponsorships,
          analyticsData.revenueMetrics.merchandise,
        ],
        backgroundColor: [
          'rgba(34, 197, 94, 0.8)',
          'rgba(59, 130, 246, 0.8)',
          'rgba(168, 85, 247, 0.8)',
          'rgba(249, 115, 22, 0.8)',
        ],
        borderWidth: 0,
      },
    ],
  };

  const demographicsChartData = {
    labels: analyticsData.audienceInsights.demographics.ageGroups.map(g => g.range),
    datasets: [
      {
        label: 'Age Distribution',
        data: analyticsData.audienceInsights.demographics.ageGroups.map(g => g.percentage),
        backgroundColor: 'rgba(59, 130, 246, 0.8)',
        borderColor: 'rgba(59, 130, 246, 1)',
        borderWidth: 1,
      },
    ],
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top' as const,
      },
    },
  };

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        {/* Header */}
        <HStack justify="space-between">
          <Text fontSize="2xl" fontWeight="bold">Analytics Dashboard</Text>
          <Select
            value={timeRange}
            onChange={(e) => setTimeRange(e.target.value)}
            w="200px"
          >
            {TIME_RANGES.map(range => (
              <option key={range.value} value={range.value}>
                {range.label}
              </option>
            ))}
          </Select>
        </HStack>

        {/* Overview Stats */}
        <SimpleGrid columns={{ base: 2, md: 3, lg: 6 }} spacing={4}>
          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Total Views</StatLabel>
            <StatNumber>{formatNumber(analyticsData.overview.totalViews)}</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              {analyticsData.overview.growthRate}%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Followers</StatLabel>
            <StatNumber>{formatNumber(analyticsData.overview.totalFollowers)}</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              8.2%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Revenue</StatLabel>
            <StatNumber>{formatCurrency(analyticsData.overview.totalRevenue)}</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              15.3%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Avg. Watch Time</StatLabel>
            <StatNumber>{analyticsData.overview.avgViewDuration}m</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              2.1%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Engagement Rate</StatLabel>
            <StatNumber>{analyticsData.overview.engagementRate}%</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              0.8%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Growth Rate</StatLabel>
            <StatNumber>{analyticsData.overview.growthRate}%</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              Monthly
            </StatHelpText>
          </Stat>
        </SimpleGrid>

        {/* Charts Row */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6}>
          {/* Viewer Trends */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <EyeIcon width="20px" />
                <Text fontWeight="bold">Viewer Trends</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <Box h="300px">
                <Line data={viewerChartData} options={chartOptions} />
              </Box>
            </CardBody>
          </Card>

          {/* Revenue Breakdown */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <CurrencyDollarIcon width="20px" />
                <Text fontWeight="bold">Revenue Breakdown</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <Box h="300px">
                <Doughnut data={revenueChartData} options={chartOptions} />
              </Box>
            </CardBody>
          </Card>
        </SimpleGrid>

        {/* Revenue Details */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <Text fontWeight="bold">Revenue Details</Text>
          </CardHeader>
          <CardBody>
            <SimpleGrid columns={{ base: 2, md: 4 }} spacing={6}>
              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Subscriptions</Text>
                <Text fontSize="2xl" fontWeight="bold" color="green.500">
                  {formatCurrency(analyticsData.revenueMetrics.subscriptions)}
                </Text>
                <Progress
                  value={(analyticsData.revenueMetrics.subscriptions / analyticsData.revenueMetrics.total) * 100}
                  colorScheme="green"
                  w="100%"
                />
              </VStack>

              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Donations</Text>
                <Text fontSize="2xl" fontWeight="bold" color="blue.500">
                  {formatCurrency(analyticsData.revenueMetrics.donations)}
                </Text>
                <Progress
                  value={(analyticsData.revenueMetrics.donations / analyticsData.revenueMetrics.total) * 100}
                  colorScheme="blue"
                  w="100%"
                />
              </VStack>

              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Sponsorships</Text>
                <Text fontSize="2xl" fontWeight="bold" color="purple.500">
                  {formatCurrency(analyticsData.revenueMetrics.sponsorships)}
                </Text>
                <Progress
                  value={(analyticsData.revenueMetrics.sponsorships / analyticsData.revenueMetrics.total) * 100}
                  colorScheme="purple"
                  w="100%"
                />
              </VStack>

              <VStack spacing={2}>
                <Text fontSize="sm" color="gray.500">Merchandise</Text>
                <Text fontSize="2xl" fontWeight="bold" color="orange.500">
                  {formatCurrency(analyticsData.revenueMetrics.merchandise)}
                </Text>
                <Progress
                  value={(analyticsData.revenueMetrics.merchandise / analyticsData.revenueMetrics.total) * 100}
                  colorScheme="orange"
                  w="100%"
                />
              </VStack>
            </SimpleGrid>
          </CardBody>
        </Card>

        {/* Content Performance */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <Text fontWeight="bold">Top Performing Content</Text>
          </CardHeader>
          <CardBody>
            <Table variant="simple">
              <Thead>
                <Tr>
                  <Th>Content</Th>
                  <Th isNumeric>Views</Th>
                  <Th isNumeric>Engagement</Th>
                  <Th isNumeric>Duration</Th>
                  <Th isNumeric>Revenue</Th>
                  <Th>Date</Th>
                </Tr>
              </Thead>
              <Tbody>
                {analyticsData.contentPerformance.map((content) => (
                  <Tr key={content.id}>
                    <Td>
                      <HStack spacing={3}>
                        <Avatar size="sm" src={content.thumbnail} />
                        <VStack align="start" spacing={0}>
                          <Text fontWeight="medium" fontSize="sm" noOfLines={1}>
                            {content.title}
                          </Text>
                        </VStack>
                      </HStack>
                    </Td>
                    <Td isNumeric>
                      <VStack spacing={0} align="end">
                        <Text fontWeight="medium">{formatNumber(content.views)}</Text>
                        <HStack spacing={1}>
                          <EyeIcon width="12px" />
                          <Text fontSize="xs" color="gray.500">views</Text>
                        </HStack>
                      </VStack>
                    </Td>
                    <Td isNumeric>
                      <VStack spacing={1} align="end">
                        <HStack spacing={2}>
                          <HStack spacing={1}>
                            <HeartIcon width="12px" />
                            <Text fontSize="xs">{formatNumber(content.likes)}</Text>
                          </HStack>
                          <HStack spacing={1}>
                            <ChatBubbleLeftIcon width="12px" />
                            <Text fontSize="xs">{formatNumber(content.comments)}</Text>
                          </HStack>
                        </HStack>
                      </VStack>
                    </Td>
                    <Td isNumeric>
                      <Text fontSize="sm">{formatDuration(content.duration)}</Text>
                    </Td>
                    <Td isNumeric>
                      <Text fontWeight="medium" color="green.500">
                        {formatCurrency(content.revenue)}
                      </Text>
                    </Td>
                    <Td>
                      <Text fontSize="sm" color="gray.500">
                        {content.date.toLocaleDateString()}
                      </Text>
                    </Td>
                  </Tr>
                ))}
              </Tbody>
            </Table>
          </CardBody>
        </Card>

        {/* Audience Insights */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6}>
          {/* Demographics */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <UserGroupIcon width="20px" />
                <Text fontWeight="bold">Audience Demographics</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <VStack spacing={4} align="stretch">
                <Box h="200px">
                  <Bar data={demographicsChartData} options={chartOptions} />
                </Box>
                
                <Divider />
                
                <VStack spacing={3} align="stretch">
                  <Text fontSize="sm" fontWeight="medium">Top Locations</Text>
                  {analyticsData.audienceInsights.demographics.locations.slice(0, 3).map((location, index) => (
                    <HStack key={index} justify="space-between">
                      <Text fontSize="sm">{location.country}</Text>
                      <HStack spacing={2}>
                        <Progress
                          value={location.percentage}
                          w="60px"
                          size="sm"
                          colorScheme="blue"
                        />
                        <Text fontSize="sm" w="35px" textAlign="right">
                          {location.percentage}%
                        </Text>
                      </HStack>
                    </HStack>
                  ))}
                </VStack>
              </VStack>
            </CardBody>
          </Card>

          {/* Engagement Patterns */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <Text fontWeight="bold">Engagement Patterns</Text>
            </CardHeader>
            <CardBody>
              <VStack spacing={4} align="stretch">
                <VStack spacing={2} align="stretch">
                  <Text fontSize="sm" fontWeight="medium">Peak Viewing Hours</Text>
                  {analyticsData.audienceInsights.engagement.peakHours
                    .sort((a, b) => b.viewers - a.viewers)
                    .slice(0, 3)
                    .map((peak, index) => (
                      <HStack key={index} justify="space-between">
                        <Text fontSize="sm">
                          {peak.hour}:00 - {peak.hour + 1}:00
                        </Text>
                        <HStack spacing={2}>
                          <Progress
                            value={(peak.viewers / 680) * 100}
                            w="60px"
                            size="sm"
                            colorScheme="green"
                          />
                          <Text fontSize="sm" w="50px" textAlign="right">
                            {formatNumber(peak.viewers)}
                          </Text>
                        </HStack>
                      </HStack>
                    ))}
                </VStack>
                
                <Divider />
                
                <VStack spacing={2} align="stretch">
                  <Text fontSize="sm" fontWeight="medium">Retention Rate</Text>
                  <Text fontSize="xs" color="gray.500">
                    Average viewer retention throughout streams
                  </Text>
                  <Progress
                    value={analyticsData.audienceInsights.engagement.retentionRate[5]}
                    colorScheme="purple"
                  />
                  <Text fontSize="sm" textAlign="center">
                    {analyticsData.audienceInsights.engagement.retentionRate[5]}% at 30 minutes
                  </Text>
                </VStack>
              </VStack>
            </CardBody>
          </Card>
        </SimpleGrid>
      </VStack>
    </Box>
  );
};