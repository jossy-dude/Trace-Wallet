import React, { useState, useEffect } from 'react';
import { TrendingUp, TrendingDown, Wallet, Activity, Users, Download } from 'lucide-react';
import api from '../utils/api';

const Dashboard = ({ toast }) => {
  const [stats, setStats] = useState({
    total_income: 0,
    total_expenses: 0,
    net_balance: 0,
    transaction_count: 0,
    recent_transactions: 0
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      const data = await api.getDashboardStats();
      setStats(data);
      setError(null);
    } catch (err) {
      console.error('Failed to load dashboard:', err);
      setError(err.message);
      toast?.error('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const handleExportCSV = async () => {
    try {
      const result = await api.exportCSV();
      
      // Create download link
      const blob = new Blob([result.csv], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `transactions_${new Date().toISOString().split('T')[0]}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
      
      toast?.success(`Exported ${result.count} transactions`);
    } catch (err) {
      console.error('Export failed:', err);
      toast?.error('Failed to export transactions');
    }
  };

  if (loading) {
    return (
      <div className="space-y-6 animate-fade-in">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-bold text-slate-100">Dashboard</h2>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="glass-card p-6 animate-pulse">
              <div className="h-4 bg-dark-700 rounded w-24 mb-4"></div>
              <div className="h-8 bg-dark-700 rounded w-32"></div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-6 animate-fade-in">
        <div className="glass-card p-6 text-center">
          <p className="text-red-400 mb-4">{error}</p>
          <button onClick={loadDashboardData} className="btn-primary">
            Retry
          </button>
        </div>
      </div>
    );
  }

  const statCards = [
    {
      title: 'Net Balance',
      value: `ETB ${stats.net_balance.toLocaleString()}`,
      icon: Wallet,
      color: stats.net_balance >= 0 ? 'text-emerald-400' : 'text-red-400',
      bgColor: stats.net_balance >= 0 ? 'bg-emerald-500/20' : 'bg-red-500/20',
      trend: stats.net_balance >= 0 ? 'positive' : 'negative'
    },
    {
      title: 'Total Income',
      value: `ETB ${stats.total_income.toLocaleString()}`,
      icon: TrendingUp,
      color: 'text-emerald-400',
      bgColor: 'bg-emerald-500/20',
      trend: 'positive'
    },
    {
      title: 'Total Expenses',
      value: `ETB ${stats.total_expenses.toLocaleString()}`,
      icon: TrendingDown,
      color: 'text-red-400',
      bgColor: 'bg-red-500/20',
      trend: 'negative'
    },
    {
      title: 'Transactions',
      value: stats.transaction_count.toString(),
      icon: Activity,
      color: 'text-vault-400',
      bgColor: 'bg-vault-500/20',
      trend: 'neutral'
    }
  ];

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-slate-100">Dashboard</h2>
          <p className="text-slate-500 mt-1">Financial overview and insights</p>
        </div>
        <button 
          onClick={handleExportCSV}
          className="btn-secondary flex items-center gap-2"
        >
          <Download className="w-4 h-4" />
          Export CSV
        </button>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((stat, index) => (
          <div key={index} className="glass-card p-6">
            <div className="flex items-center justify-between mb-4">
              <div className={`w-12 h-12 rounded-xl ${stat.bgColor} flex items-center justify-center`}>
                <stat.icon className={`w-6 h-6 ${stat.color}`} />
              </div>
              {stat.trend === 'positive' && (
                <TrendingUp className="w-5 h-5 text-emerald-400" />
              )}
              {stat.trend === 'negative' && (
                <TrendingDown className="w-5 h-5 text-red-400" />
              )}
            </div>
            <p className="text-sm text-slate-400">{stat.title}</p>
            <p className={`text-2xl font-bold mt-1 ${stat.color}`}>{stat.value}</p>
          </div>
        ))}
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="glass-card p-6">
          <h3 className="text-lg font-semibold text-slate-100 mb-4">Recent Activity</h3>
          <div className="space-y-3">
            <div className="flex items-center gap-3 p-3 bg-dark-800/50 rounded-xl">
              <div className="w-10 h-10 rounded-xl bg-vault-500/20 flex items-center justify-center">
                <Activity className="w-5 h-5 text-vault-400" />
              </div>
              <div className="flex-1">
                <p className="font-medium text-slate-200">Transactions this week</p>
                <p className="text-sm text-slate-500">{stats.recent_transactions} new transactions</p>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 bg-dark-800/50 rounded-xl">
              <div className="w-10 h-10 rounded-xl bg-emerald-500/20 flex items-center justify-center">
                <Users className="w-5 h-5 text-emerald-400" />
              </div>
              <div className="flex-1">
                <p className="font-medium text-slate-200">Active Contacts</p>
                <p className="text-sm text-slate-500">Manage your payment contacts</p>
              </div>
            </div>
          </div>
        </div>

        <div className="glass-card p-6">
          <h3 className="text-lg font-semibold text-slate-100 mb-4">Quick Tips</h3>
          <div className="space-y-3 text-sm text-slate-400">
            <div className="flex items-start gap-3">
              <div className="w-2 h-2 rounded-full bg-vault-400 mt-1.5"></div>
              <p>Connect your mobile device to automatically sync bank SMS messages</p>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-2 h-2 rounded-full bg-vault-400 mt-1.5"></div>
              <p>Use the People section to organize contacts for faster transactions</p>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-2 h-2 rounded-full bg-vault-400 mt-1.5"></div>
              <p>Export your data regularly for backup and analysis</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
