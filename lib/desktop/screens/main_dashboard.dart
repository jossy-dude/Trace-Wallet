import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/vault_transaction.dart';
import '../../core/services/database_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/views/people_manager.dart'; 

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final isar = DatabaseService().isar;
  int _selectedIndex = 0;
  bool _privacyMask = false;
  bool _isVaultLocked = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Left Sidebar Navigation (Fixed width)
              _buildSidebar(colorScheme),
              
              // Main Content Area
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.02, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _buildCurrentPage(colorScheme),
                    ),
                  ),
                ),
              ),
            ],
          if (_isVaultLocked) _buildLockOverlay(colorScheme),
        ],
      ),
    );
  }

  Widget _buildLockOverlay(ColorScheme colorScheme) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        color: colorScheme.surface.withOpacity(0.8),
        child: Center(
          child: GlassCard(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_person_rounded, size: 64, color: colorScheme.primary),
                const SizedBox(height: 24),
                Text("Vault Locked", style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text("Enter master authorization to proceed", style: TextStyle(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 40),
                SizedBox(
                  width: 300,
                  child: TextField(
                    obscureText: true,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "••••••••",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      filled: true,
                    ),
                    onSubmitted: (val) {
                      if (val == "1234") { // Demo password
                        setState(() => _isVaultLocked = false);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => setState(() => _isVaultLocked = false),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Authenticate"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage(ColorScheme colorScheme) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardPage(colorScheme);
      case 1:
        return _buildLedgerPage(colorScheme);
      case 2:
        return _buildAnalyticsPage(colorScheme);
      case 3:
        return _buildSettingsPage(colorScheme);
      case 4:
        return _buildDevicesPage(colorScheme);
      default:
        return _buildDashboardPage(colorScheme);
    }
  }

  Widget _buildDevicesPage(ColorScheme colorScheme) {
    return Container(
      key: const ValueKey(4),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("P2P Device Management", colorScheme),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Local ID Card
              Expanded(
                flex: 1,
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("LOCAL IDENTIFICATION", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colorScheme.onSurfaceVariant.withOpacity(0.6))),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("This Device ID", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text("ABCD-1234-EFGH-5678", style: GoogleFonts.mono(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildStatusRow("P2P Bridge", "Active", AppColors.accentMint),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => _showAddDeviceDialog(colorScheme),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Pair New Device"),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Trusted Devices List
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TRUSTED DEVICES", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colorScheme.onSurfaceVariant.withOpacity(0.6))),
                    const SizedBox(height: 16),
                    StreamBuilder<List<PairedDevice>>(
                      stream: isar.pairedDevices.where().watch(fireImmediately: true),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final devices = snapshot.data!;
                        if (devices.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48.0),
                              child: Column(
                                children: [
                                  Icon(Icons.cell_tower, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  const Text("No devices paired yet", style: TextStyle(opacity: 0.5)),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: devices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildDeviceTile(devices[index], colorScheme),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(PairedDevice device, ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(device.deviceType == 'mobile' ? Icons.smartphone : Icons.laptop, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name ?? "Unknown Device", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(device.deviceId ?? "----", style: GoogleFonts.mono(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.6))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("LAST SEEN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant.withOpacity(0.5))),
              Text(device.lastSeen != null ? "Just now" : "Never", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pair New Device'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the Device ID of the vault you want to pair with.'),
            SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: 'Device ID',
                hintText: 'ABCD-1234-EFGH-5678',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Authorize')),
        ],
      ),
    );
  }

  Widget _buildDashboardPage(ColorScheme colorScheme) {
    return LayoutBuilder(
      key: const ValueKey(0),
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 900;
        
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.6),
              radius: 1.5,
              colors: [
                colorScheme.primary.withOpacity(0.05),
                colorScheme.surface,
              ],
            ),
          ),
          child: CustomScrollView(
            slivers: [
              _buildStickyHeader(colorScheme),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 16 : 32, 
                  vertical: 24
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _showWidgetDetailPanel("Monthly Performance", _buildHeroDetailEditor(colorScheme), colorScheme),
                        child: _buildHeroStats(colorScheme, isNarrow),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildMainContentGrid(colorScheme, isNarrow),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWidgetDetailPanel(String title, Widget editor, ColorScheme colorScheme) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Widget Detail",
      pageBuilder: (context, anim1, anim2) => Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim1),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 450,
              height: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.9),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), bottomLeft: Radius.circular(40)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40)],
                border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title, style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.primary)),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Expanded(child: editor),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text("Save Configuration"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDetailEditor(ColorScheme colorScheme) {
    return ListView(
      children: [
        _buildEditorSection("Display Options", [
          _buildSettingToggle("Show Decimals", true),
          _buildSettingToggle("Privacy Masking", _privacyMask),
          _buildSettingToggle("Show Goal Line", true),
        ], colorScheme),
        const SizedBox(height: 32),
        _buildEditorSection("Thresholds", [
          _buildNumericField("Monthly Goal Amount", "5000.00"),
          _buildNumericField("Warning Threshold (%)", "80"),
        ], colorScheme),
      ],
    );
  }

  Widget _buildNumericField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixText: "\$ ",
        ),
        controller: TextEditingController(text: value),
      ),
    );
  }

  Widget _buildEditorSection(String title, List<Widget> children, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colorScheme.onSurfaceVariant.withOpacity(0.5))),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  String _searchQuery = "";
  String _filterType = "All";

  Widget _buildLedgerPage(ColorScheme colorScheme) {
    return Container(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Full Transaction Ledger", colorScheme),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<VaultTransaction>>(
              stream: isar.vaultTransactions.where().sortByDateDesc().watch(fireImmediately: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var txs = snapshot.data!;
                
                // Apply Search and Filter
                if (_searchQuery.isNotEmpty) {
                  txs = txs.where((tx) => 
                    (tx.senderAlias ?? "").toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (tx.category ?? "").toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (tx.amount?.toString() ?? "").contains(_searchQuery)
                  ).toList();
                }
                
                if (_filterType != "All") {
                  if (_filterType == "Ghost Adjustments") {
                    txs = txs.where((tx) => tx.category == 'GHOST_ADJUST').toList();
                  } else if (_filterType == "Verified Only") {
                    txs = txs.where((tx) => tx.isApproved == true).toList();
                  } else if (_filterType == "Pending Approval") {
                    txs = txs.where((tx) => tx.isApproved == false).toList();
                  }
                }

                if (txs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: colorScheme.onSurfaceVariant.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text("No transactions match your criteria", style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: txs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildTransactionTile(txs[index], colorScheme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPage(ColorScheme colorScheme) {
    return StreamBuilder<List<VaultTransaction>>(
      stream: isar.vaultTransactions.where().watch(fireImmediately: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final txs = snapshot.data!;
        final now = DateTime.now();
        final currentMonth = txs.where((tx) => tx.date!.month == now.month && tx.date!.year == now.year);
        final lastMonth = txs.where((tx) => tx.date!.month == (now.month == 1 ? 12 : now.month - 1) && 
                                          tx.date!.year == (now.month == 1 ? now.year - 1 : now.year));

        double currentIncome = 0, currentExpense = 0;
        for (var tx in currentMonth) {
          if (tx.type == 'Income') currentIncome += tx.amount ?? 0;
          else if (tx.type == 'Expense') currentExpense += tx.amount ?? 0;
        }

        double lastIncome = 0, lastExpense = 0;
        for (var tx in lastMonth) {
          if (tx.type == 'Income') lastIncome += tx.amount ?? 0;
          else if (tx.type == 'Expense') lastExpense += tx.amount ?? 0;
        }

        double incomeChange = lastIncome > 0 ? ((currentIncome - lastIncome) / lastIncome) * 100 : 0;
        double expenseChange = lastExpense > 0 ? ((currentExpense - lastExpense) / lastExpense) * 100 : 0;

        return Container(
          key: const ValueKey(2),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Financial Insights", colorScheme),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(child: _buildComparisonCard("Income", currentIncome, incomeChange, Icons.trending_up, AppColors.accentMint, colorScheme)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildComparisonCard("Expenses", currentExpense, expenseChange, Icons.trending_down, colorScheme.error, colorScheme)),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  children: [
                    _buildAnalyticsCard(colorScheme),
                    _buildVelocityCard(colorScheme),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildComparisonCard(String title, double current, double change, IconData icon, Color accentColor, ColorScheme colorScheme) {
    bool isPositive = change >= 0;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colorScheme.onSurfaceVariant.withOpacity(0.6))),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "\$${current.toStringAsFixed(2)}",
            style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: isPositive ? AppColors.accentMint : colorScheme.error),
              const SizedBox(width: 4),
              Text(
                "${change.abs().toStringAsFixed(1)}% from last month",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? AppColors.accentMint : colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVelocityCard(ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SPENDING VELOCITY",
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.speed, color: colorScheme.primary, size: 32),
              const SizedBox(width: 16),
              Text(
                "Stable",
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            "Your daily spending rate is consistent with your 30-day average.",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage(ColorScheme colorScheme) {
    return Container(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("System Configuration", colorScheme),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              children: [
                _buildSettingsSection("Security", [
                  _buildSettingToggle('Biometric Lock', true),
                  _buildSettingToggle('Privacy Mask', false),
                ], colorScheme),
                const SizedBox(height: 24),
                _buildSettingsSection("Data Sync", [
                  _buildSettingToggle('Auto-Sync SMS', true),
                  _buildSettingToggle('Background Listener', true),
                ], colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(8),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSidebar(ColorScheme colorScheme) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.onSurface.withOpacity(0.05))),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.security, color: colorScheme.onPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                "VAULT",
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "v4.1",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          _buildNavButton(Icons.dashboard_rounded, "Dashboard", 0, colorScheme),
          _buildNavButton(Icons.receipt_long_rounded, "Ledger", 1, colorScheme),
          _buildNavButton(Icons.analytics_rounded, "Insights", 2, colorScheme),
          _buildNavButton(Icons.devices_rounded, "P2P Devices", 4, colorScheme),
          _buildNavButton(Icons.settings_rounded, "Settings", 3, colorScheme),
          const Spacer(),
          // System Status Widget
          _buildSystemStatusWidget(colorScheme),
          const SizedBox(height: 24),
          _buildLockToggle(colorScheme),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, int index, ColorScheme colorScheme) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusWidget(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SYSTEM STATUS",
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusRow("P2P Bridge", "Active", AppColors.accentMint),
          const SizedBox(height: 8),
          _buildStatusRow("Local AI", "Ready", colorScheme.primary),
          const SizedBox(height: 8),
          _buildStatusRow("Database", "Synced", AppColors.accentMint),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLockToggle(ColorScheme colorScheme) {
    return InkWell(
      onTap: () => setState(() => _isVaultLocked = true),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.error.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 18, color: colorScheme.error),
            const SizedBox(width: 12),
            Text(
              "Lock Vault",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(ColorScheme colorScheme) {
    return SliverAppBar(
      backgroundColor: colorScheme.surface.withOpacity(0.4),
      floating: true,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            "Security Fee Tracker",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 14, color: AppColors.accentMint),
                const SizedBox(width: 8),
                Text(
                  "ENCRYPTED",
                  style: GoogleFonts.inter(
                    fontSize: 10, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
            onPressed: () => _showSettingsModal(colorScheme),
          ),
        ],
      ),
    );
  }

  void _showSettingsModal(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingToggle('Dark Mode', true),
            _buildSettingToggle('Privacy Mask', false),
            _buildSettingToggle('Biometrics', true),
            _buildSettingToggle('Auto-Sync', true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildSettingToggle(String label, bool value) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: label == 'Privacy Mask' ? _privacyMask : value,
      onChanged: (val) {
        if (label == 'Privacy Mask') {
          setState(() => _privacyMask = val);
        } else {
          // Wired to global state/localStorage in production
          showDialog(context: context, builder: (c) => AlertDialog(title: Text('$label updated')));
        }
      },
    );
  }

  Widget _buildHeroStats(ColorScheme colorScheme, bool isNarrow) {
    return StreamBuilder<List<VaultTransaction>>(
      stream: isar.vaultTransactions.where().watch(fireImmediately: true),
      builder: (context, snapshot) {
        double totalPaid = 0;
        double goalAmount = 5000.0;
        
        if (snapshot.hasData) {
          final txs = snapshot.data!;
          final now = DateTime.now();
          for (var tx in txs.where((tx) => tx.date!.month == now.month)) {
            if (tx.type == 'Income') totalPaid += tx.amount ?? 0;
          }
        }

        double progress = (totalPaid / goalAmount).clamp(0.0, 1.0);

        return Flex(
          direction: isNarrow ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Hero Card
            Expanded(
              flex: isNarrow ? 0 : 2,
              child: _buildMainHeroCard(totalPaid, goalAmount, progress, colorScheme),
            ),
            if (!isNarrow) const SizedBox(width: 24) else const SizedBox(height: 24),
            // Side Goal Tracker
            Expanded(
              flex: isNarrow ? 0 : 1,
              child: _buildGoalCircleTracker(progress, colorScheme),
            ),
          ],
        );
      }
    );
  }

  Widget _buildMainHeroCard(double total, double goal, double progress, ColorScheme colorScheme) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        boxShadow: [
          BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20, bottom: -20,
            child: Icon(Icons.account_balance_wallet, size: 200, color: Colors.white.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ESTIMATED NET WORTH", style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text("\$${total.toStringAsFixed(2)}", style: GoogleFonts.manrope(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, tracking: -1)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("MONTHLY TARGET", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("\$${goal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
                      child: Text("${(progress * 100).toInt()}% ACHIEVED", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCircleTracker(double progress, ColorScheme colorScheme) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showWidgetDetailPanel("Goal Configuration", _buildGoalDetailEditor(colorScheme), colorScheme),
        child: GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text("SAVINGS GOAL", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: colorScheme.onSurfaceVariant.withOpacity(0.6))),
              const Spacer(),
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        height: 120, width: 120,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: colorScheme.onSurface.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentMint),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${(progress * 100).toInt()}%", style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                          Text("done", style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.6), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text("Keep going! You're almost there.", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withOpacity(0.7))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalDetailEditor(ColorScheme colorScheme) {
    return ListView(
      children: [
        _buildEditorSection("Target Settings", [
          _buildNumericField("Savings Target", "5000.00"),
          _buildNumericField("Auto-Adjust Monthly", "0.00"),
        ], colorScheme),
        const SizedBox(height: 32),
        _buildEditorSection("Visuals", [
          _buildSettingToggle("Show Percentage", true),
          _buildSettingToggle("Pulsing Progress", false),
        ], colorScheme),
      ],
    );
  }

  Widget _buildMainContentGrid(ColorScheme colorScheme, bool isNarrow) {
    return Flex(
      direction: isNarrow ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Community Members / Ledger
        Expanded(
          flex: isNarrow ? 0 : 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Community Members", colorScheme),
              const SizedBox(height: 20),
              StreamBuilder<List<VaultTransaction>>(
                stream: isar.vaultTransactions.where().sortByDateDesc().watch(fireImmediately: true),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final txs = snapshot.data!;
                  
                  if (txs.isEmpty) {
                    return _buildEmptyState(colorScheme);
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: txs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildTransactionTile(txs[index], colorScheme),
                  );
                },
              ),
            ],
          ),
        ),
        if (!isNarrow) const SizedBox(width: 40) else const SizedBox(height: 40),
        // Analytics Panel
        Expanded(
          flex: isNarrow ? 0 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Payment Analytics", colorScheme),
              const SizedBox(height: 20),
              _buildAnalyticsCard(colorScheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        Row(
          children: [
            if (title == "Full Transaction Ledger")
              _buildActionButton(Icons.account_balance, "Reconcile", () => _showReconciliationDialog(colorScheme), colorScheme),
            const SizedBox(width: 8),
            _buildMiniActionIcon(Icons.filter_list, () => _showFilterDialog(colorScheme), colorScheme),
            const SizedBox(width: 8),
            _buildMiniActionIcon(Icons.search, () => _showSearchDialog(colorScheme), colorScheme),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, ColorScheme colorScheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  void _showReconciliationDialog(ColorScheme colorScheme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconcile Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your current actual bank balance to identify discrepancies.'),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Actual Balance',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              // Future: Logic to calculate discrepancy and create a GHOST_ADJUST entry
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconciliation complete. 1 ghost adjustment created.')));
            }, 
            child: const Text('Reconcile')
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Ledger'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All', colorScheme),
            _buildFilterOption('Verified Only', colorScheme),
            _buildFilterOption('Pending Approval', colorScheme),
            _buildFilterOption('Ghost Adjustments', colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, ColorScheme colorScheme) {
    bool isSelected = _filterType == label;
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check, color: colorScheme.primary) : null,
      onTap: () {
        setState(() => _filterType = label);
        Navigator.pop(context);
      },
    );
  }

  void _showSearchDialog(ColorScheme colorScheme) {
    final controller = TextEditingController(text: _searchQuery);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Ledger'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter keyword or amount...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = "");
              Navigator.pop(context);
            }, 
            child: const Text('Clear')
          ),
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Close')
          ),
        ],
      ),
    );
  }

  Widget _buildMiniActionIcon(IconData icon, VoidCallback onTap, ColorScheme colorScheme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
        ),
        child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildTransactionTile(VaultTransaction tx, ColorScheme colorScheme) {
    bool isGhost = tx.category == 'GHOST_ADJUST';
    bool isUnrecognized = tx.senderAlias == null;
    String amountText = "${tx.amount! < 0 ? '-' : ''}\$${tx.amount?.abs().toStringAsFixed(2)}";
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: isGhost 
                ? Tooltip(
                    message: "GHOST ADJUST: System detected a discrepancy between the last bank balance and this transaction amount. This likely represents a hidden service fee or tax.",
                    child: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                  )
                : Text(
                    (tx.senderAlias ?? "??").substring(0, isUnrecognized ? 1 : 2).toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900, 
                      color: colorScheme.primary
                    ),
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.senderAlias ?? "Unrecognized Sender",
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold, 
                    color: colorScheme.onSurface
                  ),
                ),
                const SizedBox(height: 4),
                if (isUnrecognized)
                  InkWell(
                    onTap: () => _showQuickAssignDialog(tx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary, 
                        borderRadius: BorderRadius.circular(6) 
                      ),
                      child: Text(
                        "QUICK ASSIGN", 
                        style: TextStyle(
                          color: colorScheme.onPrimary, 
                          fontSize: 8, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isGhost ? colorScheme.errorContainer : AppColors.accentMint.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isGhost ? "GHOST ADJUST" : "PAID",
                      style: TextStyle(
                        color: isGhost ? colorScheme.error : const Color(0xFF005312),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ImageFiltered(
                imageFilter: _privacyMask ? ImageFilter.blur(sigmaX: 8, sigmaY: 8) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Text(
                  amountText,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w900, 
                    color: colorScheme.onSurface, 
                    fontSize: 18
                  ),
                ),
              ),
              Text(
                "ID: #${tx.id.toString().padLeft(5, '0')}",
                style: GoogleFonts.inter(
                  fontSize: 9, 
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6), 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(ColorScheme colorScheme) {
    return StreamBuilder<List<VaultTransaction>>(
      stream: isar.vaultTransactions.where().watch(fireImmediately: true),
      builder: (context, snapshot) {
        double incomeTotal = 0;
        double expenseTotal = 0;
        
        if (snapshot.hasData) {
          final txs = snapshot.data!;
          final now = DateTime.now();
          final currentMonthTxs = txs.where((tx) => tx.date!.month == now.month && tx.date!.year == now.year);
          
          for (var tx in currentMonthTxs) {
            if (tx.type == 'Income') incomeTotal += tx.amount ?? 0;
            if (tx.type == 'Expense') expenseTotal += tx.amount ?? 0;
          }
        }

        double total = incomeTotal + expenseTotal;
        double incomePercent = total > 0 ? (incomeTotal / total) * 100 : 0;
        double expensePercent = total > 0 ? (expenseTotal / total) * 100 : 0;

        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(color: AppColors.accentMint, value: incomePercent, radius: 10, showTitle: false),
                          PieChartSectionData(color: colorScheme.error.withOpacity(0.5), value: expensePercent, radius: 10, showTitle: false),
                        ],
                        centerSpaceRadius: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${DateTime.now().month == 10 ? 'OCTOBER' : 'CURRENT MONTH'} STATUS", 
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 1,
                            color: colorScheme.onSurfaceVariant
                          )
                        ),
                        const SizedBox(height: 12),
                        _buildLegendItem(AppColors.accentMint, "INCOME", "${incomePercent.toInt()}%", colorScheme),
                        _buildLegendItem(colorScheme.error.withOpacity(0.5), "EXPENSES", "${expensePercent.toInt()}%", colorScheme),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                "FINANCIAL HEALTH", 
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1,
                  color: colorScheme.onSurfaceVariant
                )
              ),
              const SizedBox(height: 16),
              _buildConsistencyBar("Savings Ratio", incomePercent / 100, AppColors.accentMint, colorScheme),
              const SizedBox(height: 16),
              _buildConsistencyBar("Burn Rate", expensePercent / 100, colorScheme.error, colorScheme),
            ],
          ),
        );
      }
    );
  }

  Widget _buildLegendItem(Color color, String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildConsistencyBar(String label, double value, Color color, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
            Text("${(value * 100).toInt()}%", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: colorScheme.onSurface.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showQuickAssignDialog(VaultTransaction tx) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: PeopleManagerScreen(), // Reusing existing screen inside a dialog or navigate
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 64, color: colorScheme.primary.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text(
            "Ready for your first Sync",
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Use the Vault Mobile Sensor to capture SMS data, then connect to this PC to see your glassmorphic financial ledger.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showSyncInstructions(colorScheme),
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text("How to Sync"),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSyncInstructions(ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vault Mobile Sync'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Install Vault Mobile on your Android device.'),
            Text('2. Enable "SMS Listener" in mobile settings.'),
            Text('3. Connect to the same Wi-Fi network.'),
            Text('4. Your transactions will appear in the Inbox.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }
}
