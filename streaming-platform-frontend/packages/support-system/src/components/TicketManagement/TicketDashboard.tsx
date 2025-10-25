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
  Badge,
  Button,
  Input,
  InputGroup,
  InputLeftElement,
  Select,
  useColorModeValue,
  useToast,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalBody,
  ModalFooter,
  ModalCloseButton,
  useDisclosure,
  FormControl,
  FormLabel,
  Textarea,
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  Avatar,
  Tooltip,
  IconButton,
  Menu,
  MenuButton,
  MenuList,
  MenuItem,
  Spinner,
  Alert,
  AlertIcon,
  AlertDescription,
  Progress,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  StatArrow,
  Divider,
  Tag,
  TagLabel,
  TagCloseButton,
  Accordion,
  AccordionItem,
  AccordionButton,
  AccordionPanel,
  AccordionIcon,
} from '@chakra-ui/react';
import {
  MagnifyingGlassIcon,
  PlusIcon,
  EllipsisVerticalIcon,
  ChatBubbleLeftIcon,
  ClockIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon,
  XCircleIcon,
  UserIcon,
  TagIcon,
  CalendarIcon,
  ArrowPathIcon,
  PaperAirplaneIcon,
  DocumentTextIcon,
  SparklesIcon,
} from '@heroicons/react/24/outline';
import { useAuth } from '../../stubs/auth';
import { useGlobalStore } from '../../stubs/shared';

interface TicketData {
  id: string;
  subject: string;
  description: string;
  status: 'open' | 'in_progress' | 'waiting_response' | 'resolved' | 'closed';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  category: string;
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
  assignedTo?: string;
  assignedToName?: string;
  assignedToAvatar?: string;
  requesterName: string;
  requesterEmail: string;
  requesterAvatar?: string;
  sourceContext?: {
    application: string;
    currentPage: string;
    userAgent: string;
  };
  aiSuggestions?: string[];
  messages: TicketMessage[];
  estimatedResolutionTime?: number;
  satisfactionRating?: number;
}

interface TicketMessage {
  id: string;
  content: string;
  author: string;
  authorType: 'user' | 'agent' | 'system' | 'ai';
  timestamp: Date;
  attachments?: string[];
  isInternal?: boolean;
}

interface TicketStats {
  totalTickets: number;
  openTickets: number;
  inProgressTickets: number;
  resolvedToday: number;
  avgResolutionTime: number;
  satisfactionScore: number;
  responseTime: number;
}

const TICKET_CATEGORIES = [
  'All Categories',
  'Technical Issue',
  'Account Problem',
  'Billing Question',
  'Feature Request',
  'Bug Report',
  'General Inquiry',
  'Streaming Issue',
  'Payment Problem',
  'Content Moderation',
];

const PRIORITY_LEVELS = [
  { value: 'all', label: 'All Priorities' },
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
  { value: 'urgent', label: 'Urgent' },
];

const STATUS_OPTIONS = [
  { value: 'all', label: 'All Status' },
  { value: 'open', label: 'Open' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'waiting_response', label: 'Waiting Response' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'closed', label: 'Closed' },
];

