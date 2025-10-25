import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  VStack,
  HStack,
  Text,
  Button,
  Card,
  CardBody,
  CardHeader,
  SimpleGrid,
  Badge,
  Alert,
  AlertIcon,
  AlertDescription,
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
  Input,
  Select,
  Textarea,
  Switch,
  Divider,
  Progress,
  Stat,
  StatLabel,
  StatNumber,
  StatHelpText,
  IconButton,
  Tooltip,
  Code,
  InputGroup,
  InputRightElement,
} from '@chakra-ui/react';
import {
  PlayIcon,
  StopIcon,
  PauseIcon,
  Cog6ToothIcon,
  SignalIcon,
  VideoCameraIcon,
  MicrophoneIcon,
  SpeakerWaveIcon,
  EyeIcon,
  ClockIcon,
  DocumentDuplicateIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon,
} from '@heroicons/react/24/outline';
import { useAuth } from '../../stubs/auth';
import { useGlobalStore } from '../../stubs/shared';

interface StreamConfig {
  title: string;
  description: string;
  category: string;
  tags: string[];
  visibility: 'public' | 'unlisted' | 'private';
  quality: '720p' | '1080p' | '4K';
  bitrate: number;
  framerate: 30 | 60;
  enableChat: boolean;
  enableRecording: boolean;
  scheduledStart?: Date;
}

interface StreamStatus {
  isLive: boolean;
  isPaused: boolean;
  isRecording: boolean;
  startTime?: Date;
  duration: number;
  viewers: number;
  peakViewers: number;
  chatMessages: number;
  streamKey: string;
  ingestUrl: string;
  playbackUrl: string;
  channelId: string;
  channelArn: string;
}

interface StreamMetrics {
  currentBitrate: number;
  currentFramerate: number;
  droppedFrames: number;
  networkHealth: number;
  cpuUsage: number;
  memoryUsage: number;
}

