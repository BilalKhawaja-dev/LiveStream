import React, { useState, useEffect } from 'react';
import {
    Box,
    VStack,
    HStack,
    Input,
    InputGroup,
    InputLeftElement,
    Button,
    Text,
    Badge,
    SimpleGrid,
    Card,
    CardBody,
    Image,
    Avatar,
    useColorModeValue,
    Spinner,
    Alert,
    AlertIcon,
    AlertDescription,
} from '@chakra-ui/react';
import {
    MagnifyingGlassIcon,
    FunnelIcon,
    ClockIcon,
    EyeIcon,
    HeartIcon,
} from '@heroicons/react/24/outline';
import { useGlobalStore } from '@streaming/shared';

interface ContentItem {
    id: string;
    title: string;
    description: string;
    thumbnail: string;
    duration: number;
    viewCount: number;
    likeCount: number;
    category: string;
    tags: string[];
    streamer: {
        id: string;
        username: string;
        avatar: string;
        verified: boolean;
    };
    createdAt: Date;
    isLive: boolean;
    quality: '720p' | '1080p' | '4K';
    language: string;
}

interface ContentSearchProps {
    onContentSelect?: (content: ContentItem) => void;
    initialQuery?: string;
    showFilters?: boolean;
}

const MOCK_CONTENT: ContentItem[] = [
    {
        id: '1',
        title: 'Epic Gaming Session - New RPG Adventure',
        description: 'Join me as I explore the latest RPG release with stunning 4K graphics and immersive gameplay.',
        thumbnail: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=400',
        duration: 7200,
        viewCount: 15420,
        likeCount: 892,
        category: 'Gaming',
        tags: ['RPG', 'Adventure', '4K', 'New Release'],
        streamer: {
            id: 'streamer1',
            username: 'GamerPro2024',
            avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
            verified: true,
        },
        createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
        isLive: true,
        quality: '4K',
        language: 'English',
    },
];

