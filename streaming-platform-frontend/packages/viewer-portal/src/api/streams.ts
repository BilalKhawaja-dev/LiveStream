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

import { DynamoDBClient, ScanCommand, GetItemCommand, QueryCommand } from '@aws-sdk/client-dynamodb';

const dynamoClient = new DynamoDBClient({ region: 'us-east-1' });
const CLOUDFRONT_DOMAIN = process.env.REACT_APP_CLOUDFRONT_DOMAIN || 'your-cloudfront-domain.com';

export const streamsAPI = {
  getStreams: async (): Promise<Stream[]> => {
    try {
      const command = new ScanCommand({
        TableName: 'streaming-streams',
        FilterExpression: 'is_live = :live',
        ExpressionAttributeValues: {
          ':live': { BOOL: true }
        }
      });
      
      const response = await dynamoClient.send(command);
      return response.Items?.map(item => ({
        id: item.stream_id?.S || '',
        title: item.title?.S || '',
        streamer: item.streamer_name?.S || '',
        viewers: parseInt(item.viewer_count?.N || '0'),
        isLive: item.is_live?.BOOL || false,
        thumbnail: item.thumbnail_url?.S || 'https://via.placeholder.com/320x180',
        category: item.category?.S || '',
        quality: (item.quality?.S as any) || '1080p'
      })) || [];
    } catch (error) {
      console.error('Error fetching streams:', error);
      return [];
    }
  },

  getStream: async (id: string): Promise<Stream | null> => {
    try {
      const command = new GetItemCommand({
        TableName: 'streaming-streams',
        Key: { stream_id: { S: id } }
      });
      
      const response = await dynamoClient.send(command);
      if (!response.Item) return null;
      
      return {
        id: response.Item.stream_id?.S || '',
        title: response.Item.title?.S || '',
        streamer: response.Item.streamer_name?.S || '',
        viewers: parseInt(response.Item.viewer_count?.N || '0'),
        isLive: response.Item.is_live?.BOOL || false,
        thumbnail: response.Item.thumbnail_url?.S || 'https://via.placeholder.com/320x180',
        category: response.Item.category?.S || '',
        quality: (response.Item.quality?.S as any) || '1080p'
      };
    } catch (error) {
      console.error('Error fetching stream:', error);
      return null;
    }
  },

  getStreamUrl: (streamId: string): string => {
    return `https://${CLOUDFRONT_DOMAIN}/live/${streamId}.m3u8`;
  },

  searchStreams: async (query: string): Promise<Stream[]> => {
    try {
      const command = new ScanCommand({
        TableName: 'streaming-streams',
        FilterExpression: 'contains(#title, :query) OR contains(streamer_name, :query) OR contains(category, :query)',
        ExpressionAttributeNames: {
          '#title': 'title'
        },
        ExpressionAttributeValues: {
          ':query': { S: query }
        }
      });
      
      const response = await dynamoClient.send(command);
      return response.Items?.map(item => ({
        id: item.stream_id?.S || '',
        title: item.title?.S || '',
        streamer: item.streamer_name?.S || '',
        viewers: parseInt(item.viewer_count?.N || '0'),
        isLive: item.is_live?.BOOL || false,
        thumbnail: item.thumbnail_url?.S || 'https://via.placeholder.com/320x180',
        category: item.category?.S || '',
        quality: (item.quality?.S as any) || '1080p'
      })) || [];
    } catch (error) {
      console.error('Error searching streams:', error);
      return [];
    }
  }
};