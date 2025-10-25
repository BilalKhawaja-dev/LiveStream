import React, { useState, useEffect } from 'react';
import {
  Box,
  VStack,
  HStack,
  Text,
  Button,
  Input,
  InputGroup,
  InputLeftElement,
  Select,
  Card,
  CardBody,
  CardHeader,
  SimpleGrid,
  Image,
  Badge,
  Menu,
  MenuButton,
  MenuList,
  MenuItem,
  IconButton,
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
  Switch,
  Progress,
  Alert,
  AlertIcon,
  AlertDescription,
  Divider,
  Tooltip,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
} from '@chakra-ui/react';
import {
  MagnifyingGlassIcon,
  EllipsisVerticalIcon,
  PlayIcon,
  PauseIcon,
  TrashIcon,
  PencilIcon,
  EyeIcon,
  ClockIcon,
  CalendarIcon,
  CloudArrowUpIcon,
  VideoCameraIcon,
  DocumentIcon,
} from '@heroicons/react/24/outline';
import { useAuth } from '../../stubs/auth';
import { useGlobalStore } from '../../stubs/shared';

interface ContentItem {
  id: string;
  title: string;
  description: string;
  thumbnail: string;
  type: 'live' | 'vod' | 'clip' | 'highlight';
  status: 'draft' | 'scheduled' | 'published' | 'archived' | 'processing';
  visibility: 'public' | 'unlisted' | 'private';
  duration: number;
  views: number;
  likes: number;
  comments: number;
  createdAt: Date;
  publishedAt?: Date;
  scheduledAt?: Date;
  category: string;
  tags: string[];
  fileSize?: number;
  resolution?: string;
  bitrate?: number;
  moderationStatus: 'pending' | 'approved' | 'flagged' | 'rejected';
  moderationNotes?: string;
}

interface ContentStats {
  totalContent: number;
  publishedContent: number;
  draftContent: number;
  totalViews: number;
  totalDuration: number;
  storageUsed: number;
  storageLimit: number;
}

const CONTENT_CATEGORIES = [
  'Gaming',
  'Music',
  'Sports',
  'Technology',
  'Education',
  'Entertainment',
  'News',
  'Lifestyle',
  'Art & Design',
  'Science',
];

const CONTENT_TYPES = [
  { value: 'all', label: 'All Content' },
  { value: 'live', label: 'Live Streams' },
  { value: 'vod', label: 'VOD Content' },
  { value: 'clip', label: 'Clips' },
  { value: 'highlight', label: 'Highlights' },
];

const STATUS_FILTERS = [
  { value: 'all', label: 'All Status' },
  { value: 'draft', label: 'Draft' },
  { value: 'scheduled', label: 'Scheduled' },
  { value: 'published', label: 'Published' },
  { value: 'archived', label: 'Archived' },
  { value: 'processing', label: 'Processing' },
];