export const ContentSearch: React.FC<ContentSearchProps> = ({
    onContentSelect,
    initialQuery = '',
    showFilters = true,
}) => {
    const { addNotification } = useGlobalStore();

    const [query, setQuery] = useState(initialQuery);
    const [loading, setLoading] = useState(false);
    const [results, setResults] = useState<ContentItem[]>([]);

    const cardBg = useColorModeValue('gray.50', 'gray.700');

    useEffect(() => {
        if (query) {
            performSearch();
        } else {
            setResults(MOCK_CONTENT);
        }
    }, [query]);

    const performSearch = async () => {
        setLoading(true);
        try {
            // Simulate API call
            await new Promise(resolve => setTimeout(resolve, 500));

            let filteredResults = [...MOCK_CONTENT];

            // Apply text search
            if (query) {
                filteredResults = filteredResults.filter(item =>
                    item.title.toLowerCase().includes(query.toLowerCase()) ||
                    item.description.toLowerCase().includes(query.toLowerCase()) ||
                    item.tags.some(tag => tag.toLowerCase().includes(query.toLowerCase())) ||
                    item.streamer.username.toLowerCase().includes(query.toLowerCase())
                );
            }

            setResults(filteredResults);

        } catch (error) {
            console.error('Search error:', error);
            addNotification({
                type: 'error',
                title: 'Search Failed',
                message: 'Unable to perform search. Please try again.',
            });
        } finally {
            setLoading(false);
        }
    };

    const formatDuration = (seconds: number) => {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);

        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        }
        return `${minutes}m`;
    };

    const formatViewCount = (count: number) => {
        if (count >= 1000000) {
            return `${(count / 1000000).toFixed(1)}M`;
        } else if (count >= 1000) {
            return `${(count / 1000).toFixed(1)}K`;
        }
        return count.toString();
    };

    return (
        <Box>
            <VStack spacing={6} align="stretch">
                {/* Search Header */}
                <VStack spacing={4} align="stretch">
                    <HStack spacing={4}>
                        <InputGroup flex={1}>
                            <InputLeftElement>
                                <MagnifyingGlassIcon width="20px" />
                            </InputLeftElement>
                            <Input
                                placeholder="Search for content, streamers, or topics..."
                                value={query}
                                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setQuery(e.target.value)}
                                onKeyPress={(e: React.KeyboardEvent<HTMLInputElement>) => e.key === 'Enter' && performSearch()}
                            />
                        </InputGroup>

                        <Button
                            colorScheme="blue"
                            onClick={performSearch}
                            isLoading={loading}
                        >
                            Search
                        </Button>

                        {showFilters && (
                            <Button
                                leftIcon={<FunnelIcon width="16px" />}
                                variant="outline"
                            >
                                Filters
                            </Button>
                        )}
                    </HStack>
                </VStack>

                {/* Search Results */}
                <VStack spacing={4} align="stretch">
                    <HStack justify="space-between">
                        <Text fontSize="lg" fontWeight="bold">
                            {loading ? 'Searching...' : `${results.length} Results`}
                            {query && ` for "${query}"`}
                        </Text>
                    </HStack>

                    {loading ? (
                        <Box textAlign="center" py={8}>
                            <Spinner size="lg" />
                            <Text mt={4}>Searching content...</Text>
                        </Box>
                    ) : results.length === 0 ? (
                        <Alert status="info">
                            <AlertIcon />
                            <AlertDescription>
                                No content found matching your search criteria.
                            </AlertDescription>
                        </Alert>
                    ) : (
                        <SimpleGrid columns={{ base: 1, md: 2, lg: 3 }} spacing={6}>
                            {results.map((item: ContentItem) => (
                                <Card
                                    key={item.id}
                                    bg={cardBg}
                                    cursor="pointer"
                                    transition="all 0.2s"
                                    _hover={{ transform: 'translateY(-2px)', shadow: 'lg' }}
                                    onClick={() => onContentSelect?.(item)}
                                >
                                    <CardBody p={0}>
                                        <VStack spacing={3} align="stretch">
                                            {/* Thumbnail */}
                                            <Box position="relative">
                                                <Image
                                                    src={item.thumbnail}
                                                    alt={item.title}
                                                    borderTopRadius="md"
                                                    h="200px"
                                                    w="100%"
                                                    objectFit="cover"
                                                />

                                                {/* Live Badge */}
                                                {item.isLive && (
                                                    <Badge
                                                        position="absolute"
                                                        top={2}
                                                        left={2}
                                                        colorScheme="red"
                                                        variant="solid"
                                                    >
                                                        LIVE
                                                    </Badge>
                                                )}

                                                {/* Duration */}
                                                <Badge
                                                    position="absolute"
                                                    bottom={2}
                                                    right={2}
                                                    bg="blackAlpha.700"
                                                    color="white"
                                                >
                                                    {formatDuration(item.duration)}
                                                </Badge>
                                            </Box>

                                            {/* Content Info */}
                                            <VStack spacing={3} align="stretch" p={4}>
                                                <VStack spacing={2} align="stretch">
                                                    <Text fontWeight="bold" fontSize="md" noOfLines={2}>
                                                        {item.title}
                                                    </Text>

                                                    <Text fontSize="sm" color="gray.500" noOfLines={2}>
                                                        {item.description}
                                                    </Text>
                                                </VStack>

                                                {/* Streamer Info */}
                                                <HStack spacing={3}>
                                                    <Avatar size="sm" src={item.streamer.avatar} name={item.streamer.username} />
                                                    <VStack spacing={0} align="start" flex={1}>
                                                        <HStack>
                                                            <Text fontSize="sm" fontWeight="medium">
                                                                {item.streamer.username}
                                                            </Text>
                                                            {item.streamer.verified && (
                                                                <Badge size="sm" colorScheme="blue">✓</Badge>
                                                            )}
                                                        </HStack>
                                                        <Text fontSize="xs" color="gray.500">
                                                            {item.category}
                                                        </Text>
                                                    </VStack>
                                                </HStack>

                                                {/* Stats */}
                                                <HStack justify="space-between" fontSize="sm" color="gray.500">
                                                    <HStack>
                                                        <EyeIcon width="16px" />
                                                        <Text>{formatViewCount(item.viewCount)}</Text>
                                                    </HStack>

                                                    <HStack>
                                                        <HeartIcon width="16px" />
                                                        <Text>{formatViewCount(item.likeCount)}</Text>
                                                    </HStack>

                                                    <HStack>
                                                        <ClockIcon width="16px" />
                                                        <Text>{item.createdAt.toLocaleDateString()}</Text>
                                                    </HStack>
                                                </HStack>
                                            </VStack>
                                        </VStack>
                                    </CardBody>
                                </Card>
                            ))}
                        </SimpleGrid>
                    )}
                </VStack>
            </VStack>
        </Box>
    );
};