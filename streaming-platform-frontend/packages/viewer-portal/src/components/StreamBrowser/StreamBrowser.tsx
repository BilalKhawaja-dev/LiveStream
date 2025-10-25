import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  VStack,
  HStack,
  Text,
  Card,
  CardBody,
  SimpleGrid,
  Image,
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
  ModalCloseButton,
  useDisclosure,
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
} from '@chakra-ui/react';
import {
  MagnifyingGlassIcon,
  EyeIcon,
  HeartIcon,
  ChatBubbleLeftIcon,
  PlayIcon,
  UserGroupIcon,
  ClockIcon,
  FunnelIcon,
  StarIcon,
  EllipsisVerticalIcon,
  ShareIcon,
  BookmarkIcon,
} from '@heroicons/react/24/outline';
import { useAuth } from '@streaming/auth';
import { useGlobalStore } from '@streaming/shared';

interface StreamData {
  id: string;
  title: string;
  description: string;
  thumbnail: string;
  streamerName: string;
  streamerAvatar: string;
  category: string;
  viewers: number;
  isLive: boolean;
  startTime: Date;
  duration: number;
  tags: string[];
  quality: '720p' | '1080p' | '4K';
  subscriptionTier: 'free' | 'silver' | 'gold' | 'platinum';
  language: string;
  rating: number;
  chatEnabled: boolean;
  recordingAvailable: boolean;
}

interface StreamFilters {
  category: string;
  quality: string;
  subscriptionTier: string;
  language: string;
  sortBy: string;
}

