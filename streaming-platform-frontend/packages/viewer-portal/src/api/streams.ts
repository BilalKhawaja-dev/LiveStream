// Streaming API for viewer portal
export interface Stream {
  id: string;
  title: string;
  streamer: string;
  viewers: number;
  isLive: boolean;
  thumbnail: string;
  category: string;
  quality: '720p' | '1080p' | '4K';
}

// Dummy streams for development
const DUMMY_STREAMS: Stream[] = [
  {
    id: '1',
    title: 'Gaming Stream - Live Now!',
    streamer: 'ProGamer123',
    viewers: 1250,
    isLive: true,
    thumbnail: 'https://via.placeholder.com/320x180',
    category: 'Gaming',
    quality: '1080p'
  },
  {
    id: '2',
    title: 'Music Performance',
    streamer: 'MusicMaster',
    viewers: 850,
    isLive: true,
    thumbnail: 'https://via.placeholder.com/320x180',
    category: 'Music',
    quality: '720p'
  },
  {
    id: '3',
    title: 'Cooking Show',
    streamer: 'ChefExpert',
    viewers: 0,
    isLive: false,
    thumbnail: 'https://via.placeholder.com/320x180',
    category: 'Lifestyle',
    quality: '1080p'
  }
];

export const streamsAPI = {
  getStreams: async (): Promise<Stream[]> => {
    await new Promise(resolve => setTimeout(resolve, 300));
    return DUMMY_STREAMS;
  },

  getStream: async (id: string): Promise<Stream | null> => {
    await new Promise(resolve => setTimeout(resolve, 200));
    return DUMMY_STREAMS.find(s => s.id === id) || null;
  },

  getStreamUrl: (streamId: string): string => {
    // Return CloudFront URL for HLS stream
    return `https://your-cloudfront-domain.com/live/${streamId}.m3u8`;
  },

  searchStreams: async (query: string): Promise<Stream[]> => {
    await new Promise(resolve => setTimeout(resolve, 300));
    return DUMMY_STREAMS.filter(s => 
      s.title.toLowerCase().includes(query.toLowerCase()) ||
      s.streamer.toLowerCase().includes(query.toLowerCase()) ||
      s.category.toLowerCase().includes(query.toLowerCase())
    );
  }
};