const STREAM_CATEGORIES = [
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

const QUALITY_PRESETS = {
  '720p': { width: 1280, height: 720, bitrate: 3000 },
  '1080p': { width: 1920, height: 1080, bitrate: 5000 },
  '4K': { width: 3840, height: 2160, bitrate: 15000 },
};

export const StreamControls: React.FC = () => {
  const { user } = useAuth();
  const { addNotification } = useGlobalStore();
  const toast = useToast();
  const { isOpen: isConfigModalOpen, onOpen: openConfigModal, onClose: closeConfigModal } = useDisclosure();
  
  const [streamConfig, setStreamConfig] = useState<StreamConfig>({
    title: '',
    description: '',
    category: 'Gaming',
    tags: [],
    visibility: 'public',
    quality: '1080p',
    bitrate: 5000,
    framerate: 30,
    enableChat: true,
    enableRecording: true,
  });
  
  const [streamStatus, setStreamStatus] = useState<StreamStatus>({
    isLive: false,
    isPaused: false,
    isRecording: false,
    duration: 0,
    viewers: 0,
    peakViewers: 0,
    chatMessages: 0,
    streamKey: 'sk_live_' + Math.random().toString(36).substr(2, 16),
    ingestUrl: 'rtmps://ingest.medialive.eu-west-2.amazonaws.com/live',
    playbackUrl: 'https://d1234567890.cloudfront.net/live/stream.m3u8',
    channelId: 'ch_' + Math.random().toString(36).substr(2, 8),
    channelArn: 'arn:aws:medialive:eu-west-2:123456789012:channel:1234567',
  });
  
  const [streamMetrics, setStreamMetrics] = useState<StreamMetrics>({
    currentBitrate: 0,
    currentFramerate: 0,
    droppedFrames: 0,
    networkHealth: 100,
    cpuUsage: 45,
    memoryUsage: 62,
  });
  
  const [loading, setLoading] = useState(false);
  const [showStreamKey, setShowStreamKey] = useState(false);

  const bg = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const cardBg = useColorModeValue('purple.50', 'purple.900');
  const purpleColor = useColorModeValue('purple.600', 'purple.300');

  // Update stream duration and metrics
  useEffect(() => {
    if (!streamStatus.isLive) return;
    
    const interval = setInterval(() => {
      setStreamStatus(prev => ({
        ...prev,
        duration: prev.startTime ? Date.now() - prev.startTime.getTime() : 0,
        viewers: Math.max(0, prev.viewers + Math.floor(Math.random() * 3) - 1),
        chatMessages: prev.chatMessages + Math.floor(Math.random() * 2),
      }));
      
      setStreamMetrics(prev => ({
        ...prev,
        currentBitrate: streamConfig.bitrate + Math.floor(Math.random() * 200) - 100,
        currentFramerate: streamConfig.framerate + Math.random() * 2 - 1,
        droppedFrames: Math.max(0, prev.droppedFrames + Math.random() * 0.1 - 0.05),
        networkHealth: Math.max(90, Math.min(100, prev.networkHealth + Math.random() * 2 - 1)),
        cpuUsage: Math.max(20, Math.min(90, prev.cpuUsage + Math.random() * 4 - 2)),
        memoryUsage: Math.max(40, Math.min(85, prev.memoryUsage + Math.random() * 2 - 1)),
      }));
    }, 2000);
    
    return () => clearInterval(interval);
  }, [streamStatus.isLive, streamConfig.bitrate, streamConfig.framerate]);

  const startStream = async () => {
    if (!streamConfig.title.trim()) {
      toast({
        title: 'Stream Title Required',
        description: 'Please set a title for your stream before starting.',
        status: 'warning',
        duration: 5000,
      });
      openConfigModal();
      return;
    }
    
    setLoading(true);
    try {
      // Simulate MediaLive channel creation and start
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      setStreamStatus(prev => ({
        ...prev,
        isLive: true,
        isPaused: false,
        startTime: new Date(),
        duration: 0,
        viewers: 1,
        peakViewers: 1,
        chatMessages: 0,
      }));
      
      setStreamMetrics(prev => ({
        ...prev,
        currentBitrate: streamConfig.bitrate,
        currentFramerate: streamConfig.framerate,
        droppedFrames: 0,
      }));
      
      addNotification({
        type: 'success',
        title: 'Stream Started',
        message: 'Your stream is now live!',
      });
      
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.info('Stream started', { 
          component: 'StreamControls',
          channelId: streamStatus.channelId,
          title: streamConfig.title 
        });
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error starting stream', error, { 
          component: 'StreamControls',
          action: 'startStream' 
        });
      });
      toast({
        title: 'Stream Start Failed',
        description: 'Unable to start stream. Please check your configuration and try again.',
        status: 'error',
        duration: 5000,
      });
    } finally {
      setLoading(false);
    }
  };

  const stopStream = async () => {
    setLoading(true);
    try {
      // Simulate MediaLive channel stop
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      setStreamStatus(prev => ({
        ...prev,
        isLive: false,
        isPaused: false,
        isRecording: false,
        peakViewers: Math.max(prev.peakViewers, prev.viewers),
      }));
      
      setStreamMetrics(prev => ({
        ...prev,
        currentBitrate: 0,
        currentFramerate: 0,
      }));
      
      addNotification({
        type: 'info',
        title: 'Stream Ended',
        message: `Stream ended after ${formatDuration(streamStatus.duration)}`,
      });
      
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.info('Stream stopped', { 
          component: 'StreamControls',
          channelId: streamStatus.channelId,
          duration: streamStatus.duration,
          peakViewers: streamStatus.peakViewers 
        });
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error stopping stream', error, { 
          component: 'StreamControls',
          action: 'stopStream' 
        });
      });
      toast({
        title: 'Stream Stop Failed',
        description: 'Unable to stop stream. Please try again.',
        status: 'error',
        duration: 5000,
      });
    } finally {
      setLoading(false);
    }
  };

  const pauseStream = async () => {
    setLoading(true);
    try {
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      setStreamStatus(prev => ({
        ...prev,
        isPaused: !prev.isPaused,
      }));
      
      addNotification({
        type: 'info',
        title: streamStatus.isPaused ? 'Stream Resumed' : 'Stream Paused',
        message: streamStatus.isPaused ? 'Your stream is now live again' : 'Your stream is paused',
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error pausing/resuming stream', error, { 
          component: 'StreamControls',
          action: 'pauseStream' 
        });
      });
    } finally {
      setLoading(false);
    }
  };

  const toggleRecording = async () => {
    setLoading(true);
    try {
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      setStreamStatus(prev => ({
        ...prev,
        isRecording: !prev.isRecording,
      }));
      
      addNotification({
        type: 'info',
        title: streamStatus.isRecording ? 'Recording Stopped' : 'Recording Started',
        message: streamStatus.isRecording ? 'Stream recording has been stopped' : 'Stream recording has been started',
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error toggling recording', error, { 
          component: 'StreamControls',
          action: 'toggleRecording' 
        });
      });
    } finally {
      setLoading(false);
    }
  };

  const saveStreamConfig = async () => {
    setLoading(true);
    try {
      // Simulate API call to update MediaLive channel configuration
      await new Promise(resolve => setTimeout(resolve, 1500));
      
      // Update bitrate in metrics if stream is live
      if (streamStatus.isLive) {
        setStreamMetrics(prev => ({
          ...prev,
          currentBitrate: streamConfig.bitrate,
          currentFramerate: streamConfig.framerate,
        }));
      }
      
      closeConfigModal();
      
      addNotification({
        type: 'success',
        title: 'Configuration Saved',
        message: 'Stream configuration has been updated',
      });
    } catch (error) {
      // Use secure logging to prevent log injection
      import('../../stubs/shared').then(({ secureLogger }) => {
        secureLogger.error('Error saving stream config', error, { 
          component: 'StreamControls',
          action: 'saveConfig' 
        });
      });
      toast({
        title: 'Save Failed',
        description: 'Unable to save configuration. Please try again.',
        status: 'error',
        duration: 5000,
      });
    } finally {
      setLoading(false);
    }
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text).then(() => {
      toast({
        title: 'Copied!',
        description: `${label} copied to clipboard`,
        status: 'success',
        duration: 2000,
      });
    });
  };

  const formatDuration = (ms: number) => {
    const seconds = Math.floor(ms / 1000);
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  };

  const getHealthColor = (value: number, thresholds: { good: number; warning: number }) => {
    if (value >= thresholds.good) return 'green';
    if (value >= thresholds.warning) return 'yellow';
    return 'red';
  };

  return (
    <Box>
      <VStack spacing={6} align="stretch">
        {/* Stream Status Header */}
        <Card bg={cardBg} border="2px" borderColor={purpleColor}>
          <CardHeader>
            <HStack justify="space-between">
              <HStack spacing={4}>
                <Box>
                  {streamStatus.isLive ? (
                    <Badge colorScheme="red" variant="solid" fontSize="lg" px={4} py={2}>
                      <HStack spacing={2}>
                        <Box w={2} h={2} bg="white" borderRadius="full" />
                        <Text>LIVE</Text>
                      </HStack>
                    </Badge>
                  ) : (
                    <Badge colorScheme="gray" variant="solid" fontSize="lg" px={4} py={2}>
                      OFFLINE
                    </Badge>
                  )}
                </Box>
                
                {streamStatus.isLive && (
                  <VStack spacing={1} align="start">
                    <Text fontSize="sm" color="gray.600">Duration</Text>
                    <Text fontSize="lg" fontWeight="bold" color={purpleColor}>
                      {formatDuration(streamStatus.duration)}
                    </Text>
                  </VStack>
                )}
              </HStack>
              
              <HStack spacing={2}>
                <Button
                  leftIcon={<Cog6ToothIcon width="16px" />}
                  variant="outline"
                  colorScheme="purple"
                  onClick={openConfigModal}
                  isDisabled={loading}
                >
                  Configure
                </Button>
                
                {!streamStatus.isLive ? (
                  <Button
                    leftIcon={<PlayIcon width="16px" />}
                    colorScheme="purple"
                    size="lg"
                    onClick={startStream}
                    isLoading={loading}
                    loadingText="Starting..."
                  >
                    Start Stream
                  </Button>
                ) : (
                  <HStack spacing={2}>
                    <Button
                      leftIcon={streamStatus.isPaused ? <PlayIcon width="16px" /> : <PauseIcon width="16px" />}
                      colorScheme="yellow"
                      onClick={pauseStream}
                      isLoading={loading}
                    >
                      {streamStatus.isPaused ? 'Resume' : 'Pause'}
                    </Button>
                    
                    <Button
                      leftIcon={<StopIcon width="16px" />}
                      colorScheme="red"
                      onClick={stopStream}
                      isLoading={loading}
                      loadingText="Stopping..."
                    >
                      Stop Stream
                    </Button>
                  </HStack>
                )}
              </HStack>
            </HStack>
          </CardHeader>
        </Card>

        {/* Stream Info and Metrics */}
        {streamStatus.isLive && (
          <SimpleGrid columns={{ base: 2, md: 4 }} spacing={4}>
            <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
              <StatLabel>Current Viewers</StatLabel>
              <StatNumber color={purpleColor}>{streamStatus.viewers}</StatNumber>
              <StatHelpText>Peak: {streamStatus.peakViewers}</StatHelpText>
            </Stat>

            <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
              <StatLabel>Chat Messages</StatLabel>
              <StatNumber color={purpleColor}>{streamStatus.chatMessages}</StatNumber>
              <StatHelpText>Total messages</StatHelpText>
            </Stat>

            <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
              <StatLabel>Bitrate</StatLabel>
              <StatNumber color={purpleColor}>{streamMetrics.currentBitrate.toFixed(0)} kbps</StatNumber>
              <StatHelpText>Target: {streamConfig.bitrate} kbps</StatHelpText>
            </Stat>

            <Stat bg={bg} p={4} borderRadius="md" border="1px" borderColor={borderColor}>
              <StatLabel>Framerate</StatLabel>
              <StatNumber color={purpleColor}>{streamMetrics.currentFramerate.toFixed(1)} fps</StatNumber>
              <StatHelpText>Target: {streamConfig.framerate} fps</StatHelpText>
            </Stat>
          </SimpleGrid>
        )}

        {/* Stream Health */}
        {streamStatus.isLive && (
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack>
                <SignalIcon width="20px" color={purpleColor} />
                <Text fontWeight="bold" color={purpleColor}>Stream Health</Text>
              </HStack>
            </CardHeader>
            <CardBody>
              <SimpleGrid columns={{ base: 1, md: 3 }} spacing={6}>
                <VStack spacing={3} align="stretch">
                  <Text fontSize="sm" fontWeight="medium">Network Health</Text>
                  <Progress
                    value={streamMetrics.networkHealth}
                    colorScheme={getHealthColor(streamMetrics.networkHealth, { good: 95, warning: 85 })}
                    size="lg"
                  />
                  <Text fontSize="sm" color="gray.500">
                    {streamMetrics.networkHealth.toFixed(1)}% - {
                      streamMetrics.networkHealth >= 95 ? 'Excellent' :
                      streamMetrics.networkHealth >= 85 ? 'Good' : 'Poor'
                    }
                  </Text>
                </VStack>

                <VStack spacing={3} align="stretch">
                  <Text fontSize="sm" fontWeight="medium">CPU Usage</Text>
                  <Progress
                    value={streamMetrics.cpuUsage}
                    colorScheme={getHealthColor(100 - streamMetrics.cpuUsage, { good: 50, warning: 20 })}
                    size="lg"
                  />
                  <Text fontSize="sm" color="gray.500">
                    {streamMetrics.cpuUsage.toFixed(1)}% - {
                      streamMetrics.cpuUsage <= 50 ? 'Good' :
                      streamMetrics.cpuUsage <= 80 ? 'Moderate' : 'High'
                    }
                  </Text>
                </VStack>

                <VStack spacing={3} align="stretch">
                  <Text fontSize="sm" fontWeight="medium">Dropped Frames</Text>
                  <Progress
                    value={Math.min(100, streamMetrics.droppedFrames * 10)}
                    colorScheme={getHealthColor(100 - streamMetrics.droppedFrames * 10, { good: 95, warning: 80 })}
                    size="lg"
                  />
                  <Text fontSize="sm" color="gray.500">
                    {streamMetrics.droppedFrames.toFixed(2)}% - {
                      streamMetrics.droppedFrames <= 0.5 ? 'Excellent' :
                      streamMetrics.droppedFrames <= 2 ? 'Good' : 'Poor'
                    }
                  </Text>
                </VStack>
              </SimpleGrid>
            </CardBody>
          </Card>
        )}

        {/* Stream Configuration */}
        <SimpleGrid columns={{ base: 1, lg: 2 }} spacing={6}>
          {/* Current Configuration */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <Text fontWeight="bold" color={purpleColor}>Current Configuration</Text>
            </CardHeader>
            <CardBody>
              <VStack spacing={4} align="stretch">
                <Box>
                  <Text fontSize="sm" color="gray.500">Title</Text>
                  <Text fontWeight="medium">
                    {streamConfig.title || 'No title set'}
                  </Text>
                </Box>
                
                <Box>
                  <Text fontSize="sm" color="gray.500">Quality</Text>
                  <Text fontWeight="medium">
                    {streamConfig.quality} @ {streamConfig.bitrate} kbps, {streamConfig.framerate} fps
                  </Text>
                </Box>
                
                <Box>
                  <Text fontSize="sm" color="gray.500">Category</Text>
                  <Text fontWeight="medium">{streamConfig.category}</Text>
                </Box>
                
                <HStack spacing={4}>
                  <VStack spacing={1} align="start">
                    <Text fontSize="sm" color="gray.500">Chat</Text>
                    <Badge colorScheme={streamConfig.enableChat ? 'green' : 'red'}>
                      {streamConfig.enableChat ? 'Enabled' : 'Disabled'}
                    </Badge>
                  </VStack>
                  
                  <VStack spacing={1} align="start">
                    <Text fontSize="sm" color="gray.500">Recording</Text>
                    <Badge colorScheme={streamConfig.enableRecording ? 'green' : 'red'}>
                      {streamConfig.enableRecording ? 'Enabled' : 'Disabled'}
                    </Badge>
                  </VStack>
                </HStack>
              </VStack>
            </CardBody>
          </Card>

          {/* Stream URLs */}
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <Text fontWeight="bold" color={purpleColor}>Stream URLs</Text>
            </CardHeader>
            <CardBody>
              <VStack spacing={4} align="stretch">
                <Box>
                  <Text fontSize="sm" color="gray.500" mb={2}>Ingest URL</Text>
                  <InputGroup>
                    <Input
                      value={streamStatus.ingestUrl}
                      isReadOnly
                      fontSize="sm"
                      fontFamily="mono"
                    />
                    <InputRightElement>
                      <IconButton
                        aria-label="Copy ingest URL"
                        icon={<DocumentDuplicateIcon width="16px" />}
                        size="sm"
                        variant="ghost"
                        onClick={() => copyToClipboard(streamStatus.ingestUrl, 'Ingest URL')}
                      />
                    </InputRightElement>
                  </InputGroup>
                </Box>
                
                <Box>
                  <Text fontSize="sm" color="gray.500" mb={2}>Stream Key</Text>
                  <InputGroup>
                    <Input
                      value={showStreamKey ? streamStatus.streamKey : '••••••••••••••••'}
                      isReadOnly
                      fontSize="sm"
                      fontFamily="mono"
                    />
                    <InputRightElement>
                      <HStack spacing={1}>
                        <IconButton
                          aria-label="Toggle stream key visibility"
                          icon={<EyeIcon width="16px" />}
                          size="sm"
                          variant="ghost"
                          onClick={() => setShowStreamKey(!showStreamKey)}
                        />
                        <IconButton
                          aria-label="Copy stream key"
                          icon={<DocumentDuplicateIcon width="16px" />}
                          size="sm"
                          variant="ghost"
                          onClick={() => copyToClipboard(streamStatus.streamKey, 'Stream Key')}
                        />
                      </HStack>
                    </InputRightElement>
                  </InputGroup>
                </Box>
                
                <Box>
                  <Text fontSize="sm" color="gray.500" mb={2}>Playback URL</Text>
                  <InputGroup>
                    <Input
                      value={streamStatus.playbackUrl}
                      isReadOnly
                      fontSize="sm"
                      fontFamily="mono"
                    />
                    <InputRightElement>
                      <IconButton
                        aria-label="Copy playback URL"
                        icon={<DocumentDuplicateIcon width="16px" />}
                        size="sm"
                        variant="ghost"
                        onClick={() => copyToClipboard(streamStatus.playbackUrl, 'Playback URL')}
                      />
                    </InputRightElement>
                  </InputGroup>
                </Box>
              </VStack>
            </CardBody>
          </Card>
        </SimpleGrid>

        {/* Recording Controls */}
        {streamStatus.isLive && streamConfig.enableRecording && (
          <Card bg={bg} border="1px" borderColor={borderColor}>
            <CardHeader>
              <HStack justify="space-between">
                <Text fontWeight="bold" color={purpleColor}>Recording</Text>
                <Button
                  leftIcon={streamStatus.isRecording ? <StopIcon width="16px" /> : <VideoCameraIcon width="16px" />}
                  colorScheme={streamStatus.isRecording ? 'red' : 'purple'}
                  variant={streamStatus.isRecording ? 'solid' : 'outline'}
                  onClick={toggleRecording}
                  isLoading={loading}
                >
                  {streamStatus.isRecording ? 'Stop Recording' : 'Start Recording'}
                </Button>
              </HStack>
            </CardHeader>
            {streamStatus.isRecording && (
              <CardBody>
                <Alert status="info" borderRadius="md">
                  <AlertIcon />
                  <AlertDescription>
                    Recording in progress. The recorded stream will be available in your content library after the stream ends.
                  </AlertDescription>
                </Alert>
              </CardBody>
            )}
          </Card>
        )}

        {/* Configuration Modal */}
        <Modal isOpen={isConfigModalOpen} onClose={closeConfigModal} size="xl">
          <ModalOverlay />
          <ModalContent>
            <ModalHeader color={purpleColor}>Stream Configuration</ModalHeader>
            <ModalCloseButton />
            <ModalBody>
              <VStack spacing={6} align="stretch">
                <FormControl isRequired>
                  <FormLabel>Stream Title</FormLabel>
                  <Input
                    value={streamConfig.title}
                    onChange={(e) => setStreamConfig(prev => ({ ...prev, title: e.target.value }))}
                    placeholder="Enter your stream title"
                  />
                </FormControl>
                
                <FormControl>
                  <FormLabel>Description</FormLabel>
                  <Textarea
                    value={streamConfig.description}
                    onChange={(e) => setStreamConfig(prev => ({ ...prev, description: e.target.value }))}
                    placeholder="Describe your stream content"
                    rows={3}
                  />
                </FormControl>
                
                <HStack spacing={4}>
                  <FormControl>
                    <FormLabel>Category</FormLabel>
                    <Select
                      value={streamConfig.category}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, category: e.target.value }))}
                    >
                      {STREAM_CATEGORIES.map(category => (
                        <option key={category} value={category}>
                          {category}
                        </option>
                      ))}
                    </Select>
                  </FormControl>
                  
                  <FormControl>
                    <FormLabel>Visibility</FormLabel>
                    <Select
                      value={streamConfig.visibility}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, visibility: e.target.value as any }))}
                    >
                      <option value="public">Public</option>
                      <option value="unlisted">Unlisted</option>
                      <option value="private">Private</option>
                    </Select>
                  </FormControl>
                </HStack>
                
                <Divider />
                
                <Text fontWeight="bold" color={purpleColor}>Quality Settings</Text>
                
                <HStack spacing={4}>
                  <FormControl>
                    <FormLabel>Quality Preset</FormLabel>
                    <Select
                      value={streamConfig.quality}
                      onChange={(e) => {
                        const quality = e.target.value as keyof typeof QUALITY_PRESETS;
                        setStreamConfig(prev => ({
                          ...prev,
                          quality,
                          bitrate: QUALITY_PRESETS[quality].bitrate,
                        }));
                      }}
                    >
                      <option value="720p">720p HD</option>
                      <option value="1080p">1080p Full HD</option>
                      <option value="4K">4K Ultra HD</option>
                    </Select>
                  </FormControl>
                  
                  <FormControl>
                    <FormLabel>Framerate</FormLabel>
                    <Select
                      value={streamConfig.framerate}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, framerate: parseInt(e.target.value) as any }))}
                    >
                      <option value={30}>30 FPS</option>
                      <option value={60}>60 FPS</option>
                    </Select>
                  </FormControl>
                </HStack>
                
                <FormControl>
                  <FormLabel>Bitrate (kbps)</FormLabel>
                  <Input
                    type="number"
                    value={streamConfig.bitrate}
                    onChange={(e) => setStreamConfig(prev => ({ ...prev, bitrate: parseInt(e.target.value) || 0 }))}
                    min={1000}
                    max={20000}
                  />
                </FormControl>
                
                <Divider />
                
                <Text fontWeight="bold" color={purpleColor}>Features</Text>
                
                <HStack spacing={8}>
                  <FormControl display="flex" alignItems="center">
                    <FormLabel mb={0}>Enable Chat</FormLabel>
                    <Switch
                      colorScheme="purple"
                      isChecked={streamConfig.enableChat}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, enableChat: e.target.checked }))}
                    />
                  </FormControl>
                  
                  <FormControl display="flex" alignItems="center">
                    <FormLabel mb={0}>Enable Recording</FormLabel>
                    <Switch
                      colorScheme="purple"
                      isChecked={streamConfig.enableRecording}
                      onChange={(e) => setStreamConfig(prev => ({ ...prev, enableRecording: e.target.checked }))}
                    />
                  </FormControl>
                </HStack>
              </VStack>
            </ModalBody>
            <ModalFooter>
              <Button variant="ghost" mr={3} onClick={closeConfigModal}>
                Cancel
              </Button>
              <Button
                colorScheme="purple"
                onClick={saveStreamConfig}
                isLoading={loading}
              >
                Save Configuration
              </Button>
            </ModalFooter>
          </ModalContent>
        </Modal>
      </VStack>
    </Box>
  );
};