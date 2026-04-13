/**
 * Vault Pro API Client
 * Handles all communication with the FastAPI backend
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080';

class ApiClient {
  constructor() {
    this.baseUrl = API_BASE_URL;
    this.timeout = 10000; // 10 seconds
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);
    
    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options.headers,
        },
        signal: controller.signal,
      });
      
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.detail || `HTTP ${response.status}: ${response.statusText}`);
      }
      
      return await response.json();
    } catch (error) {
      clearTimeout(timeoutId);
      
      if (error.name === 'AbortError') {
        throw new Error('Request timeout - please try again');
      }
      
      if (error.message.includes('Failed to fetch')) {
        throw new Error('Cannot connect to server. Make sure the backend is running.');
      }
      
      throw error;
    }
  }

  // Health check
  async healthCheck() {
    return this.request('/api/health');
  }

  // Transactions
  async getTransactions(params = {}) {
    const queryString = new URLSearchParams(params).toString();
    return this.request(`/api/transactions${queryString ? '?' + queryString : ''}`);
  }

  async createTransaction(transaction) {
    return this.request('/api/transactions', {
      method: 'POST',
      body: JSON.stringify(transaction),
    });
  }

  async createTransactionsBatch(transactions) {
    return this.request('/api/transactions/batch', {
      method: 'POST',
      body: JSON.stringify(transactions),
    });
  }

  // SMS
  async sendSMS(smsData) {
    return this.request('/api/sms', {
      method: 'POST',
      body: JSON.stringify(smsData),
    });
  }

  async sendSMSBatch(messages) {
    return this.request('/api/sms/batch', {
      method: 'POST',
      body: JSON.stringify({ messages }),
    });
  }

  // People
  async getPeople() {
    return this.request('/api/people');
  }

  async createPerson(person) {
    return this.request('/api/people', {
      method: 'POST',
      body: JSON.stringify(person),
    });
  }

  // Dashboard
  async getDashboardStats() {
    return this.request('/api/dashboard/stats');
  }

  // Discovery
  async startDiscovery() {
    return this.request('/api/discovery/start');
  }

  async stopDiscovery() {
    return this.request('/api/discovery/stop');
  }

  async getDiscoveredDevices() {
    return this.request('/api/discovery/devices');
  }

  // Export
  async exportCSV(params = {}) {
    return this.request(`/api/export/csv${new URLSearchParams(params).toString()}`);
  }
}

export const api = new ApiClient();
export default api;
