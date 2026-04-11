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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar Navigation (Fixed width)
          _buildSidebar(colorScheme),
          
          // Main Content Area
          Expanded(
            child: Container(
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 900;
                  
                  return CustomScrollView(
                    slivers: [
                      _buildStickyHeader(colorScheme),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 16 : 32, 
                          vertical: 24
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildHeroStats(colorScheme, isNarrow),
                            const SizedBox(height: 40),
                            _buildMainContentGrid(colorScheme, isNarrow),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ColorScheme colorScheme) {
    return Container(
      width: 80,
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.security, color: colorScheme.primary, size: 28),
          const Spacer(),
          _buildNavIcon(Icons.home_rounded, 0, colorScheme),
          _buildNavIcon(Icons.verified_user_rounded, 1, colorScheme),
          _buildNavIcon(Icons.analytics_rounded, 2, colorScheme),
          _buildNavIcon(Icons.settings_rounded, 3, colorScheme),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, ColorScheme colorScheme) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Icon(
          icon,
          color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(0.5),
          size: 24,
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
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats(ColorScheme colorScheme, bool isNarrow) {
    return Flex(
      direction: isNarrow ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Hero Card (Monthly Progress)
        Expanded(
          flex: isNarrow ? 0 : 2,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative Circle
                Positioned(
                  right: -40,
                  top: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CURRENT MONTH PROGRESS",
                        style: GoogleFonts.inter(
                          color: colorScheme.onPrimary.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "12",
                            style: GoogleFonts.manrope(
                              color: colorScheme.onPrimary,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            "/20",
                            style: GoogleFonts.manrope(
                              color: colorScheme.onPrimary.withOpacity(0.4),
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Paid Status",
                        style: GoogleFonts.inter(
                          color: colorScheme.onPrimary.withOpacity(0.7), 
                          fontSize: 14, 
                          letterSpacing: 1
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "GOAL: \$2,000.00", 
                            style: TextStyle(
                              color: colorScheme.onPrimary, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12
                            )
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentMint, 
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: const Text(
                              "60% REACHED", 
                              style: TextStyle(
                                color: Color(0xFF005312), 
                                fontWeight: FontWeight.bold, 
                                fontSize: 10
                              )
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: 0.6,
                          minHeight: 12,
                          backgroundColor: Colors.black.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentMint),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isNarrow) const SizedBox(width: 24) else const SizedBox(height: 24),
        // Side mini cards
        Expanded(
          flex: isNarrow ? 0 : 1,
          child: Column(
            children: [
              StatCard(
                label: "COLLECTED",
                value: "\$1,200",
                icon: Icons.account_balance_wallet,
                iconBackgroundColor: colorScheme.primary.withOpacity(0.1),
                iconColor: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              StatCard(
                label: "PENDING",
                value: "\$800",
                icon: Icons.pending_actions,
                iconBackgroundColor: colorScheme.error.withOpacity(0.1),
                iconColor: colorScheme.error,
              ),
            ],
          ),
        ),
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
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
        Row(
          children: [
            _buildMiniActionIcon(Icons.filter_list, colorScheme),
            const SizedBox(width: 8),
            _buildMiniActionIcon(Icons.search, colorScheme),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniActionIcon(IconData icon, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildTransactionTile(VaultTransaction tx, ColorScheme colorScheme) {
    bool isGhost = tx.category == 'GHOST_ADJUST';
    bool isUnrecognized = tx.senderAlias == null;
    
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
              Text(
                "${tx.amount! < 0 ? '-' : ''}\$${tx.amount?.abs().toStringAsFixed(2)}",
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w900, 
                  color: colorScheme.onSurface, 
                  fontSize: 18
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
                      PieChartSectionData(color: AppColors.accentMint, value: 60, radius: 10, showTitle: false),
                      PieChartSectionData(color: colorScheme.error.withOpacity(0.5), value: 20, radius: 10, showTitle: false),
                      PieChartSectionData(color: colorScheme.onSurface.withOpacity(0.1), value: 20, radius: 10, showTitle: false),
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
                      "OCTOBER STATUS", 
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 1,
                        color: colorScheme.onSurfaceVariant
                      )
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem(AppColors.accentMint, "PAID", "60%", colorScheme),
                    _buildLegendItem(colorScheme.error.withOpacity(0.5), "DUE", "20%", colorScheme),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            "PAYMENT CONSISTENCY", 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1,
              color: colorScheme.onSurfaceVariant
            )
          ),
          const SizedBox(height: 16),
          _buildConsistencyBar("Early Payers", 0.75, AppColors.accentMint, colorScheme),
          const SizedBox(height: 16),
          _buildConsistencyBar("Consistently Late", 0.15, colorScheme.error, colorScheme),
        ],
      ),
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
            onPressed: () {}, // Future: Instructions dialog
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
}
