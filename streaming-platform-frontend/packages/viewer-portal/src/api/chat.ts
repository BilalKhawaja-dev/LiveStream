// Chat API for real-time messaging
export interface ChatMessage {
  id: string;
  userId: string;
  username: string;
  message: string;
  timestamp: Date;
  streamId: string;
}

class ChatService {
  private ws: WebSocket | null = null;
  private messageHandlers: ((message: ChatMessage) => void)[] = [];
  private connectionHandlers: ((connected: boolean) => void)[] = [];

  connect(streamId: string, userId: string) {
    // Use WebSocket API Gateway endpoint (will be populated by Terraform)
    const wsUrl = process.env.REACT_APP_WS_ENDPOINT || 'ws://localhost:3001';
    
    this.ws = new WebSocket(wsUrl);
    
    this.ws.onopen = () => {
      console.log('Connected to chat');
      this.connectionHandlers.forEach(handler => handler(true));
      
      // Send connection message
      this.ws?.send(JSON.stringify({
        action: 'connect',
        streamId,
        userId
      }));
    };

    this.ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.type === 'message') {
          const message: ChatMessage = {
            id: data.id,
            userId: data.userId,
            username: data.username,
            message: data.message,
            timestamp: new Date(data.timestamp),
            streamId: data.streamId
          };
          this.messageHandlers.forEach(handler => handler(message));
        }
      } catch (error) {
        console.error('Error parsing chat message:', error);
      }
    };

    this.ws.onclose = () => {
      console.log('Disconnected from chat');
      this.connectionHandlers.forEach(handler => handler(false));
    };

    this.ws.onerror = (error) => {
      console.error('Chat connection error:', error);
    };
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  sendMessage(streamId: string, userId: string, username: string, message: string) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({
        action: 'message',
        streamId,
        userId,
        username,
        message,
        timestamp: new Date().toISOString()
      }));
    }
  }

  onMessage(handler: (message: ChatMessage) => void) {
    this.messageHandlers.push(handler);
    return () => {
      const index = this.messageHandlers.indexOf(handler);
      if (index > -1) {
        this.messageHandlers.splice(index, 1);
      }
    };
  }

  onConnectionChange(handler: (connected: boolean) => void) {
    this.connectionHandlers.push(handler);
    return () => {
      const index = this.connectionHandlers.indexOf(handler);
      if (index > -1) {
        this.connectionHandlers.splice(index, 1);
      }
    };
  }
}

export const chatService = new ChatService();