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
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  Progress,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalBody,
  ModalFooter,
  ModalCloseButton,
  useDisclosure,
  Input,
  FormControl,
  FormLabel,
  Textarea,
  useToast,
  Alert,
  AlertIcon,
  AlertDescription,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  StatArrow,
} from '@chakra-ui/react';
import {
  CurrencyPoundSterlingIcon,
  BanknotesIcon,
  GiftIcon,
  TrophyIcon,
  ArrowDownTrayIcon,
  PlusIcon,
  CalendarIcon,
} from '@heroicons/react/24/outline';
import { Line, Bar } from 'react-chartjs-2';
import { useAuth } from '@streaming/auth';
import { useGlobalStore } from '@streaming/shared';

interface RevenueStream {
  id: string;
  type: 'subscription' | 'donation' | 'sponsorship' | 'merchandise' | 'ad_revenue';
  amount: number;
  currency: string;
  date: Date;
  description: string;
  status: 'pending' | 'completed' | 'failed';
  source?: string;
  fees?: number;
  netAmount?: number;
}

interface RevenueGoal {
  id: string;
  title: string;
  targetAmount: number;
  currentAmount: number;
  deadline: Date;
  description: string;
  isActive: boolean;
}

interface PayoutInfo {
  nextPayoutDate: Date;
  pendingAmount: number;
  minimumPayout: number;
  payoutMethod: string;
  accountDetails: string;
}

interface RevenueAnalytics {
  totalRevenue: number;
  monthlyRevenue: number;
  weeklyRevenue: number;
  dailyRevenue: number;
  revenueByType: Record<string, number>;
  monthlyTrend: Array<{ month: string; amount: number }>;
  topDonators: Array<{
    username: string;
    avatar: string;
    totalDonated: number;
    lastDonation: Date;
  }>;
  projectedRevenue: number;
  growthRate: number;
}

