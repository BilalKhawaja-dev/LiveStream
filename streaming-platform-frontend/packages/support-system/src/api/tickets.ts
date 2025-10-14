import { DynamoDBClient, PutItemCommand, ScanCommand, UpdateItemCommand } from '@aws-sdk/client-dynamodb';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

export interface SupportTicket {
  id: string;
  userId: string;
  type: 'complaint' | 'technical' | 'billing' | 'general';
  subject: string;
  description: string;
  status: 'open' | 'in-progress' | 'resolved' | 'closed';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  createdAt: Date;
  updatedAt: Date;
  assignedTo?: string;
}

const dynamoClient = new DynamoDBClient({ region: 'us-east-1' });
const snsClient = new SNSClient({ region: 'us-east-1' });
const SUPPORT_TOPIC_ARN = process.env.REACT_APP_SUPPORT_TOPIC_ARN || 'arn:aws:sns:us-east-1:123456789012:support-notifications';

export const supportAPI = {
  createTicket: async (ticket: Omit<SupportTicket, 'id' | 'status' | 'createdAt' | 'updatedAt'>): Promise<SupportTicket> => {
    const ticketId = `ticket-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const now = new Date().toISOString();
    
    const newTicket: SupportTicket = {
      ...ticket,
      id: ticketId,
      status: 'open',
      createdAt: new Date(now),
      updatedAt: new Date(now)
    };

    // Save to DynamoDB
    await dynamoClient.send(new PutItemCommand({
      TableName: 'support-tickets',
      Item: {
        ticket_id: { S: ticketId },
        user_id: { S: ticket.userId },
        type: { S: ticket.type },
        subject: { S: ticket.subject },
        description: { S: ticket.description },
        status: { S: 'open' },
        priority: { S: ticket.priority },
        created_at: { S: now },
        updated_at: { S: now }
      }
    }));

    // Send notification
    await snsClient.send(new PublishCommand({
      TopicArn: SUPPORT_TOPIC_ARN,
      Message: JSON.stringify({
        ticketId,
        type: ticket.type,
        subject: ticket.subject,
        priority: ticket.priority,
        userId: ticket.userId
      }),
      Subject: `New Support Ticket: ${ticket.subject}`
    }));

    return newTicket;
  },

  getTickets: async (userId: string): Promise<SupportTicket[]> => {
    try {
      const command = new ScanCommand({
        TableName: 'support-tickets',
        FilterExpression: 'user_id = :userId',
        ExpressionAttributeValues: {
          ':userId': { S: userId }
        }
      });
      
      const response = await dynamoClient.send(command);
      return response.Items?.map(item => ({
        id: item.ticket_id?.S || '',
        userId: item.user_id?.S || '',
        type: (item.type?.S as any) || 'general',
        subject: item.subject?.S || '',
        description: item.description?.S || '',
        status: (item.status?.S as any) || 'open',
        priority: (item.priority?.S as any) || 'medium',
        createdAt: new Date(item.created_at?.S || ''),
        updatedAt: new Date(item.updated_at?.S || ''),
        assignedTo: item.assigned_to?.S
      })) || [];
    } catch (error) {
      console.error('Error fetching tickets:', error);
      return [];
    }
  },

  updateTicketStatus: async (ticketId: string, status: SupportTicket['status']): Promise<void> => {
    await dynamoClient.send(new UpdateItemCommand({
      TableName: 'support-tickets',
      Key: { ticket_id: { S: ticketId } },
      UpdateExpression: 'SET #status = :status, updated_at = :updatedAt',
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: {
        ':status': { S: status },
        ':updatedAt': { S: new Date().toISOString() }
      }
    }));
  }
};