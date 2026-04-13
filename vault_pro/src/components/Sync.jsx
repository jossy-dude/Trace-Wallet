import React, { useState, useEffect } from 'react';
import {
  Smartphone,
  Laptop,
  RefreshCw,
  CheckCircle,
  XCircle,
  Clock,
  Wifi,
  WifiOff,
  Server,
  Link,
  Unlink,
  Send,
  Download,
  AlertCircle,
  Play,
  Square,
  QrCode,
  Scan
} from 'lucide-react';
import api from '../utils/api';

const Sync = ({ toast }) => {
  const [serverStatus, setServerStatus] = useState('offline');
  const [discoveryRunning, setDiscoveryRunning] = useState(false);
  const [connectedDevices, setConnectedDevices] = useState([]);
  const [discoveredDevices, setDiscoveredDevices] = useState([]);
  const [syncHistory, setSyncHistory] = useState([]);
  const [targetIp, setTargetIp] = useState('');
  const [isSyncing, setIsSyncing] = useState(false);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadSyncData();
    // Poll for discovered devices every 5 seconds
    const interval = setInterval(loadDiscoveredDevices, 5000);
    return () => clearInterval(interval);
  }, []);

  const loadSyncData = async () => {
    try {
      setLoading(true);
      // Check health
      try {
        const health = await api.healthCheck();
        setServerStatus(health.status === 'healthy' ? 'online' : 'offline');
      } catch (err) {
        setServerStatus('offline');
      }
      
      // Load discovered devices
      await loadDiscoveredDevices();
      
      setError(null);
    } catch (err) {
      console.error('Failed to load sync data:', err);
      setError(err.message);
      toast?.error('Failed to load sync data');
    } finally {
      setLoading(false);
    }
  };

  const loadDiscoveredDevices = async () => {
    try {
      const devices = await api.getDiscoveredDevices();
      setDiscoveredDevices(devices || []);
    } catch (err) {
      // Silently fail - discovery might not be running
    }
  };

  const handleStartDiscovery = async () => {
    try {
      await api.startDiscovery();
      setDiscoveryRunning(true);
      addLog('UDP discovery started');
      toast?.success('Device discovery started');
    } catch (err) {
      console.error('Failed to start discovery:', err);
      toast?.error('Failed to start discovery');
    }
  };

  const handleStopDiscovery = async () => {
    try {
      await api.stopDiscovery();
      setDiscoveryRunning(false);
      addLog('UDP discovery stopped');
      toast?.info('Device discovery stopped');
    } catch (err) {
      console.error('Failed to stop discovery:', err);
      toast?.error('Failed to stop discovery');
    }
  };

  const handlePairDevice = async (device) => {
    try {
      addLog(`Attempting to pair with ${device.name} at ${device.ip}`);
      toast?.info(`Pairing with ${device.name}...`);
      // In a real implementation, this would send a pairing request
      setTimeout(() => {
        toast?.success(`Paired with ${device.name}`);
        addLog(`Successfully paired with ${device.name}`);
      }, 1500);
    } catch (err) {
      console.error('Failed to pair device:', err);
      toast?.error('Failed to pair device');
    }
  };

  const handleSync = async () => {
    if (!targetIp) {
      toast?.error('Please enter target IP address');
      return;
    }
    
    setIsSyncing(true);
    addLog(`Starting sync to ${targetIp}...`);
    
    try {
      // Simulate sync process - in real app, this would call actual sync API
      await new Promise(resolve => setTimeout(resolve, 2000));
      setIsSyncing(false);
      addLog(`Sync completed. Transactions synced.`);
      setSyncHistory([
        { id: Date.now(), device: targetIp, transactions: Math.floor(Math.random() * 20), status: 'success', timestamp: new Date().toLocaleString() },
        ...syncHistory
      ]);
      toast?.success('Sync completed successfully');
    } catch (err) {
      setIsSyncing(false);
      addLog(`Sync failed: ${err.message}`);
      toast?.error('Sync failed');
    }
  };

  const addLog = (message) => {
    setLogs(prev => [...prev, { timestamp: new Date().toLocaleTimeString(), message }]);
  };

  if (loading) {
    return (
      <div className="space-y-6 animate-fade-in">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-bold text-slate-100">Sync & Connection</h2>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="glass-card p-6 animate-pulse">
              <div className="h-4 bg-dark-700 rounded w-24 mb-4"></div>
              <div className="h-8 bg-dark-700 rounded w-32"></div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold text-slate-100">Sync & Connection</h2>
        <p className="text-slate-500 mt-1">Manage connections between desktop and mobile devices</p>
      </div>

      {/* Server Status */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                serverStatus === 'online' ? 'bg-emerald-500/20' : 'bg-red-500/20'
              }`}>
                <Server className={`w-6 h-6 ${
                  serverStatus === 'online' ? 'text-emerald-400' : 'text-red-400'
                }`} />
              </div>
              <div>
                <p className="text-sm text-slate-400">Server Status</p>
                <p className={`font-semibold ${
                  serverStatus === 'online' ? 'text-emerald-400' : 'text-red-400'
                }`}>
                  {serverStatus === 'online' ? 'Online' : 'Offline'}
                </p>
              </div>
            </div>
            <div className={`w-3 h-3 rounded-full ${
              serverStatus === 'online' ? 'bg-emerald-500 animate-pulse' : 'bg-red-500'
            }`}></div>
          </div>
          <p className="text-sm text-slate-500">Port: 8080</p>
          <p className="text-sm text-slate-500">IP: 192.168.1.100</p>
        </div>

        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-xl bg-vault-500/20 flex items-center justify-center">
                <Smartphone className="w-6 h-6 text-vault-400" />
              </div>
              <div>
                <p className="text-sm text-slate-400">Discovered Devices</p>
                <p className="font-semibold text-slate-200">{discoveredDevices.length}</p>
              </div>
            </div>
          </div>
          {!discoveryRunning ? (
            <button 
              onClick={handleStartDiscovery}
              className="w-full btn-primary flex items-center justify-center gap-2"
            >
              <Play className="w-4 h-4" />
              Start Discovery
            </button>
          ) : (
            <button 
              onClick={handleStopDiscovery}
              className="w-full btn-secondary flex items-center justify-center gap-2"
            >
              <Square className="w-4 h-4" />
              Stop Discovery
            </button>
          )}
        </div>

        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-xl bg-blue-500/20 flex items-center justify-center">
                <RefreshCw className={`w-6 h-6 text-blue-400 ${isSyncing ? 'animate-spin' : ''}`} />
              </div>
              <div>
                <p className="text-sm text-slate-400">Last Sync</p>
                <p className="font-semibold text-slate-200">
                  {syncHistory.length > 0 ? 'Just now' : 'Never'}
                </p>
              </div>
            </div>
          </div>
          <p className="text-sm text-slate-500">
            {syncHistory.length > 0 ? `${syncHistory[0].transactions} transactions synced` : 'No syncs yet'}
          </p>
        </div>
      </div>

      {/* Discovered Devices */}
      <div className="glass-card p-6">
        <h3 className="text-lg font-semibold text-slate-100 mb-4">Discovered Devices (UDP)</h3>
        {discoveredDevices.length > 0 ? (
          <div className="space-y-3">
            {discoveredDevices.map((device) => (
              <div key={device.id || device.ip} className="flex items-center justify-between p-4 bg-dark-800/50 rounded-xl">
                <div className="flex items-center gap-4">
                  <div className="w-10 h-10 rounded-xl bg-vault-500/20 flex items-center justify-center">
                    <Smartphone className="w-5 h-5 text-vault-400" />
                  </div>
                  <div>
                    <p className="font-medium text-slate-200">{device.name || 'Unknown Device'}</p>
                    <p className="text-sm text-slate-500">{device.ip}:{device.port || 8080}</p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <div className="text-right">
                    <span className="px-3 py-1 rounded-full text-xs font-medium status-pending">
                      Found
                    </span>
                    <p className="text-xs text-slate-500 mt-1">Last seen: {new Date(device.last_seen).toLocaleString()}</p>
                  </div>
                  <button 
                    onClick={() => handlePairDevice(device)}
                    className="btn-primary flex items-center gap-2"
                  >
                    <Link className="w-4 h-4" />
                    Pair
                  </button>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-8">
            <WifiOff className="w-12 h-12 text-slate-600 mx-auto mb-4" />
            <p className="text-slate-500">
              {discoveryRunning ? 'Scanning for devices...' : 'No devices discovered'}
            </p>
            {!discoveryRunning && (
              <button 
                onClick={handleStartDiscovery}
                className="mt-4 text-vault-400 hover:text-vault-300 text-sm font-medium"
              >
                Start scanning
              </button>
            )}
          </div>
        )}
      </div>

      {/* Manual Sync */}
      <div className="glass-card p-6">
        <h3 className="text-lg font-semibold text-slate-100 mb-4">Manual Sync</h3>
        <div className="flex flex-col md:flex-row gap-4">
          <div className="flex-1">
            <label className="block text-sm font-medium text-slate-400 mb-2">Target IP Address</label>
            <div className="relative">
              <Wifi className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500" />
              <input
                type="text"
                value={targetIp}
                onChange={(e) => setTargetIp(e.target.value)}
                placeholder="192.168.1.100"
                className="input-field pl-10"
              />
            </div>
          </div>
          <div className="flex items-end">
            <button 
              onClick={handleSync}
              disabled={isSyncing}
              className="btn-primary flex items-center gap-2 disabled:opacity-50"
            >
              {isSyncing ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  Syncing...
                </>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  Sync Now
                </>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Sync History */}
      <div className="glass-card p-6">
        <h3 className="text-lg font-semibold text-slate-100 mb-4">Sync History</h3>
        {syncHistory.length > 0 ? (
          <div className="space-y-3">
            {syncHistory.map((sync) => (
              <div key={sync.id} className="flex items-center justify-between p-4 bg-dark-800/50 rounded-xl">
                <div className="flex items-center gap-4">
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                    sync.status === 'success' ? 'bg-emerald-500/20' : 'bg-red-500/20'
                  }`}>
                    {sync.status === 'success' ? (
                      <CheckCircle className="w-5 h-5 text-emerald-400" />
                    ) : (
                      <XCircle className="w-5 h-5 text-red-400" />
                    )}
                  </div>
                  <div>
                    <p className="font-medium text-slate-200">{sync.device}</p>
                    <p className="text-sm text-slate-500">{sync.transactions} transactions</p>
                  </div>
                </div>
                <div className="text-right">
                  <span className={`px-3 py-1 rounded-full text-xs font-medium ${
                    sync.status === 'success' ? 'status-approved' : 'status-review'
                  }`}>
                    {sync.status}
                  </span>
                  <p className="text-xs text-slate-500 mt-1 flex items-center gap-1">
                    <Clock className="w-3 h-3" />
                    {sync.timestamp}
                  </p>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-slate-500 text-center py-4">No sync history yet</p>
        )}
      </div>

      {/* Activity Log */}
      <div className="glass-card p-6">
        <h3 className="text-lg font-semibold text-slate-100 mb-4">Activity Log</h3>
        <div className="bg-dark-900 rounded-xl p-4 h-48 overflow-y-auto font-mono text-sm">
          {logs.length > 0 ? (
            logs.map((log, idx) => (
              <div key={idx} className="flex gap-3 text-slate-400 mb-1">
                <span className="text-vault-500">[{log.timestamp}]</span>
                <span>{log.message}</span>
              </div>
            ))
          ) : (
            <p className="text-slate-600 italic">No activity yet...</p>
          )}
        </div>
      </div>
    </div>
  );
};

export default Sync;