const CATEGORIES = [
  'All Categories',
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

const LANGUAGES = [
  'All Languages',
  'English',
  'Spanish',
  'French',
  'German',
  'Japanese',
  'Korean',
  'Portuguese',
  'Russian',
  'Chinese',
];

const SORT_OPTIONS = [
  { value: 'viewers', label: 'Most Viewers' },
  { value: 'recent', label: 'Recently Started' },
  { value: 'rating', label: 'Highest Rated' },
  { value: 'title', label: 'Title A-Z' },
];

export const StreamBrowser: React.FC = () => {
  const { user, hasSubscription } = useAuth();
  const { addNotification } = useGlobalStore();
  const toast = useToast();
  const { isOpen: isStreamModalOpen, onOpen: openStreamModal, onClose: closeStreamModal } = useDisclosure();
  
  const [searchQuery, setSearchQuery] = useState('');
  const [filters, setFilters] = useState<StreamFilters>({
    category: 'All Categories',
    quality: 'All Qualities',
    subscriptionTier: 'All Tiers',
    language: 'All Languages',
    sortBy: 'viewers',
  });
  
  const [selectedStream, setSelectedStream] = useState<StreamData | null>(null);
  const [loading, setLoading] = useState(false);
  const [favoriteStreams, setFavoriteStreams] = useState<Set<string>>(new Set());
  
  const [streams, setStreams] = useState<StreamData[]>([
    {
      id: '1',
      title: 'Epic Gaming Marathon - New Game Release!',
      description: 'Join me for an epic gaming session with the latest AAA release. Viewer challenges and giveaways!',
      thumbnail: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=400',
      streamerName: 'ProGamer123',
      streamerAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
      category: 'Gaming',
      viewers: 2847,
      isLive: true,
      startTime: new Date(Date.now() - 2 * 60 * 60 * 1000),
      duration: 7200,
      tags: ['gaming', 'new release', 'giveaway'],
      quality: '1080p',
      subscriptionTier: 'free',
      language: 'English',
      rating: 4.8,
      chatEnabled: true,
      recordingAvailable: true,
    },
    {
      id: '2',
      title: 'Live Music Performance - Acoustic Session',
      description: 'Intimate acoustic performance with original songs and covers. Taking requests!',
      thumbnail: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400',
      streamerName: 'MusicMaven',
      streamerAvatar: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100',
      category: 'Music',
      viewers: 1234,
      isLive: true,
      startTime: new Date(Date.now() - 1 * 60 * 60 * 1000),
      duration: 3600,
      tags: ['music', 'acoustic', 'live'],
      quality: '1080p',
      subscriptionTier: 'silver',
      language: 'English',
      rating: 4.9,
      chatEnabled: true,
      recordingAvailable: false,
    },
    {
      id: '3',
      title: 'Tech Talk: AI and Machine Learning Trends',
      description: 'Deep dive into the latest AI developments and their impact on various industries.',
      thumbnail: 'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=400',
      streamerName: 'TechGuru',
      streamerAvatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
      category: 'Technology',
      viewers: 892,
      isLive: true,
      startTime: new Date(Date.now() - 30 * 60 * 1000),
      duration: 1800,
      tags: ['tech', 'AI', 'education'],
      quality: '4K',
      subscriptionTier: 'gold',
      language: 'English',
      rating: 4.7,
      chatEnabled: true,
      recordingAvailable: true,
    },
    {
      id: '4',
      title: 'Cooking Masterclass: Italian Cuisine',
      description: 'Learn to make authentic Italian pasta from scratch with professional chef techniques.',
      thumbnail: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400',
      streamerName: 'ChefMario',
      streamerAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
      category: 'Lifestyle',
      viewers: 567,
      isLive: true,
      startTime: new Date(Date.now() - 45 * 60 * 1000),
      duration: 2700,
      tags: ['cooking', 'italian', 'masterclass'],
      quality: '1080p',
      subscriptionTier: 'silver',
      language: 'English',
      rating: 4.6,
      chatEnabled: true,
      recordingAvailable: true,
    },
  ]);

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const cardBg = useColorModeValue('purple.50', 'purple.900');
  const purpleColor = useColorModeValue('purple.600', 'purple.300');

  // Filter and sort streams
  const filteredStreams = streams.filter(stream => {
    const matchesSearch = stream.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         stream.streamerName.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         stream.tags.some(tag => tag.toLowerCase().includes(searchQuery.toLowerCase()));
    
    const matchesCategory = filters.category === 'All Categories' || stream.category === filters.category;
    const matchesQuality = filters.quality === 'All Qualities' || stream.quality === filters.quality;
    const matchesTier = filters.subscriptionTier === 'All Tiers' || stream.subscriptionTier === filters.subscriptionTier;
    const matchesLanguage = filters.language === 'All Languages' || stream.language === filters.language;
    
    return matchesSearch && matchesCategory && matchesQuality && matchesTier && matchesLanguage;
  });

  const sortedStreams = [...filteredStreams].sort((a, b) => {
    switch (filters.sortBy) {
      case 'viewers':
        return b.viewers - a.viewers;
      case 'recent':
        return b.startTime.getTime() - a.startTime.getTime();
      case 'rating':
        return b.rating - a.rating;
      case 'title':
        return a.title.localeCompare(b.title);
      default:
        return 0;
    }
  });

  const canWatchStream = (stream: StreamData) => {
    switch (stream.subscriptionTier) {
      case 'free':
        return true;
      case 'silver':
        return hasSubscription('silver');
      case 'gold':
        return hasSubscription('gold');
      case 'platinum':
        return hasSubscription('platinum');
      default:
        return false;
    }
  };

  const handleWatchStream = (stream: StreamData) => {
    if (!canWatchStream(stream)) {
      toast({
        title: 'Subscription Required',
        description: `This stream requires ${stream.subscriptionTier} tier or higher`,
        status: 'warning',
        duration: 5000,
      });
      return;
    }
    
    setSelectedStream(stream);
    openStreamModal();
    
    addNotification({
      type: 'info',
      title: 'Stream Starting',
      message: `Now watching: ${stream.title}`,
    });
  };

  const toggleFavorite = (streamId: string) => {
    setFavoriteStreams(prev => {
      const newFavorites = new Set(prev);
      if (newFavorites.has(streamId)) {
        newFavorites.delete(streamId);
        toast({
          title: 'Removed from Favorites',
          status: 'info',
          duration: 2000,
        });
      } else {
        newFavorites.add(streamId);
        toast({
          title: 'Added to Favorites',
          status: 'success',
          duration: 2000,
        });
      }
      return newFavorites;
    });
  };

  const shareStream = (stream: StreamData) => {
    const shareUrl = `${window.location.origin}/stream/${stream.id}`;
    navigator.clipboard.writeText(shareUrl).then(() => {
      toast({
        title: 'Link Copied',
        description: 'Stream link copied to clipboard',
        status: 'success',
        duration: 2000,
      });
    });
  };

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  };

  const formatViewers = (count: number) => {
    if (count >= 1000) {
      return (count / 1000).toFixed(1) + 'K';
    }
    return count.toString();
  };

  const getTierColor = (tier: string) => {
    switch (tier) {
      case 'free': return 'green';
      case 'silver': return 'gray';
      case 'gold': return 'yellow';
      case 'platinum': return 'purple';
      default: return 'gray';
    }
  };

  const getTierIcon = (tier: string) => {
    switch (tier) {
      case 'gold':
      case 'platinum':
        return <StarIcon width="12px" />;
      default:
        return null;
    }
  };

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        {/* Header */}
        <HStack justify="space-between">
          <VStack align="start" spacing={1}>
            <Text fontSize="2xl" fontWeight="bold" color={purpleColor}>
              Live Streams
            </Text>
            <Text fontSize="sm" color="gray.500">
              {sortedStreams.length} streams available
            </Text>
          </VStack>
          
          <HStack spacing={3}>
            <Text fontSize="sm" color="gray.500">
              Your tier: <Badge colorScheme={getTierColor(user?.subscriptionTier || 'free')}>
                {user?.subscriptionTier || 'free'}
              </Badge>
            </Text>
          </HStack>
        </HStack>

        {/* Search and Filters */}
        <Card bg={bg} border="1px" borderColor={borderColor}>
          <CardBody>
            <VStack spacing={4} align="stretch">
              <InputGroup>
                <InputLeftElement>
                  <MagnifyingGlassIcon width="16px" />
                </InputLeftElement>
                <Input
                  placeholder="Search streams, streamers, or tags..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </InputGroup>
              
              <HStack spacing={4} wrap="wrap">
                <Select
                  value={filters.category}
                  onChange={(e) => setFilters(prev => ({ ...prev, category: e.target.value }))}
                  maxW="200px"
                >
                  {CATEGORIES.map(category => (
                    <option key={category} value={category}>
                      {category}
                    </option>
                  ))}
                </Select>
                
                <Select
                  value={filters.quality}
                  onChange={(e) => setFilters(prev => ({ ...prev, quality: e.target.value }))}
                  maxW="150px"
                >
                  <option value="All Qualities">All Qualities</option>
                  <option value="720p">720p HD</option>
                  <option value="1080p">1080p Full HD</option>
                  <option value="4K">4K Ultra HD</option>
                </Select>
                
                <Select
                  value={filters.subscriptionTier}
                  onChange={(e) => setFilters(prev => ({ ...prev, subscriptionTier: e.target.value }))}
                  maxW="150px"
                >
                  <option value="All Tiers">All Tiers</option>
                  <option value="free">Free</option>
                  <option value="silver">Silver+</option>
                  <option value="gold">Gold+</option>
                  <option value="platinum">Platinum</option>
                </Select>
                
                <Select
                  value={filters.language}
                  onChange={(e) => setFilters(prev => ({ ...prev, language: e.target.value }))}
                  maxW="150px"
                >
                  {LANGUAGES.map(language => (
                    <option key={language} value={language}>
                      {language}
                    </option>
                  ))}
                </Select>
                
                <Select
                  value={filters.sortBy}
                  onChange={(e) => setFilters(prev => ({ ...prev, sortBy: e.target.value }))}
                  maxW="150px"
                >
                  {SORT_OPTIONS.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </Select>
              </HStack>
            </VStack>
          </CardBody>
        </Card>

        {/* Stream Grid */}
        <SimpleGrid columns={{ base: 1, md: 2, lg: 3, xl: 4 }} spacing={6}>
          {sortedStreams.map((stream) => {
            const canWatch = canWatchStream(stream);
            const isFavorite = favoriteStreams.has(stream.id);
            
            return (
              <Card
                key={stream.id}
                bg={canWatch ? bg : 'gray.100'}
                border="1px"
                borderColor={borderColor}
                opacity={canWatch ? 1 : 0.7}
                transition="all 0.2s"
                _hover={{ transform: 'translateY(-2px)', shadow: 'lg' }}
              >
                <CardBody p={0}>
                  <VStack spacing={0} align="stretch">
                    {/* Thumbnail */}
                    <Box position="relative">
                      <Image
                        src={stream.thumbnail}
                        alt={stream.title}
                        h="200px"
                        w="100%"
                        objectFit="cover"
                        borderTopRadius="md"
                      />
                      
                      {/* Live Badge */}
                      {stream.isLive && (
                        <Badge
                          position="absolute"
                          top={2}
                          left={2}
                          colorScheme="red"
                          variant="solid"
                        >
                          <HStack spacing={1}>
                            <Box w={2} h={2} bg="white" borderRadius="full" />
                            <Text>LIVE</Text>
                          </HStack>
                        </Badge>
                      )}
                      
                      {/* Quality Badge */}
                      <Badge
                        position="absolute"
                        top={2}
                        right={2}
                        colorScheme="blue"
                        variant="solid"
                      >
                        {stream.quality}
                      </Badge>
                      
                      {/* Duration */}
                      <Badge
                        position="absolute"
                        bottom={2}
                        right={2}
                        bg="blackAlpha.700"
                        color="white"
                      >
                        {formatDuration(stream.duration)}
                      </Badge>
                      
                      {/* Subscription Tier */}
                      {stream.subscriptionTier !== 'free' && (
                        <Badge
                          position="absolute"
                          bottom={2}
                          left={2}
                          colorScheme={getTierColor(stream.subscriptionTier)}
                          variant="solid"
                        >
                          <HStack spacing={1}>
                            {getTierIcon(stream.subscriptionTier)}
                            <Text>{stream.subscriptionTier.toUpperCase()}</Text>
                          </HStack>
                        </Badge>
                      )}
                      
                      {/* Action Menu */}
                      <Menu>
                        <MenuButton
                          as={IconButton}
                          icon={<EllipsisVerticalIcon width="16px" />}
                          variant="ghost"
                          size="sm"
                          position="absolute"
                          top={2}
                          right={10}
                          bg="blackAlpha.600"
                          color="white"
                          _hover={{ bg: 'blackAlpha.800' }}
                        />
                        <MenuList>
                          <MenuItem
                            icon={<BookmarkIcon width="16px" />}
                            onClick={() => toggleFavorite(stream.id)}
                          >
                            {isFavorite ? 'Remove from Favorites' : 'Add to Favorites'}
                          </MenuItem>
                          <MenuItem
                            icon={<ShareIcon width="16px" />}
                            onClick={() => shareStream(stream)}
                          >
                            Share Stream
                          </MenuItem>
                        </MenuList>
                      </Menu>
                    </Box>

                    {/* Stream Info */}
                    <VStack spacing={3} align="stretch" p={4}>
                      <VStack spacing={2} align="stretch">
                        <Text fontWeight="bold" fontSize="md" noOfLines={2}>
                          {stream.title}
                        </Text>
                        
                        <HStack spacing={2}>
                          <Avatar size="xs" src={stream.streamerAvatar} />
                          <Text fontSize="sm" color="gray.500">
                            {stream.streamerName}
                          </Text>
                        </HStack>
                        
                        <Text fontSize="sm" color="gray.500" noOfLines={2}>
                          {stream.description}
                        </Text>
                      </VStack>

                      {/* Stats */}
                      <HStack justify="space-between" fontSize="sm" color="gray.500">
                        <HStack>
                          <EyeIcon width="16px" />
                          <Text>{formatViewers(stream.viewers)}</Text>
                        </HStack>
                        
                        <HStack>
                          <StarIcon width="16px" />
                          <Text>{stream.rating}</Text>
                        </HStack>
                        
                        <Badge colorScheme="purple" variant="outline">
                          {stream.category}
                        </Badge>
                      </HStack>

                      {/* Tags */}
                      <HStack spacing={1} wrap="wrap">
                        {stream.tags.slice(0, 3).map((tag, index) => (
                          <Badge key={index} size="sm" variant="subtle" colorScheme="gray">
                            {tag}
                          </Badge>
                        ))}
                      </HStack>

                      {/* Watch Button */}
                      <Button
                        leftIcon={<PlayIcon width="16px" />}
                        colorScheme="purple"
                        size="sm"
                        onClick={() => handleWatchStream(stream)}
                        isDisabled={!canWatch}
                      >
                        {canWatch ? 'Watch Now' : `${stream.subscriptionTier} Required`}
                      </Button>
                    </VStack>
                  </VStack>
                </CardBody>
              </Card>
            );
          })}
        </SimpleGrid>

        {/* No Results */}
        {sortedStreams.length === 0 && (
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardBody textAlign="center" py={8}>
              <Text color="gray.500">No streams found matching your criteria</Text>
            </CardBody>
          </Card>
        )}

        {/* Stream Modal */}
        <Modal isOpen={isStreamModalOpen} onClose={closeStreamModal} size="6xl">
          <ModalOverlay />
          <ModalContent>
            <ModalHeader color={purpleColor}>
              {selectedStream?.title}
            </ModalHeader>
            <ModalCloseButton />
            <ModalBody pb={6}>
              {selectedStream && (
                <VStack spacing={4} align="stretch">
                  <Alert status="info" borderRadius="md">
                    <AlertIcon />
                    <AlertDescription>
                      Stream player would be integrated here with HLS.js or similar video player.
                      Playback URL: {selectedStream.id}.m3u8
                    </AlertDescription>
                  </Alert>
                  
                  <Box bg="black" h="400px" borderRadius="md" display="flex" alignItems="center" justifyContent="center">
                    <VStack spacing={4} color="white" textAlign="center">
                      <PlayIcon width="64px" />
                      <Text fontSize="lg">Video Player Placeholder</Text>
                      <Text fontSize="sm" opacity={0.7}>
                        Real implementation would use HLS.js or Video.js
                      </Text>
                    </VStack>
                  </Box>
                  
                  <HStack justify="space-between">
                    <VStack align="start" spacing={1}>
                      <Text fontWeight="bold">{selectedStream.streamerName}</Text>
                      <Text fontSize="sm" color="gray.500">{selectedStream.category}</Text>
                    </VStack>
                    
                    <HStack spacing={4}>
                      <Stat textAlign="center">
                        <StatLabel>Viewers</StatLabel>
                        <StatNumber fontSize="lg">{formatViewers(selectedStream.viewers)}</StatNumber>
                      </Stat>
                      
                      <Stat textAlign="center">
                        <StatLabel>Duration</StatLabel>
                        <StatNumber fontSize="lg">{formatDuration(selectedStream.duration)}</StatNumber>
                      </Stat>
                      
                      <Stat textAlign="center">
                        <StatLabel>Rating</StatLabel>
                        <StatNumber fontSize="lg">{selectedStream.rating}</StatNumber>
                      </Stat>
                    </HStack>
                  </HStack>
                </VStack>
              )}
            </ModalBody>
          </ModalContent>
        </Modal>
      </VStack>
    </Box>
  );
};