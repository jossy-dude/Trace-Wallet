import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../services/database_service.dart';
import '../models/vault_transaction.dart';
import '../models/vault_person.dart';
import 'package:intl/intl.dart';
import 'people_manager.dart';

class DesktopDashboard extends StatefulWidget {
  const DesktopDashboard({super.key});

  @override
  State<DesktopDashboard> createState() => _DesktopDashboardState();
}

class _DesktopDashboardState extends State<DesktopDashboard> {
  final isar = DatabaseService().isar;
  bool _showNeedsAttentionOnly = false;

  Future<void> _quickAssign(VaultTransaction tx) async {
    // Fetch people
    final people = await isar.vaultPersons.where().findAll();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quick Assign Alias'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Raw Alias: ${tx.senderAlias}'),
                const SizedBox(height: 16),
                const Text('Assign to existing person:'),
                const SizedBox(height: 8),
                if (people.isEmpty) const Text('No people found. Add one below.')
                else ...people.map((p) => ListTile(
                  title: Text(p.name),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () async {
                    // Update person with new alias
                    final newAliases = List<String>.from(p.aliases);
                    if (tx.senderAlias != null && !newAliases.contains(tx.senderAlias)) {
                      newAliases.add(tx.senderAlias!);
                      p.aliases = newAliases;
                    }
                    
                    // Update transaction
                    tx.senderAlias = p.name;
                    tx.category = 'PROCESSED';
                    
                    await isar.writeTxn(() async {
                      await isar.vaultPersons.put(p);
                      await isar.vaultTransactions.put(tx);
                    });
                    
                    if (mounted) Navigator.pop(context);
                  },
                )),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create New Person / Manage People'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PeopleManagerScreen()));
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Integrity Ledger'),
        actions: [
          Row(
            children: [
              const Text('Needs Attention'),
              Switch(
                value: _showNeedsAttentionOnly,
                onChanged: (val) {
                  setState(() => _showNeedsAttentionOnly = val);
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PeopleManagerScreen()));
            },
            tooltip: 'People & Aliases Manager',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {}, // Isar .watch() handles this automatically
          ),
        ],
      ),
      body: StreamBuilder<List<VaultTransaction>>(
        // Watch for all transactions, sorted by date descending, optionally filtered
        stream: _showNeedsAttentionOnly 
            ? isar.vaultTransactions.filter().categoryEqualTo('Requires Review').sortByDateDesc().watch(fireImmediately: true)
            : isar.vaultTransactions.where().sortByDateDesc().watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data!;

          if (transactions.isEmpty) {
            return Center(
              child: Text(_showNeedsAttentionOnly ? 'All caught up! No transactions need attention.' : 'No transactions yet. Sync from your phone to begin.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Contact / Alias')),
                DataColumn(label: Text('Raw Text')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: transactions.map((tx) {
                final isReviewNeeded = tx.category == 'Requires Review';
                
                return DataRow(
                  cells: [
                    DataCell(Text(DateFormat('MMM dd, HH:mm').format(tx.date))),
                    DataCell(Text(
                      tx.amount != null ? '\$${tx.amount!.toStringAsFixed(2)}' : '---',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tx.category == 'INCOME' ? Colors.green : null,
                      ),
                    )),
                    DataCell(Text(tx.senderAlias ?? 'Unknown')),
                    DataCell(SizedBox(
                      width: 300,
                      child: Text(
                        tx.rawText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )),
                    DataCell(
                      isReviewNeeded
                          ? const Tooltip(
                              message: 'Alias not recognized. Please review.',
                              child: Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            )
                          : const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    ),
                    DataCell(
                      isReviewNeeded
                        ? ElevatedButton(
                            onPressed: () => _quickAssign(tx),
                            child: const Text('Assign'),
                          )
                        : const SizedBox.shrink(),
                    )
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