export const TicketDashboard: React.FC = () => {
  const { user } = useAuth();
  const { addNotification } = useGlobalStore();
  const toast = useToast();
  const { isOpen: isTicketModalOpen, onOpen: openTicketModal, onClose: closeTicketModal } = useDisclosure();
  const { isOpen: isCreateModalOpen, onOpen: openCreateModal, onClose: closeCreateModal } = useDisclosure();
  
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All Categories');
  const [priorityFilter, setPriorityFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('updatedAt');
  
  const [selectedTicket, setSelectedTicket] = useState<TicketData | null>(null);
  const [loading, setLoading] = useState(false);
  const [newMessage, setNewMessage] = useState('');
  
  const [newTicket, setNewTicket] = useState({
    subject: '',
    description: '',
    category: 'Technical Issue',
    priority: 'medium' as const,
    tags: [] as string[],
  });
  
  const [tickets, setTickets] = useState<TicketData[]>([
    {
      id: 'TKT-001',
      subject: 'Unable to start live stream',
      description: 'I am having trouble starting my live stream. The video quality is poor and there are connection issues.',
      status: 'open',
      priority: 'high',
      category: 'Streaming Issue',
      tags: ['streaming', 'video quality', 'connection'],
      createdAt: new Date('2024-01-16T10:30:00'),
      updatedAt: new Date('2024-01-16T14:20:00'),
      assignedTo: 'agent1',
      assignedToName: 'Sarah Johnson',
      assignedToAvatar: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100',
      requesterName: 'John Doe',
      requesterEmail: 'john.doe@example.com',
      requesterAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
      sourceContext: {
        application: 'creator-dashboard',
        currentPage: '/streaming',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
      aiSuggestions: [
        'Check MediaLive channel configuration',
        'Verify network bandwidth requirements',
        'Review streaming software settings',
      ],
      messages: [
        {
          id: 'msg1',
          content: 'I am having trouble starting my live stream. The video quality is poor and there are connection issues.',
          author: 'John Doe',
          authorType: 'user',
          timestamp: new Date('2024-01-16T10:30:00'),
        },
        {
          id: 'msg2',
          content: 'Thank you for contacting support. I can see you\'re having streaming issues. Let me check your account configuration.',
          author: 'Sarah Johnson',
          authorType: 'agent',
          timestamp: new Date('2024-01-16T11:15:00'),
        },
        {
          id: 'msg3',
          content: 'AI Analysis: User\'s bitrate settings appear to be too high for their current network capacity. Recommend reducing to 3000 kbps.',
          author: 'AI Assistant',
          authorType: 'ai',
          timestamp: new Date('2024-01-16T11:16:00'),
          isInternal: true,
        },
      ],
      estimatedResolutionTime: 120, // minutes
    },
    {
      id: 'TKT-002',
      subject: 'Billing discrepancy on subscription',
      description: 'I was charged twice for my gold subscription this month. Please help resolve this billing issue.',
      status: 'in_progress',
      priority: 'medium',
      category: 'Billing Question',
      tags: ['billing', 'subscription', 'duplicate charge'],
      createdAt: new Date('2024-01-15T16:45:00'),
      updatedAt: new Date('2024-01-16T09:30:00'),
      assignedTo: 'agent2',
      assignedToName: 'Mike Chen',
      assignedToAvatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
      requesterName: 'Jane Smith',
      requesterEmail: 'jane.smith@example.com',
      requesterAvatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100',
      messages: [
        {
          id: 'msg4',
          content: 'I was charged twice for my gold subscription this month. Please help resolve this billing issue.',
          author: 'Jane Smith',
          authorType: 'user',
          timestamp: new Date('2024-01-15T16:45:00'),
        },
        {
          id: 'msg5',
          content: 'I\'ve reviewed your billing history and can see the duplicate charge. I\'m processing a refund for the extra charge now.',
          author: 'Mike Chen',
          authorType: 'agent',
          timestamp: new Date('2024-01-16T09:30:00'),
        },
      ],
      estimatedResolutionTime: 60,
    },
    {
      id: 'TKT-003',
      subject: 'Feature request: Dark mode for viewer portal',
      description: 'It would be great to have a dark mode option for the viewer portal to reduce eye strain during night viewing.',
      status: 'waiting_response',
      priority: 'low',
      category: 'Feature Request',
      tags: ['feature request', 'dark mode', 'UI'],
      createdAt: new Date('2024-01-14T20:15:00'),
      updatedAt: new Date('2024-01-15T10:00:00'),
      assignedTo: 'agent3',
      assignedToName: 'Lisa Wang',
      assignedToAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100',
      requesterName: 'Alex Johnson',
      requesterEmail: 'alex.johnson@example.com',
      messages: [
        {
          id: 'msg6',
          content: 'It would be great to have a dark mode option for the viewer portal to reduce eye strain during night viewing.',
          author: 'Alex Johnson',
          authorType: 'user',
          timestamp: new Date('2024-01-14T20:15:00'),
        },
        {
          id: 'msg7',
          content: 'Thank you for the suggestion! Dark mode is actually on our roadmap for Q2 2024. I\'ll add your vote to this feature request.',
          author: 'Lisa Wang',
          authorType: 'agent',
          timestamp: new Date('2024-01-15T10:00:00'),
        },
      ],
      estimatedResolutionTime: 30,
    },
  ]);
  
  const [ticketStats] = useState<TicketStats>({
    totalTickets: 156,
    openTickets: 23,
    inProgressTickets: 12,
    resolvedToday: 8,
    avgResolutionTime: 4.2, // hours
    satisfactionScore: 4.6,
    responseTime: 15, // minutes
  });

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const cardBg = useColorModeValue('blue.50', 'blue.900');
  const blueColor = useColorModeValue('blue.600', 'blue.300');
  const pinkColor = useColorModeValue('pink.500', 'pink.300');

  // Filter and sort tickets
  const filteredTickets = tickets.filter(ticket => {
    const matchesSearch = ticket.subject.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         ticket.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         ticket.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         ticket.requesterName.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesCategory = categoryFilter === 'All Categories' || ticket.category === categoryFilter;
    const matchesPriority = priorityFilter === 'all' || ticket.priority === priorityFilter;
    const matchesStatus = statusFilter === 'all' || ticket.status === statusFilter;
    
    return matchesSearch && matchesCategory && matchesPriority && matchesStatus;
  });

  const sortedTickets = [...filteredTickets].sort((a, b) => {
    switch (sortBy) {
      case 'priority':
        const priorityOrder = { urgent: 4, high: 3, medium: 2, low: 1 };
        return priorityOrder[b.priority] - priorityOrder[a.priority];
      case 'createdAt':
        return b.createdAt.getTime() - a.createdAt.getTime();
      case 'updatedAt':
      default:
        return b.updatedAt.getTime() - a.updatedAt.getTime();
    }
  });

  const handleViewTicket = (ticket: TicketData) => {
    setSelectedTicket(ticket);
    openTicketModal();
  };

  const handleSendMessage = async () => {
    if (!selectedTicket || !newMessage.trim()) return;
    
    setLoading(true);
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const message: TicketMessage = {
        id: `msg${Date.now()}`,
        content: newMessage,
        author: user?.displayName || user?.username || 'Agent',
        authorType: 'agent',
        timestamp: new Date(),
      };
      
      setTickets(prev => prev.map(ticket => 
        ticket.id === selectedTicket.id 
          ? { ...ticket, messages: [...ticket.messages, message], updatedAt: new Date() }
          : ticket
      ));
      
      setSelectedTicket(prev => prev ? { ...prev, messages: [...prev.messages, message] } : null);
      setNewMessage('');
      
      addNotification({
        type: 'success',
        title: 'Message Sent',
        message: 'Your response has been sent to the customer',
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error sending message', error, { 
          component: 'TicketDashboard',
          action: 'sendMessage' 
        });
      });
      toast({
        title: 'Send Failed',
        description: 'Unable to send message. Please try again.',
        status: 'error',
        duration: 5000,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleCreateTicket = async () => {
    if (!newTicket.subject.trim() || !newTicket.description.trim()) {
      toast({
        title: 'Missing Information',
        description: 'Please fill in all required fields',
        status: 'warning',
        duration: 3000,
      });
      return;
    }
    
    setLoading(true);
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      const ticket: TicketData = {
        id: `TKT-${String(tickets.length + 1).padStart(3, '0')}`,
        subject: newTicket.subject,
        description: newTicket.description,
        status: 'open',
        priority: newTicket.priority,
        category: newTicket.category,
        tags: newTicket.tags,
        createdAt: new Date(),
        updatedAt: new Date(),
        requesterName: user?.displayName || user?.username || 'User',
        requesterEmail: user?.email || 'user@example.com',
        messages: [
          {
            id: 'msg1',
            content: newTicket.description,
            author: user?.displayName || user?.username || 'User',
            authorType: 'user',
            timestamp: new Date(),
          },
        ],
      };
      
      setTickets(prev => [ticket, ...prev]);
      closeCreateModal();
      
      // Reset form
      setNewTicket({
        subject: '',
        description: '',
        category: 'Technical Issue',
        priority: 'medium',
        tags: [],
      });
      
      addNotification({
        type: 'success',
        title: 'Ticket Created',
        message: `Ticket ${ticket.id} has been created successfully`,
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error creating ticket', error, { 
          component: 'TicketDashboard',
          action: 'createTicket' 
        });
      });
      toast({
        title: 'Creation Failed',
        description: 'Unable to create ticket. Please try again.',
        status: 'error',
        duration: 5000,
      });
    } finally {
      setLoading(false);
    }
  };

  const updateTicketStatus = async (ticketId: string, newStatus: TicketData['status']) => {
    setLoading(true);
    try {
      await new Promise(resolve => setTimeout(resolve, 500));
      
      setTickets(prev => prev.map(ticket => 
        ticket.id === ticketId 
          ? { ...ticket, status: newStatus, updatedAt: new Date() }
          : ticket
      ));
      
      if (selectedTicket?.id === ticketId) {
        setSelectedTicket(prev => prev ? { ...prev, status: newStatus } : null);
      }
      
      toast({
        title: 'Status Updated',
        description: `Ticket status changed to ${newStatus.replace('_', ' ')}`,
        status: 'success',
        duration: 3000,
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error updating ticket status', error, { 
          component: 'TicketDashboard',
          action: 'updateStatus' 
        });
      });
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open': return 'red';
      case 'in_progress': return 'blue';
      case 'waiting_response': return 'yellow';
      case 'resolved': return 'green';
      case 'closed': return 'gray';
      default: return 'gray';
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'urgent': return 'red';
      case 'high': return 'orange';
      case 'medium': return 'yellow';
      case 'low': return 'green';
      default: return 'gray';
    }
  };

  const formatTimeAgo = (date: Date) => {
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);
    
    if (diffMins < 60) {
      return `${diffMins}m ago`;
    } else if (diffHours < 24) {
      return `${diffHours}h ago`;
    } else {
      return `${diffDays}d ago`;
    }
  };

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        {/* Header */}
        <HStack justify="space-between">
          <VStack align="start" spacing={1}>
            <Text fontSize="2xl" fontWeight="bold" color={blueColor}>
              Support Dashboard
            </Text>
            <Text fontSize="sm" color="gray.500">
              Manage customer support tickets and inquiries
            </Text>
          </VStack>
          
          <Button
            leftIcon={<PlusIcon width="16px" />}
            colorScheme="blue"
            onClick={openCreateModal}
          >
            Create Ticket
          </Button>
        </HStack>

        {/* Stats Overview */}
        <SimpleGrid columns={{ base: 2, md: 4, lg: 7 }} spacing={4}>
          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Total Tickets</StatLabel>
            <StatNumber color={blueColor}>{ticketStats.totalTickets}</StatNumber>
            <StatHelpText>All time</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Open</StatLabel>
            <StatNumber color="red.500">{ticketStats.openTickets}</StatNumber>
            <StatHelpText>Needs attention</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>In Progress</StatLabel>
            <StatNumber color="blue.500">{ticketStats.inProgressTickets}</StatNumber>
            <StatHelpText>Being worked on</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Resolved Today</StatLabel>
            <StatNumber color="green.500">{ticketStats.resolvedToday}</StatNumber>
            <StatHelpText>
              <StatArrow type="increase" />
              +12% from yesterday
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Avg Resolution</StatLabel>
            <StatNumber color={pinkColor}>{ticketStats.avgResolutionTime}h</StatNumber>
            <StatHelpText>
              <StatArrow type="decrease" />
              -8% this week
            </StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Satisfaction</StatLabel>
            <StatNumber color="green.500">{ticketStats.satisfactionScore}/5</StatNumber>
            <StatHelpText>Customer rating</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Response Time</StatLabel>
            <StatNumber color={blueColor}>{ticketStats.responseTime}m</StatNumber>
            <StatHelpText>Average first response</StatHelpText>
          </Stat>
        </SimpleGrid>

        {/* Filters */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardBody>
            <VStack spacing={4} align="stretch">
              <InputGroup>
                <InputLeftElement>
                  <MagnifyingGlassIcon width="16px" />
                </InputLeftElement>
                <Input
                  placeholder="Search tickets by ID, subject, or customer..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </InputGroup>
              
              <HStack spacing={4} wrap="wrap">
                <Select
                  value={categoryFilter}
                  onChange={(e) => setCategoryFilter(e.target.value)}
                  maxW="200px"
                >
                  {TICKET_CATEGORIES.map(category => (
                    <option key={category} value={category}>
                      {category}
                    </option>
                  ))}
                </Select>
                
                <Select
                  value={priorityFilter}
                  onChange={(e) => setPriorityFilter(e.target.value)}
                  maxW="150px"
                >
                  {PRIORITY_LEVELS.map(priority => (
                    <option key={priority.value} value={priority.value}>
                      {priority.label}
                    </option>
                  ))}
                </Select>
                
                <Select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  maxW="150px"
                >
                  {STATUS_OPTIONS.map(status => (
                    <option key={status.value} value={status.value}>
                      {status.label}
                    </option>
                  ))}
                </Select>
                
                <Select
                  value={sortBy}
                  onChange={(e) => setSortBy(e.target.value)}
                  maxW="150px"
                >
                  <option value="updatedAt">Last Updated</option>
                  <option value="createdAt">Date Created</option>
                  <option value="priority">Priority</option>
                </Select>
              </HStack>
            </VStack>
          </CardBody>
        </Card>

        {/* Tickets Table */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardHeader>
            <HStack justify="space-between">
              <Text fontWeight="bold" color={blueColor}>
                Support Tickets ({sortedTickets.length})
              </Text>
              <IconButton
                aria-label="Refresh tickets"
                icon={<ArrowPathIcon width="16px" />}
                size="sm"
                variant="ghost"
                onClick={() => window.location.reload()}
              />
            </HStack>
          </CardHeader>
          <CardBody>
            <Table variant="simple">
              <Thead>
                <Tr>
                  <Th>Ticket ID</Th>
                  <Th>Subject</Th>
                  <Th>Customer</Th>
                  <Th>Status</Th>
                  <Th>Priority</Th>
                  <Th>Assigned To</Th>
                  <Th>Updated</Th>
                  <Th>Actions</Th>
                </Tr>
              </Thead>
              <Tbody>
                {sortedTickets.map((ticket) => (
                  <Tr key={ticket.id} _hover={{ bg: cardBg }}>
                    <Td>
                      <Text fontWeight="bold" color={blueColor}>
                        {ticket.id}
                      </Text>
                    </Td>
                    <Td>
                      <VStack align="start" spacing={1}>
                        <Text fontWeight="medium" noOfLines={1}>
                          {ticket.subject}
                        </Text>
                        <HStack spacing={1}>
                          {ticket.tags.slice(0, 2).map((tag, index) => (
                            <Badge key={index} size="sm" colorScheme="gray">
                              {tag}
                            </Badge>
                          ))}
                        </HStack>
                      </VStack>
                    </Td>
                    <Td>
                      <HStack spacing={2}>
                        <Avatar size="sm" src={ticket.requesterAvatar} />
                        <VStack align="start" spacing={0}>
                          <Text fontSize="sm" fontWeight="medium">
                            {ticket.requesterName}
                          </Text>
                          <Text fontSize="xs" color="gray.500">
                            {ticket.requesterEmail}
                          </Text>
                        </VStack>
                      </HStack>
                    </Td>
                    <Td>
                      <Badge colorScheme={getStatusColor(ticket.status)}>
                        {ticket.status.replace('_', ' ')}
                      </Badge>
                    </Td>
                    <Td>
                      <Badge colorScheme={getPriorityColor(ticket.priority)}>
                        {ticket.priority}
                      </Badge>
                    </Td>
                    <Td>
                      {ticket.assignedToName ? (
                        <HStack spacing={2}>
                          <Avatar size="xs" src={ticket.assignedToAvatar} />
                          <Text fontSize="sm">{ticket.assignedToName}</Text>
                        </HStack>
                      ) : (
                        <Text fontSize="sm" color="gray.500">
                          Unassigned
                        </Text>
                      )}
                    </Td>
                    <Td>
                      <Text fontSize="sm" color="gray.500">
                        {formatTimeAgo(ticket.updatedAt)}
                      </Text>
                    </Td>
                    <Td>
                      <HStack spacing={1}>
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => handleViewTicket(ticket)}
                        >
                          View
                        </Button>
                        <Menu>
                          <MenuButton
                            as={IconButton}
                            icon={<EllipsisVerticalIcon width="16px" />}
                            size="sm"
                            variant="ghost"
                          />
                          <MenuList>
                            <MenuItem onClick={() => updateTicketStatus(ticket.id, 'in_progress')}>
                              Mark In Progress
                            </MenuItem>
                            <MenuItem onClick={() => updateTicketStatus(ticket.id, 'resolved')}>
                              Mark Resolved
                            </MenuItem>
                            <MenuItem onClick={() => updateTicketStatus(ticket.id, 'closed')}>
                              Close Ticket
                            </MenuItem>
                          </MenuList>
                        </Menu>
                      </HStack>
                    </Td>
                  </Tr>
                ))}
              </Tbody>
            </Table>
            
            {sortedTickets.length === 0 && (
              <Box textAlign="center" py={8}>
                <Text color="gray.500">No tickets found matching your criteria</Text>
              </Box>
            )}
          </CardBody>
        </Card>

        {/* Ticket Detail Modal */}
        <Modal isOpen={isTicketModalOpen} onClose={closeTicketModal} size="4xl">
          <ModalOverlay />
          <ModalContent>
            <ModalHeader color={blueColor}>
              {selectedTicket?.id} - {selectedTicket?.subject}
            </ModalHeader>
            <ModalCloseButton />
            <ModalBody>
              {selectedTicket && (
                <VStack spacing={6} align="stretch">
                  {/* Ticket Info */}
                  <SimpleGrid columns={{ base: 1, md: 2 }} spacing={4}>
                    <VStack align="stretch" spacing={3}>
                      <Box>
                        <Text fontSize="sm" color="gray.500">Status</Text>
                        <Badge colorScheme={getStatusColor(selectedTicket.status)}>
                          {selectedTicket.status.replace('_', ' ')}
                        </Badge>
                      </Box>
                      
                      <Box>
                        <Text fontSize="sm" color="gray.500">Priority</Text>
                        <Badge colorScheme={getPriorityColor(selectedTicket.priority)}>
                          {selectedTicket.priority}
                        </Badge>
                      </Box>
                      
                      <Box>
                        <Text fontSize="sm" color="gray.500">Category</Text>
                        <Text>{selectedTicket.category}</Text>
                      </Box>
                    </VStack>
                    
                    <VStack align="stretch" spacing={3}>
                      <Box>
                        <Text fontSize="sm" color="gray.500">Customer</Text>
                        <HStack>
                          <Avatar size="sm" src={selectedTicket.requesterAvatar} />
                          <VStack align="start" spacing={0}>
                            <Text fontWeight="medium">{selectedTicket.requesterName}</Text>
                            <Text fontSize="sm" color="gray.500">{selectedTicket.requesterEmail}</Text>
                          </VStack>
                        </HStack>
                      </Box>
                      
                      <Box>
                        <Text fontSize="sm" color="gray.500">Assigned To</Text>
                        {selectedTicket.assignedToName ? (
                          <HStack>
                            <Avatar size="sm" src={selectedTicket.assignedToAvatar} />
                            <Text>{selectedTicket.assignedToName}</Text>
                          </HStack>
                        ) : (
                          <Text color="gray.500">Unassigned</Text>
                        )}
                      </Box>
                      
                      <Box>
                        <Text fontSize="sm" color="gray.500">Created</Text>
                        <Text>{selectedTicket.createdAt.toLocaleString()}</Text>
                      </Box>
                    </VStack>
                  </SimpleGrid>

                  {/* AI Suggestions */}
                  {selectedTicket.aiSuggestions && selectedTicket.aiSuggestions.length > 0 && (
                    <Card bg="purple.50" border="1px" borderColor="purple.200">
                      <CardHeader>
                        <HStack>
                          <SparklesIcon width="20px" color="purple" />
                          <Text fontWeight="bold" color="purple.600">AI Suggestions</Text>
                        </HStack>
                      </CardHeader>
                      <CardBody>
                        <VStack align="stretch" spacing={2}>
                          {selectedTicket.aiSuggestions.map((suggestion, index) => (
                            <HStack key={index} align="start" spacing={3}>
                              <Box w={2} h={2} bg="purple.500" borderRadius="full" mt={2} flexShrink={0} />
                              <Text fontSize="sm">{suggestion}</Text>
                            </HStack>
                          ))}
                        </VStack>
                      </CardBody>
                    </Card>
                  )}

                  {/* Messages */}
                  <Card bg={bg} border="1px" borderColor={borderColor}>
                    <CardHeader>
                      <Text fontWeight="bold">Conversation</Text>
                    </CardHeader>
                    <CardBody>
                      <VStack spacing={4} align="stretch" maxH="400px" overflowY="auto">
                        {selectedTicket.messages.map((message) => (
                          <HStack
                            key={message.id}
                            align="start"
                            spacing={3}
                            opacity={message.isInternal ? 0.7 : 1}
                          >
                            <Avatar
                              size="sm"
                              name={message.author}
                              bg={
                                message.authorType === 'agent' ? 'blue.500' :
                                message.authorType === 'ai' ? 'purple.500' :
                                message.authorType === 'system' ? 'gray.500' : 'green.500'
                              }
                            />
                            <VStack align="start" spacing={1} flex={1}>
                              <HStack spacing={2}>
                                <Text fontSize="sm" fontWeight="medium">
                                  {message.author}
                                </Text>
                                <Badge
                                  size="sm"
                                  colorScheme={
                                    message.authorType === 'agent' ? 'blue' :
                                    message.authorType === 'ai' ? 'purple' :
                                    message.authorType === 'system' ? 'gray' : 'green'
                                  }
                                >
                                  {message.authorType}
                                </Badge>
                                <Text fontSize="xs" color="gray.500">
                                  {message.timestamp.toLocaleString()}
                                </Text>
                                {message.isInternal && (
                                  <Badge size="sm" colorScheme="orange">
                                    Internal
                                  </Badge>
                                )}
                              </HStack>
                              <Text fontSize="sm" whiteSpace="pre-wrap">
                                {message.content}
                              </Text>
                            </VStack>
                          </HStack>
                        ))}
                      </VStack>
                      
                      <Divider my={4} />
                      
                      {/* Reply Form */}
                      <VStack spacing={3} align="stretch">
                        <Textarea
                          placeholder="Type your response..."
                          value={newMessage}
                          onChange={(e) => setNewMessage(e.target.value)}
                          rows={3}
                        />
                        <HStack justify="space-between">
                          <HStack spacing={2}>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => updateTicketStatus(selectedTicket.id, 'in_progress')}
                            >
                              Mark In Progress
                            </Button>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => updateTicketStatus(selectedTicket.id, 'resolved')}
                            >
                              Mark Resolved
                            </Button>
                          </HStack>
                          <Button
                            leftIcon={<PaperAirplaneIcon width="16px" />}
                            colorScheme="blue"
                            onClick={handleSendMessage}
                            isLoading={loading}
                            isDisabled={!newMessage.trim()}
                          >
                            Send Reply
                          </Button>
                        </HStack>
                      </VStack>
                    </CardBody>
                  </Card>
                </VStack>
              )}
            </ModalBody>
          </ModalContent>
        </Modal>

        {/* Create Ticket Modal */}
        <Modal isOpen={isCreateModalOpen} onClose={closeCreateModal} size="xl">
          <ModalOverlay />
          <ModalContent>
            <ModalHeader color={blueColor}>Create New Ticket</ModalHeader>
            <ModalCloseButton />
            <ModalBody>
              <VStack spacing={4} align="stretch">
                <FormControl isRequired>
                  <FormLabel>Subject</FormLabel>
                  <Input
                    value={newTicket.subject}
                    onChange={(e) => setNewTicket(prev => ({ ...prev, subject: e.target.value }))}
                    placeholder="Brief description of the issue"
                  />
                </FormControl>
                
                <FormControl isRequired>
                  <FormLabel>Description</FormLabel>
                  <Textarea
                    value={newTicket.description}
                    onChange={(e) => setNewTicket(prev => ({ ...prev, description: e.target.value }))}
                    placeholder="Detailed description of the issue or request"
                    rows={4}
                  />
                </FormControl>
                
                <HStack spacing={4}>
                  <FormControl>
                    <FormLabel>Category</FormLabel>
                    <Select
                      value={newTicket.category}
                      onChange={(e) => setNewTicket(prev => ({ ...prev, category: e.target.value }))}
                    >
                      {TICKET_CATEGORIES.slice(1).map(category => (
                        <option key={category} value={category}>
                          {category}
                        </option>
                      ))}
                    </Select>
                  </FormControl>
                  
                  <FormControl>
                    <FormLabel>Priority</FormLabel>
                    <Select
                      value={newTicket.priority}
                      onChange={(e) => setNewTicket(prev => ({ ...prev, priority: e.target.value as any }))}
                    >
                      <option value="low">Low</option>
                      <option value="medium">Medium</option>
                      <option value="high">High</option>
                      <option value="urgent">Urgent</option>
                    </Select>
                  </FormControl>
                </HStack>
              </VStack>
            </ModalBody>
            <ModalFooter>
              <Button variant="ghost" mr={3} onClick={closeCreateModal}>
                Cancel
              </Button>
              <Button
                colorScheme="blue"
                onClick={handleCreateTicket}
                isLoading={loading}
              >
                Create Ticket
              </Button>
            </ModalFooter>
          </ModalContent>
        </Modal>
      </VStack>
    </Box>
  );
};