export const ContentManager: React.FC = () => {
  const { user } = useAuth();
  const { addNotification } = useGlobalStore();
  const toast = useToast();
  const { isOpen: isEditModalOpen, onOpen: openEditModal, onClose: closeEditModal } = useDisclosure();
  const { isOpen: isUploadModalOpen, onOpen: openUploadModal, onClose: closeUploadModal } = useDisclosure();
  
  const [searchQuery, setSearchQuery] = useState(');
  const [typeFilter, setTypeFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('createdAt');
  const [selectedContent, setSelectedContent] = useState<ContentItem | null>(null);
  const [loading, setLoading] = useState(false);
  
  const [contentItems, setContentItems] = useState<ContentItem[]>([
    {
      id: '1',
      title: 'Epic Gaming Marathon - 12 Hour Stream',
      description: 'Join me for an epic 12-hour gaming marathon featuring the latest releases and viewer challenges.',
      thumbnail: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=400',
      type: 'vod',
      status: 'published',
      visibility: 'public',
      duration: 43200,
      views: 15420,
      likes: 892,
      comments: 234,
      createdAt: new Date('2024-01-15'),
      publishedAt: new Date('2024-01-15'),
      category: 'Gaming',
      tags: ['gaming', 'marathon', 'live'],
      fileSize: 8500000000, // 8.5GB
      resolution: '1080p',
      bitrate: 5000,
      moderationStatus: 'approved',
    },
    {
      id: '2',
      title: 'New Game Review & First Impressions',
      description: 'Comprehensive review of the latest game release with first impressions and gameplay.',
      thumbnail: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=400',
      type: 'vod',
      status: 'published',
      visibility: 'public',
      duration: 3600,
      views: 8934,
      likes: 567,
      comments: 123,
      createdAt: new Date('2024-01-14'),
      publishedAt: new Date('2024-01-14'),
      category: 'Gaming',
      tags: ['review', 'gaming', 'new release'],
      fileSize: 2100000000, // 2.1GB
      resolution: '1080p',
      bitrate: 5000,
      moderationStatus: 'approved',
    },
    {
      id: '3',
      title: 'Upcoming Stream: Special Event',
      description: 'Special streaming event scheduled for this weekend with exclusive content.',
      thumbnail: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400',
      type: 'live',
      status: 'scheduled',
      visibility: 'public',
      duration: 0,
      views: 0,
      likes: 0,
      comments: 0,
      createdAt: new Date('2024-01-16'),
      scheduledAt: new Date('2024-01-20T20:00:00'),
      category: 'Gaming',
      tags: ['special event', 'exclusive'],
      moderationStatus: 'pending',
    },
  ]);
  
  const [contentStats] = useState<ContentStats>({
    totalContent: 45,
    publishedContent: 38,
    draftContent: 7,
    totalViews: 125430,
    totalDuration: 180000, // 50 hours
    storageUsed: 85000000000, // 85GB
    storageLimit: 100000000000, // 100GB
  });
  
  const [editForm, setEditForm] = useState({
    title: ',
    description: ',
    category: ',
    tags: ',
    visibility: 'public' as const,
    scheduledAt: ',
  });

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const cardBg = useColorModeValue('gray.50', 'gray.700');

  useEffect(() => {
    if (selectedContent) {
      setEditForm({
        title: selectedContent.title,
        description: selectedContent.description,
        category: selectedContent.category,
        tags: selectedContent.tags.join(', '),
        visibility: selectedContent.visibility,
        scheduledAt: selectedContent.scheduledAt?.toISOString().slice(0, 16) || ',
      });
    }
  }, [selectedContent]);

  const filteredContent = contentItems.filter(item => {
    const matchesSearch = item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         item.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         item.tags.some(tag => tag.toLowerCase().includes(searchQuery.toLowerCase()));
    
    const matchesType = typeFilter === 'all' || item.type === typeFilter;
    const matchesStatus = statusFilter === 'all' || item.status === statusFilter;
    
    return matchesSearch && matchesType && matchesStatus;
  });

  const sortedContent = [...filteredContent].sort((a, b) => {
    switch (sortBy) {
      case 'title':
        return a.title.localeCompare(b.title);
      case 'views':
        return b.views - a.views;
      case 'duration':
        return b.duration - a.duration;
      case 'createdAt':
      default:
        return b.createdAt.getTime() - a.createdAt.getTime();
    }
  });

  const handleEdit = (content: ContentItem) => {
    setSelectedContent(content);
    openEditModal();
  };

  const handleDelete = async (contentId: string) => {
    if (!confirm('Are you sure you want to delete this content? This action cannot be undone.')) {
      return;
    }
    
    setLoading(true);
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      setContentItems(prev => prev.filter(item => item.id !== contentId));
      
      addNotification({
        type: 'success',
        title: 'Content Deleted',
        message: 'Content has been successfully deleted',
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error deleting content', error, { 
          component: 'ContentManager',
          action: 'deleteContent' 
        });
      });
      toast({
        title: 'Delete Failed',
        description: 'Unable to delete content. Please try again.',
        status: 'error',
        duration: 5000,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSaveEdit = async () => {
    if (!selectedContent) return;
    
    setLoading(true);
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const updatedContent = {
        ...selectedContent,
        title: editForm.title,
        description: editForm.description,
        category: editForm.category,
        tags: editForm.tags.split(',').map(tag => tag.trim()).filter(Boolean),
        visibility: editForm.visibility,
        scheduledAt: editForm.scheduledAt ? new Date(editForm.scheduledAt) : undefined,
      };
      
      setContentItems(prev => prev.map(item => 
        item.id === selectedContent.id ? updatedContent : item
      ));
      
      closeEditModal();
      setSelectedContent(null);
      
      addNotification({
        type: 'success',
        title: 'Content Updated',
        message: 'Content has been successfully updated',
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error updating content', error, { 
          component: 'ContentManager',
          action: 'updateContent' 
        });
      });
      toast({
        title: 'Update Failed',
        description: 'Unable to update content. Please try again.',
        status: 'error',
        duration: 5000,
      });
    } finally {
      setLoading(false);
    }
  };

  const toggleVisibility = async (contentId: string, currentVisibility: string) => {
    const newVisibility = currentVisibility === 'public' ? 'private' : 'public';
    
    try {
      setContentItems(prev => prev.map(item => 
        item.id === contentId ? { ...item, visibility: newVisibility as any } : item
      ));
      
      addNotification({
        type: 'info',
        title: 'Visibility Updated',
        message: `Content is now ${newVisibility}`,
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error updating visibility', error, { 
          component: 'ContentManager',
          action: 'updateVisibility' 
        });
      });
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'published': return 'green';
      case 'scheduled': return 'blue';
      case 'draft': return 'gray';
      case 'processing': return 'yellow';
      case 'archived': return 'orange';
      default: return 'gray';
    }
  };

  const getModerationColor = (status: string) => {
    switch (status) {
      case 'approved': return 'green';
      case 'pending': return 'yellow';
      case 'flagged': return 'orange';
      case 'rejected': return 'red';
      default: return 'gray';
    }
  };

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'live': return VideoCameraIcon;
      case 'vod': return PlayIcon;
      case 'clip': return DocumentIcon;
      case 'highlight': return DocumentIcon;
      default: return DocumentIcon;
    }
  };

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        {/* Header */}
        <HStack justify="space-between">
          <Text fontSize="2xl" fontWeight="bold">Content Manager</Text>
          <Button
            leftIcon={<CloudArrowUpIcon width="16px" />}
            colorScheme="blue"
            onClick={openUploadModal}
          >
            Upload Content
          </Button>
        </HStack>

        {/* Content Stats */}
        <SimpleGrid columns={{ base: 2, md: 4, lg: 6 }} spacing={4}>
          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Total Content</StatLabel>
            <StatNumber>{contentStats.totalContent}</StatNumber>
            <StatHelpText>All items</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Published</StatLabel>
            <StatNumber>{contentStats.publishedContent}</StatNumber>
            <StatHelpText>Live content</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Drafts</StatLabel>
            <StatNumber>{contentStats.draftContent}</StatNumber>
            <StatHelpText>Unpublished</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Total Views</StatLabel>
            <StatNumber>{contentStats.totalViews.toLocaleString()}</StatNumber>
            <StatHelpText>All time</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Total Duration</StatLabel>
            <StatNumber>{formatDuration(contentStats.totalDuration)}</StatNumber>
            <StatHelpText>Content length</StatHelpText>
          </Stat>

          <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
            <StatLabel>Storage Used</StatLabel>
            <StatNumber>{formatFileSize(contentStats.storageUsed)}</StatNumber>
            <StatHelpText>
              <Progress
                value={(contentStats.storageUsed / contentStats.storageLimit) * 100}
                size="sm"
                colorScheme="blue"
                mt={1}
              />
            </StatHelpText>
          </Stat>
        </SimpleGrid>

        {/* Filters and Search */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardBody>
            <HStack spacing={4} wrap="wrap">
              <InputGroup maxW="300px">
                <InputLeftElement>
                  <MagnifyingGlassIcon width="16px" />
                </InputLeftElement>
                <Input
                  placeholder="Search content..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </InputGroup>

              <Select
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
                maxW="150px"
              >
                {CONTENT_TYPES.map(type => (
                  <option key={type.value} value={type.value}>
                    {type.label}
                  </option>
                ))}
              </Select>

              <Select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                maxW="150px"
              >
                {STATUS_FILTERS.map(status => (
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
                <option value="createdAt">Date Created</option>
                <option value="title">Title</option>
                <option value="views">Views</option>
                <option value="duration">Duration</option>
              </Select>
            </HStack>
          </CardBody>
        </Card>

        {/* Content Grid */}
        <SimpleGrid columns={{ base: 1, md: 2, lg: 3 }} spacing={6}>
          {sortedContent.map((content) => {
            const TypeIcon = getTypeIcon(content.type);
            
            return (
              <Card key={content.id} bg={cardBg} border="1px" borderColor={borderColor}>
                <CardBody p={0}>
                  <VStack spacing={0} align="stretch">
                    {/* Thumbnail */}
                    <Box position="relative">
                      <Image
                        src={content.thumbnail}
                        alt={content.title}
                        h="200px"
                        w="100%"
                        objectFit="cover"
                        borderTopRadius="md"
                      />
                      
                      {/* Type Badge */}
                      <Badge
                        position="absolute"
                        top={2}
                        left={2}
                        colorScheme="blue"
                        variant="solid"
                      >
                        <HStack spacing={1}>
                          <TypeIcon width="12px" />
                          <Text>{content.type.toUpperCase()}</Text>
                        </HStack>
                      </Badge>
                      
                      {/* Duration */}
                      {content.duration > 0 && (
                        <Badge
                          position="absolute"
                          bottom={2}
                          right={2}
                          bg="blackAlpha.700"
                          color="white"
                        >
                          {formatDuration(content.duration)}
                        </Badge>
                      )}
                      
                      {/* Menu */}
                      <Menu>
                        <MenuButton
                          as={IconButton}
                          icon={<EllipsisVerticalIcon width="16px" />}
                          variant="ghost"
                          size="sm"
                          position="absolute"
                          top={2}
                          right={2}
                          bg="blackAlpha.600"
                          color="white"
                          _hover={{ bg: 'blackAlpha.800' }}
                        />
                        <MenuList>
                          <MenuItem
                            icon={<PencilIcon width="16px" />}
                            onClick={() => handleEdit(content)}
                          >
                            Edit
                          </MenuItem>
                          <MenuItem
                            icon={<EyeIcon width="16px" />}
                            onClick={() => toggleVisibility(content.id, content.visibility)}
                          >
                            {content.visibility === 'public' ? 'Make Private' : 'Make Public'}
                          </MenuItem>
                          <MenuItem
                            icon={<TrashIcon width="16px" />}
                            onClick={() => handleDelete(content.id)}
                            color="red.500"
                          >
                            Delete
                          </MenuItem>
                        </MenuList>
                      </Menu>
                    </Box>

                    {/* Content Info */}
                    <VStack spacing={3} align="stretch" p={4}>
                      <VStack spacing={2} align="stretch">
                        <Text fontWeight="bold" fontSize="md" noOfLines={2}>
                          {content.title}
                        </Text>
                        
                        <Text fontSize="sm" color="gray.500" noOfLines={2}>
                          {content.description}
                        </Text>
                      </VStack>

                      {/* Status Badges */}
                      <HStack spacing={2} wrap="wrap">
                        <Badge colorScheme={getStatusColor(content.status)}>
                          {content.status}
                        </Badge>
                        
                        <Badge colorScheme={getModerationColor(content.moderationStatus)}>
                          {content.moderationStatus}
                        </Badge>
                        
                        <Badge variant="outline">
                          {content.visibility}
                        </Badge>
                      </HStack>

                      {/* Stats */}
                      <HStack justify="space-between" fontSize="sm" color="gray.500">
                        <HStack>
                          <EyeIcon width="16px" />
                          <Text>{content.views.toLocaleString()}</Text>
                        </HStack>
                        
                        <HStack>
                          <CalendarIcon width="16px" />
                          <Text>{content.createdAt.toLocaleDateString()}</Text>
                        </HStack>
                      </HStack>

                      {/* Scheduled Info */}
                      {content.scheduledAt && (
                        <Alert status="info" borderRadius="md" py={2}>
                          <AlertIcon />
                          <AlertDescription fontSize="sm">
                            Scheduled for {content.scheduledAt.toLocaleString()}
                          </AlertDescription>
                        </Alert>
                      )}

                      {/* File Info */}
                      {content.fileSize && (
                        <HStack justify="space-between" fontSize="xs" color="gray.500">
                          <Text>{formatFileSize(content.fileSize)}</Text>
                          <Text>{content.resolution} • {content.bitrate}kbps</Text>
                        </HStack>
                      )}
                    </VStack>
                  </VStack>
                </CardBody>
              </Card>
            );
          })}
        </SimpleGrid>

        {/* No Results */}
        {sortedContent.length === 0 && (
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardBody textAlign="center" py={8}>
              <Text color="gray.500">No content found matching your criteria</Text>
            </CardBody>
          </Card>
        )}

        {/* Edit Modal */}
        <Modal isOpen={isEditModalOpen} onClose={closeEditModal} size="xl">
          <ModalOverlay />
          <ModalContent>
            <ModalHeader>Edit Content</ModalHeader>
            <ModalCloseButton />
            <ModalBody>
              <VStack spacing={4} align="stretch">
                <FormControl>
                  <FormLabel>Title</FormLabel>
                  <Input
                    value={editForm.title}
                    onChange={(e) => setEditForm(prev => ({ ...prev, title: e.target.value }))}
                  />
                </FormControl>
                
                <FormControl>
                  <FormLabel>Description</FormLabel>
                  <Textarea
                    value={editForm.description}
                    onChange={(e) => setEditForm(prev => ({ ...prev, description: e.target.value }))}
                    rows={4}
                  />
                </FormControl>
                
                <HStack spacing={4}>
                  <FormControl>
                    <FormLabel>Category</FormLabel>
                    <Select
                      value={editForm.category}
                      onChange={(e) => setEditForm(prev => ({ ...prev, category: e.target.value }))}
                    >
                      {CONTENT_CATEGORIES.map(category => (
                        <option key={category} value={category}>
                          {category}
                        </option>
                      ))}
                    </Select>
                  </FormControl>
                  
                  <FormControl>
                    <FormLabel>Visibility</FormLabel>
                    <Select
                      value={editForm.visibility}
                      onChange={(e) => setEditForm(prev => ({ ...prev, visibility: e.target.value as any }))}
                    >
                      <option value="public">Public</option>
                      <option value="unlisted">Unlisted</option>
                      <option value="private">Private</option>
                    </Select>
                  </FormControl>
                </HStack>
                
                <FormControl>
                  <FormLabel>Tags (comma separated)</FormLabel>
                  <Input
                    value={editForm.tags}
                    onChange={(e) => setEditForm(prev => ({ ...prev, tags: e.target.value }))}
                    placeholder="gaming, review, tutorial"
                  />
                </FormControl>
                
                {selectedContent?.type === 'live' && (
                  <FormControl>
                    <FormLabel>Scheduled Date & Time</FormLabel>
                    <Input
                      type="datetime-local"
                      value={editForm.scheduledAt}
                      onChange={(e) => setEditForm(prev => ({ ...prev, scheduledAt: e.target.value }))}
                    />
                  </FormControl>
                )}
              </VStack>
            </ModalBody>
            <ModalFooter>
              <Button variant="ghost" mr={3} onClick={closeEditModal}>
                Cancel
              </Button>
              <Button
                colorScheme="blue"
                onClick={handleSaveEdit}
                isLoading={loading}
              >
                Save Changes
              </Button>
            </ModalFooter>
          </ModalContent>
        </Modal>

        {/* Upload Modal */}
        <Modal isOpen={isUploadModalOpen} onClose={closeUploadModal} size="xl">
          <ModalOverlay />
          <ModalContent>
            <ModalHeader>Upload Content</ModalHeader>
            <ModalCloseButton />
            <ModalBody>
              <VStack spacing={6} align="stretch">
                <Alert status="info">
                  <AlertIcon />
                  <AlertDescription>
                    Upload your video content to MediaStore. Supported formats: MP4, MOV, AVI. Max file size: 10GB.
                  </AlertDescription>
                </Alert>
                
                <Box
                  border="2px dashed"
                  borderColor="gray.300"
                  borderRadius="md"
                  p={8}
                  textAlign="center"
                  cursor="pointer"
                  _hover={{ borderColor: 'blue.400' }}
                >
                  <VStack spacing={4}>
                    <CloudArrowUpIcon width="48px" color="gray.400" />
                    <Text>Drag and drop your video file here, or click to browse</Text>
                    <Button colorScheme="blue" variant="outline">
                      Choose File
                    </Button>
                  </VStack>
                </Box>
              </VStack>
            </ModalBody>
            <ModalFooter>
              <Button variant="ghost" mr={3} onClick={closeUploadModal}>
                Cancel
              </Button>
              <Button colorScheme="blue">
                Start Upload
              </Button>
            </ModalFooter>
          </ModalContent>
        </Modal>
      </VStack>
    </Box>
  );
};