export const RevenueTracking: React.FC = () => {
  const { user } = useAuth();
  const { addNotification } = useGlobalStore();
  const toast = useToast();
  const { isOpen: isGoalModalOpen, onOpen: openGoalModal, onClose: closeGoalModal } = useDisclosure();
  
  const [timeRange, setTimeRange] = useState('30d');
  const [revenueStreams, setRevenueStreams] = useState<RevenueStream[]>([
    {
      id: '1',
      type: 'subscription',
      amount: 125.50,
      currency: 'GBP',
      date: new Date('2024-01-15'),
      description: 'Monthly subscription revenue',
      status: 'completed',
      source: 'Stripe',
      fees: 3.76,
      netAmount: 121.74,
    },
    {
      id: '2',
      type: 'donation',
      amount: 25.00,
      currency: 'GBP',
      date: new Date('2024-01-15'),
      description: 'Donation from viewer: "Great stream!"',
      status: 'completed',
      source: 'PayPal',
      fees: 1.02,
      netAmount: 23.98,
    },
    {
      id: '3',
      type: 'sponsorship',
      amount: 500.00,
      currency: 'GBP',
      date: new Date('2024-01-14'),
      description: 'Gaming peripheral sponsorship deal',
      status: 'pending',
      source: 'Direct',
      fees: 0,
      netAmount: 500.00,
    },
  ]);
  
  const [revenueGoals, setRevenueGoals] = useState<RevenueGoal[]>([
    {
      id: '1',
      title: 'Monthly Revenue Goal',
      targetAmount: 3000,
      currentAmount: 2847.50,
      deadline: new Date('2024-01-31'),
      description: 'Reach £3,000 in monthly revenue',
      isActive: true,
    },
    {
      id: '2',
      title: 'Equipment Upgrade Fund',
      targetAmount: 1500,
      currentAmount: 850.00,
      deadline: new Date('2024-03-01'),
      description: 'Save for new streaming equipment',
      isActive: true,
    },
  ]);
  
  const [payoutInfo] = useState<PayoutInfo>({
    nextPayoutDate: new Date('2024-02-01'),
    pendingAmount: 2847.50,
    minimumPayout: 100,
    payoutMethod: 'Bank Transfer',
    accountDetails: '****1234',
  });
  
  const [analytics] = useState<RevenueAnalytics>({
    totalRevenue: 12450.75,
    monthlyRevenue: 2847.50,
    weeklyRevenue: 685.25,
    dailyRevenue: 95.50,
    revenueByType: {
      subscription: 1850.00,
      donation: 650.50,
      sponsorship: 300.00,
      merchandise: 47.00,
    },
    monthlyTrend: [
      { month: 'Aug', amount: 1850 },
      { month: 'Sep', amount: 2100 },
      { month: 'Oct', amount: 2350 },
      { month: 'Nov', amount: 2650 },
      { month: 'Dec', amount: 2900 },
      { month: 'Jan', amount: 2847.50 },
    ],
    topDonators: [
      {
        username: 'SuperFan123',
        avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
        totalDonated: 250.00,
        lastDonation: new Date('2024-01-14'),
      },
      {
        username: 'GamerGirl99',
        avatar: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150',
        totalDonated: 180.50,
        lastDonation: new Date('2024-01-13'),
      },
    ],
    projectedRevenue: 3200,
    growthRate: 15.2,
  });
  
  const [newGoal, setNewGoal] = useState({
    title: '',
    targetAmount: 0,
    deadline: '',
    description: '',
  });

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const cardBg = useColorModeValue('gray.50', 'gray.700');

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
    }).format(amount);
  };

  const getRevenueTypeIcon = (type: string) => {
    switch (type) {
      case 'subscription': return CurrencyPoundSterlingIcon;
      case 'donation': return GiftIcon;
      case 'sponsorship': return TrophyIcon;
      case 'merchandise': return BanknotesIcon;
      default: return CurrencyPoundSterlingIcon;
    }
  };

  const getRevenueTypeColor = (type: string) => {
    switch (type) {
      case 'subscription': return 'green';
      case 'donation': return 'blue';
      case 'sponsorship': return 'purple';
      case 'merchandise': return 'orange';
      default: return 'gray';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'green';
      case 'pending': return 'yellow';
      case 'failed': return 'red';
      default: return 'gray';
    }
  };

  const createGoal = async () => {
    if (!newGoal.title || !newGoal.targetAmount || !newGoal.deadline) {
      toast({
        title: 'Validation Error',
        description: 'Please fill in all required fields',
        status: 'error',
        duration: 3000,
      });
      return;
    }

    const goal: RevenueGoal = {
      id: Date.now().toString(),
      title: newGoal.title,
      targetAmount: newGoal.targetAmount,
      currentAmount: 0,
      deadline: new Date(newGoal.deadline),
      description: newGoal.description,
      isActive: true,
    };

    setRevenueGoals(prev => [...prev, goal]);
    setNewGoal({ title: '', targetAmount: 0, deadline: '', description: '' });
    closeGoalModal();

    addNotification({
      type: 'success',
      title: 'Goal Created',
      message: `Revenue goal "${goal.title}" has been created`,
    });
  };

  const exportRevenueData = () => {
    // Simulate CSV export
    const csvData = revenueStreams.map(stream => ({
      Date: stream.date.toISOString().split('T')[0],
      Type: stream.type,
      Amount: stream.amount,
      Description: stream.description,
      Status: stream.status,
      'Net Amount': stream.netAmount || stream.amount,
    }));

    addNotification({
      type: 'info',
      title: 'Export Started',
      message: 'Revenue data export has been initiated',
    });
  };

  // Chart data
  const revenueChartData = {
    labels: analytics.monthlyTrend.map(item => item.month),
    datasets: [
      {
        label: 'Monthly Revenue',
        data: analytics.monthlyTrend.map(item => item.amount),
        borderColor: 'rgb(34, 197, 94)',
        backgroundColor: 'rgba(34, 197, 94, 0.1)',
        tension: 0.4,
        fill: true,
      },
    ],
  };

  const revenueTypeChartData = {
    labels: Object.keys(analytics.revenueByType),
    datasets: [
      {
        label: 'Revenue by Type',
        data: Object.values(analytics.revenueByType),
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
          <Text fontSize="2xl" fontWeight="bold">Revenue Tracking</Text>
          <HStack spacing={3}>
            <Button
              leftIcon={<ArrowDownTrayIcon width="16px" />}
              variant="outline"
              onClick={exportRevenueData}
            >
              Export Data
            </Button>
            <Button
              leftIcon={<PlusIcon width="16px" />}
              colorScheme="blue"
              onClick={openGoalModal}
            >
              Set Goal
            </Button>
          </HStack>
        </HStack>

        {/* Revenue Overview */}
        <SimpleGrid columns={{ base: 2, md: 4 }} spacing={4}>
          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Total Revenue</StatLabel>
            <StatNumber>{formatCurrency(analytics.totalRevenue)}</StatNumber>
            <StatHelpText>All time</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>This Month</StatLabel>
            <StatNumber>{formatCurrency(analytics.monthlyRevenue)}</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              {analytics.growthRate}%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>This Week</StatLabel>
            <StatNumber>{formatCurrency(analytics.weeklyRevenue)}</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              12.5%
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Projected</StatLabel>
            <StatNumber>{formatCurrency(analytics.projectedRevenue)}</StatNumber>
            <StatHelpText>End of month</StatHelpText>
          </Stat>
        </SimpleGrid>

        {/* Charts */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6}>
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <Text fontWeight="bold">Revenue Trend</Text>
            </CardHeader>
            <CardBody>
              <Box h="300px">
                <Line data={revenueChartData} options={chartOptions} />
              </Box>
            </CardBody>
          </Card>

          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <Text fontWeight="bold">Revenue by Type</Text>
            </CardHeader>
            <CardBody>
              <Box h="300px">
                <Bar data={revenueTypeChartData} options={chartOptions} />
              </Box>
            </CardBody>
          </Card>
        </SimpleGrid>

        {/* Revenue Goals */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <Text fontWeight="bold">Revenue Goals</Text>
          </CardHeader>
          <CardBody>
            <VStack spacing={4} align="stretch">
              {revenueGoals.filter(goal => goal.isActive).map((goal) => {
                const progress = (goal.currentAmount / goal.targetAmount) * 100;
                const daysLeft = Math.ceil((goal.deadline.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
                
                return (
                  <Box key={goal.id} p={4} bg={cardBg} borderRadius="md">
                    <VStack spacing={3} align="stretch">
                      <HStack justify="space-between">
                        <VStack align="start" spacing={1}>
                          <Text fontWeight="bold">{goal.title}</Text>
                          <Text fontSize="sm" color="gray.500">{goal.description}</Text>
                        </VStack>
                        <VStack align="end" spacing={1}>
                          <Text fontSize="sm" color="gray.500">
                            {daysLeft > 0 ? `${daysLeft} days left` : 'Overdue'}
                          </Text>
                          <Text fontSize="sm">
                            {formatCurrency(goal.currentAmount)} / {formatCurrency(goal.targetAmount)}
                          </Text>
                        </VStack>
                      </HStack>
                      
                      <Progress
                        value={progress}
                        colorScheme={progress >= 100 ? 'green' : progress >= 75 ? 'blue' : 'yellow'}
                        size="lg"
                      />
                      
                      <HStack justify="space-between" fontSize="sm">
                        <Text color="gray.500">{progress.toFixed(1)}% complete</Text>
                        <Text color="gray.500">
                          {formatCurrency(goal.targetAmount - goal.currentAmount)} remaining
                        </Text>
                      </HStack>
                    </VStack>
                  </Box>
                );
              })}
            </VStack>
          </CardBody>
        </Card>

        {/* Payout Information */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <Text fontWeight="bold">Payout Information</Text>
          </CardHeader>
          <CardBody>
            <SimpleGrid columns={{ base: 1, md: 2 }} spacing={6}>
              <VStack spacing={4} align="stretch">
                <HStack justify="space-between">
                  <Text color="gray.500">Next Payout Date:</Text>
                  <Text fontWeight="medium">
                    {payoutInfo.nextPayoutDate.toLocaleDateString()}
                  </Text>
                </HStack>
                
                <HStack justify="space-between">
                  <Text color="gray.500">Pending Amount:</Text>
                  <Text fontWeight="bold" color="green.500">
                    {formatCurrency(payoutInfo.pendingAmount)}
                  </Text>
                </HStack>
                
                <HStack justify="space-between">
                  <Text color="gray.500">Minimum Payout:</Text>
                  <Text>{formatCurrency(payoutInfo.minimumPayout)}</Text>
                </HStack>
              </VStack>
              
              <VStack spacing={4} align="stretch">
                <HStack justify="space-between">
                  <Text color="gray.500">Payout Method:</Text>
                  <Text>{payoutInfo.payoutMethod}</Text>
                </HStack>
                
                <HStack justify="space-between">
                  <Text color="gray.500">Account:</Text>
                  <Text>{payoutInfo.accountDetails}</Text>
                </HStack>
                
                <Alert status="info" borderRadius="md">
                  <AlertIcon />
                  <AlertDescription fontSize="sm">
                    Payouts are processed on the 1st of each month for amounts over £{payoutInfo.minimumPayout}.
                  </AlertDescription>
                </Alert>
              </VStack>
            </SimpleGrid>
          </CardBody>
        </Card>

        {/* Recent Transactions */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <HStack justify="space-between">
              <Text fontWeight="bold">Recent Transactions</Text>
              <Select value={timeRange} onChange={(e) => setTimeRange(e.target.value)} w="150px">
                <option value="7d">Last 7 days</option>
                <option value="30d">Last 30 days</option>
                <option value="90d">Last 3 months</option>
              </Select>
            </HStack>
          </CardHeader>
          <CardBody>
            <Table variant="simple">
              <Thead>
                <Tr>
                  <Th>Date</Th>
                  <Th>Type</Th>
                  <Th>Description</Th>
                  <Th isNumeric>Amount</Th>
                  <Th isNumeric>Fees</Th>
                  <Th isNumeric>Net</Th>
                  <Th>Status</Th>
                </Tr>
              </Thead>
              <Tbody>
                {revenueStreams.map((stream) => {
                  const IconComponent = getRevenueTypeIcon(stream.type);
                  
                  return (
                    <Tr key={stream.id}>
                      <Td>
                        <Text fontSize="sm">
                          {stream.date.toLocaleDateString()}
                        </Text>
                      </Td>
                      <Td>
                        <HStack spacing={2}>
                          <IconComponent width="16px" />
                          <Text fontSize="sm" textTransform="capitalize">
                            {stream.type.replace('_', ' ')}
                          </Text>
                        </HStack>
                      </Td>
                      <Td>
                        <Text fontSize="sm" noOfLines={1}>
                          {stream.description}
                        </Text>
                      </Td>
                      <Td isNumeric>
                        <Text fontWeight="medium">
                          {formatCurrency(stream.amount)}
                        </Text>
                      </Td>
                      <Td isNumeric>
                        <Text fontSize="sm" color="gray.500">
                          {stream.fees ? formatCurrency(stream.fees) : '-'}
                        </Text>
                      </Td>
                      <Td isNumeric>
                        <Text fontWeight="medium" color="green.500">
                          {formatCurrency(stream.netAmount || stream.amount)}
                        </Text>
                      </Td>
                      <Td>
                        <Badge
                          colorScheme={getStatusColor(stream.status)}
                          variant="subtle"
                        >
                          {stream.status}
                        </Badge>
                      </Td>
                    </Tr>
                  );
                })}
              </Tbody>
            </Table>
          </CardBody>
        </Card>

        {/* Top Supporters */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <Text fontWeight="bold">Top Supporters</Text>
          </CardHeader>
          <CardBody>
            <VStack spacing={4} align="stretch">
              {analytics.topDonators.map((donator, index) => (
                <HStack key={index} justify="space-between" p={3} bg={cardBg} borderRadius="md">
                  <HStack spacing={3}>
                    <Text fontSize="lg" fontWeight="bold" color="gray.500">
                      #{index + 1}
                    </Text>
                    <Box
                      w={8}
                      h={8}
                      bg={donator.avatar}
                      borderRadius="full"
                      backgroundSize="cover"
                      backgroundPosition="center"
                    />
                    <VStack align="start" spacing={0}>
                      <Text fontWeight="medium">{donator.username}</Text>
                      <Text fontSize="sm" color="gray.500">
                        Last donation: {donator.lastDonation.toLocaleDateString()}
                      </Text>
                    </VStack>
                  </HStack>
                  
                  <Text fontWeight="bold" color="green.500">
                    {formatCurrency(donator.totalDonated)}
                  </Text>
                </HStack>
              ))}
            </VStack>
          </CardBody>
        </Card>

        {/* Goal Creation Modal */}
        <Modal isOpen={isGoalModalOpen} onClose={closeGoalModal}>
          <ModalOverlay />
          <ModalContent>
            <ModalHeader>Create Revenue Goal</ModalHeader>
            <ModalCloseButton />
            <ModalBody>
              <VStack spacing={4} align="stretch">
                <FormControl>
                  <FormLabel>Goal Title</FormLabel>
                  <Input
                    value={newGoal.title}
                    onChange={(e) => setNewGoal(prev => ({ ...prev, title: e.target.value }))}
                    placeholder="e.g., Monthly Revenue Target"
                  />
                </FormControl>
                
                <FormControl>
                  <FormLabel>Target Amount (£)</FormLabel>
                  <Input
                    type="number"
                    value={newGoal.targetAmount || ''}
                    onChange={(e) => setNewGoal(prev => ({ ...prev, targetAmount: parseFloat(e.target.value) || 0 }))}
                    placeholder="1000"
                  />
                </FormControl>
                
                <FormControl>
                  <FormLabel>Deadline</FormLabel>
                  <Input
                    type="date"
                    value={newGoal.deadline}
                    onChange={(e) => setNewGoal(prev => ({ ...prev, deadline: e.target.value }))}
                  />
                </FormControl>
                
                <FormControl>
                  <FormLabel>Description (Optional)</FormLabel>
                  <Textarea
                    value={newGoal.description}
                    onChange={(e) => setNewGoal(prev => ({ ...prev, description: e.target.value }))}
                    placeholder="Describe your goal..."
                    rows={3}
                  />
                </FormControl>
              </VStack>
            </ModalBody>
            <ModalFooter>
              <Button variant="ghost" mr={3} onClick={closeGoalModal}>
                Cancel
              </Button>
              <Button colorScheme="blue" onClick={createGoal}>
                Create Goal
              </Button>
            </ModalFooter>
          </ModalContent>
        </Modal>
      </VStack>
    </Box>
  );
};