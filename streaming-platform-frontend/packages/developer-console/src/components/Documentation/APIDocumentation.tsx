import React, { useState, useEffect } from 'react';
import { useAuth } from '../../stubs/auth';

interface APIEndpointDoc {
  path: string;
  method: string;
  summary: string;
  description: string;
  parameters: Parameter[];
  requestBody?: RequestBody;
  responses: Response[];
  examples: Example[];
  tags: string[];
}

interface Parameter {
  name: string;
  in: 'path' | 'query' | 'header';
  required: boolean;
  type: string;
  description: string;
  example?: any;
}

interface RequestBody {
  required: boolean;
  contentType: string;
  schema: any;
  example?: any;
}

interface Response {
  statusCode: number;
  description: string;
  schema?: any;
  example?: any;
}

interface Example {
  name: string;
  description: string;
  request: any;
  response: any;
}

export const APIDocumentation: React.FC = () => {
  const { user } = useAuth();
  const [endpoints, setEndpoints] = useState<APIEndpointDoc[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedEndpoint, setSelectedEndpoint] = useState<APIEndpointDoc | null>(null);
  const [searchQuery, setSearchQuery] = useState(');
  const [selectedTag, setSelectedTag] = useState<string>('all');

  useEffect(() => {
    fetchAPIDocumentation();
  }, []);

  const fetchAPIDocumentation = async () => {
    try {
      setLoading(true);
      
      // Mock API documentation data - in real implementation, this would come from OpenAPI spec
      const mockEndpoints: APIEndpointDoc[] = [
        {
          path: '/auth/login',
          method: 'POST',
          summary: 'User Authentication',
          description: 'Authenticate a user with email and password',
          tags: ['Authentication'],
          parameters: [],
          requestBody: {
            required: true,
            contentType: 'application/json',
            schema: {
              type: 'object',
              properties: {
                email: { type: 'string', format: 'email' },
                password: { type: 'string', minLength: 8 }
              },
              required: ['email', 'password']
            },
            example: {
              email: 'user@example.com',
              password: 'securepassword123'
            }
          },
          responses: [
            {
              statusCode: 200,
              description: 'Authentication successful',
              example: {
                token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                user: {
                  id: 'user123',
                  email: 'user@example.com',
                  role: 'viewer'
                }
              }
            },
            {
              statusCode: 401,
              description: 'Invalid credentials',
              example: { error: 'Invalid email or password' }
            }
          ],
          examples: [
            {
              name: 'Successful Login',
              description: 'Example of successful user authentication',
              request: {
                email: 'john.doe@example.com',
                password: 'mypassword123'
              },
              response: {
                token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                user: {
                  id: 'user_123',
                  email: 'john.doe@example.com',
                  role: 'creator'
                }
              }
            }
          ]
        },
        {
          path: '/streams',
          method: 'GET',
          summary: 'List Streams',
          description: 'Retrieve a list of live streams with optional filtering',
          tags: ['Streams'],
          parameters: [
            {
              name: 'category',
              in: 'query',
              required: false,
              type: 'string',
              description: 'Filter streams by category',
              example: 'gaming'
            },
            {
              name: 'limit',
              in: 'query',
              required: false,
              type: 'integer',
              description: 'Maximum number of streams to return',
              example: 20
            },
            {
              name: 'offset',
              in: 'query',
              required: false,
              type: 'integer',
              description: 'Number of streams to skip for pagination',
              example: 0
            }
          ],
          responses: [
            {
              statusCode: 200,
              description: 'List of streams retrieved successfully',
              example: {
                streams: [
                  {
                    id: 'stream_123',
                    title: 'Epic Gaming Session',
                    creator: 'GamerPro',
                    category: 'gaming',
                    viewerCount: 1250,
                    isLive: true
                  }
                ],
                total: 1,
                hasMore: false
              }
            }
          ],
          examples: [
            {
              name: 'Get Gaming Streams',
              description: 'Retrieve gaming category streams',
              request: {
                category: 'gaming',
                limit: 10
              },
              response: {
                streams: [
                  {
                    id: 'stream_456',
                    title: 'Competitive Tournament',
                    creator: 'ProGamer',
                    category: 'gaming',
                    viewerCount: 2500,
                    isLive: true
                  }
                ]
              }
            }
          ]
        },
        {
          path: '/streams/{streamId}',
          method: 'GET',
          summary: 'Get Stream Details',
          description: 'Retrieve detailed information about a specific stream',
          tags: ['Streams'],
          parameters: [
            {
              name: 'streamId',
              in: 'path',
              required: true,
              type: 'string',
              description: 'Unique identifier of the stream',
              example: 'stream_123'
            }
          ],
          responses: [
            {
              statusCode: 200,
              description: 'Stream details retrieved successfully',
              example: {
                id: 'stream_123',
                title: 'Epic Gaming Session',
                description: 'Join me for an epic gaming adventure!',
                creator: {
                  id: 'creator_456',
                  username: 'GamerPro',
                  displayName: 'Pro Gamer'
                },
                category: 'gaming',
                viewerCount: 1250,
                isLive: true,
                startedAt: '2023-12-01T10:00:00Z'
              }
            },
            {
              statusCode: 404,
              description: 'Stream not found',
              example: { error: 'Stream not found' }
            }
          ],
          examples: []
        }
      ];

      setEndpoints(mockEndpoints);
      if (mockEndpoints.length > 0) {
        setSelectedEndpoint(mockEndpoints[0]);
      }
    } catch (error) {
      console.error('Error fetching API documentation:', error);
    } finally {
      setLoading(false);
    }
  };

  const getAllTags = (): string[] => {
    const tags = new Set<string>();
    endpoints.forEach(endpoint => {
      endpoint.tags.forEach(tag => tags.add(tag));
    });
    return Array.from(tags).sort();
  };

  const filteredEndpoints = endpoints.filter(endpoint => {
    const matchesSearch = endpoint.path.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         endpoint.summary.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         endpoint.description.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesTag = selectedTag === 'all' || endpoint.tags.includes(selectedTag);
    return matchesSearch && matchesTag;
  });

  const getMethodColor = (method: string): string => {
    switch (method.toUpperCase()) {
      case 'GET': return 'bg-blue-100 text-blue-800';
      case 'POST': return 'bg-green-100 text-green-800';
      case 'PUT': return 'bg-yellow-100 text-yellow-800';
      case 'DELETE': return 'bg-red-100 text-red-800';
      case 'PATCH': return 'bg-purple-100 text-purple-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const renderCodeBlock = (code: any, language: string = 'json'): JSX.Element => {
    return (
      <pre className="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-sm">
        <code>{JSON.stringify(code, null, 2)}</code>
      </pre>
    );
  };

  return (
    <div className="api-documentation">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">API Documentation</h1>
        <p className="text-gray-600">Interactive documentation for all API endpoints</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Sidebar - Endpoint List */}
        <div className="lg:col-span-1">
          <div className="bg-white rounded-lg shadow-md p-6 sticky top-6">
            <div className="mb-4">
              <input
                type="text"
                placeholder="Search endpoints..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div className="mb-4">
              <select
                value={selectedTag}
                onChange={(e) => setSelectedTag(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="all">All Categories</option>
                {getAllTags().map(tag => (
                  <option key={tag} value={tag}>{tag}</option>
                ))}
              </select>
            </div>

            <div className="space-y-2">
              {filteredEndpoints.map((endpoint, index) => (
                <button
                  key={`${endpoint.method}-${endpoint.path}`}
                  onClick={() => setSelectedEndpoint(endpoint)}
                  className={`w-full text-left p-3 rounded-lg transition-colors ${
                    selectedEndpoint?.path === endpoint.path && selectedEndpoint?.method === endpoint.method
                      ? 'bg-blue-50 border border-blue-200'
                      : 'hover:bg-gray-50 border border-transparent'
                  }`}
                >
                  <div className="flex items-center space-x-2 mb-1">
                    <span className={`px-2 py-1 text-xs font-semibold rounded ${getMethodColor(endpoint.method)}`}>
                      {endpoint.method}
                    </span>
                  </div>
                  <div className="text-sm font-medium text-gray-900 mb-1">{endpoint.path}</div>
                  <div className="text-xs text-gray-500">{endpoint.summary}</div>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Main Content - Endpoint Details */}
        <div className="lg:col-span-2">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
              <span className="ml-4 text-gray-600">Loading documentation...</span>
            </div>
          ) : selectedEndpoint ? (
            <div className="bg-white rounded-lg shadow-md p-6">
              <div className="mb-6">
                <div className="flex items-center space-x-3 mb-4">
                  <span className={`px-3 py-1 text-sm font-semibold rounded ${getMethodColor(selectedEndpoint.method)}`}>
                    {selectedEndpoint.method}
                  </span>
                  <code className="text-lg font-mono bg-gray-100 px-3 py-1 rounded">{selectedEndpoint.path}</code>
                </div>
                <h2 className="text-2xl font-bold text-gray-900 mb-2">{selectedEndpoint.summary}</h2>
                <p className="text-gray-600">{selectedEndpoint.description}</p>
                
                {selectedEndpoint.tags.length > 0 && (
                  <div className="flex flex-wrap gap-2 mt-4">
                    {selectedEndpoint.tags.map(tag => (
                      <span key={tag} className="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded">
                        {tag}
                      </span>
                    ))}
                  </div>
                )}
              </div>

              {/* Parameters */}
              {selectedEndpoint.parameters.length > 0 && (
                <div className="mb-6">
                  <h3 className="text-lg font-semibold text-gray-900 mb-3">Parameters</h3>
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                          <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">In</th>
                          <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                          <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Required</th>
                          <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Description</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-200">
                        {selectedEndpoint.parameters.map((param, index) => (
                          <tr key={index}>
                            <td className="px-4 py-2 text-sm font-mono text-gray-900">{param.name}</td>
                            <td className="px-4 py-2 text-sm text-gray-600">{param.in}</td>
                            <td className="px-4 py-2 text-sm text-gray-600">{param.type}</td>
                            <td className="px-4 py-2 text-sm">
                              {param.required ? (
                                <span className="text-red-600 font-medium">Required</span>
                              ) : (
                                <span className="text-gray-500">Optional</span>
                              )}
                            </td>
                            <td className="px-4 py-2 text-sm text-gray-600">{param.description}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* Request Body */}
              {selectedEndpoint.requestBody && (
                <div className="mb-6">
                  <h3 className="text-lg font-semibold text-gray-900 mb-3">Request Body</h3>
                  <div className="mb-3">
                    <span className="text-sm text-gray-600">Content Type: </span>
                    <code className="text-sm bg-gray-100 px-2 py-1 rounded">{selectedEndpoint.requestBody.contentType}</code>
                    {selectedEndpoint.requestBody.required && (
                      <span className="ml-2 text-sm text-red-600 font-medium">Required</span>
                    )}
                  </div>
                  {selectedEndpoint.requestBody.example && (
                    <div>
                      <h4 className="text-sm font-medium text-gray-900 mb-2">Example:</h4>
                      {renderCodeBlock(selectedEndpoint.requestBody.example)}
                    </div>
                  )}
                </div>
              )}

              {/* Responses */}
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">Responses</h3>
                <div className="space-y-4">
                  {selectedEndpoint.responses.map((response, index) => (
                    <div key={index} className="border border-gray-200 rounded-lg p-4">
                      <div className="flex items-center space-x-2 mb-2">
                        <span className={`px-2 py-1 text-sm font-semibold rounded ${
                          response.statusCode >= 200 && response.statusCode < 300 ? 'bg-green-100 text-green-800' :
                          response.statusCode >= 400 && response.statusCode < 500 ? 'bg-yellow-100 text-yellow-800' :
                          'bg-red-100 text-red-800'
                        }`}>
                          {response.statusCode}
                        </span>
                        <span className="text-sm text-gray-600">{response.description}</span>
                      </div>
                      {response.example && (
                        <div>
                          <h5 className="text-sm font-medium text-gray-900 mb-2">Example Response:</h5>
                          {renderCodeBlock(response.example)}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Examples */}
              {selectedEndpoint.examples.length > 0 && (
                <div className="mb-6">
                  <h3 className="text-lg font-semibold text-gray-900 mb-3">Examples</h3>
                  <div className="space-y-6">
                    {selectedEndpoint.examples.map((example, index) => (
                      <div key={index} className="border border-gray-200 rounded-lg p-4">
                        <h4 className="text-md font-semibold text-gray-900 mb-2">{example.name}</h4>
                        <p className="text-sm text-gray-600 mb-4">{example.description}</p>
                        
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                          <div>
                            <h5 className="text-sm font-medium text-gray-900 mb-2">Request:</h5>
                            {renderCodeBlock(example.request)}
                          </div>
                          <div>
                            <h5 className="text-sm font-medium text-gray-900 mb-2">Response:</h5>
                            {renderCodeBlock(example.response)}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ) : (
            <div className="bg-white rounded-lg shadow-md p-8 text-center">
              <div className="text-6xl mb-4">📚</div>
              <h2 className="text-xl font-semibold text-gray-900 mb-2">Select an Endpoint</h2>
              <p className="text-gray-600">Choose an endpoint from the sidebar to view its documentation.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};