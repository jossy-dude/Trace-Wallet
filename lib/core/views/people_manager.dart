import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/vault_person.dart';
import '../services/database_service.dart';

class PeopleManagerScreen extends StatefulWidget {
  const PeopleManagerScreen({super.key});

  @override
  State<PeopleManagerScreen> createState() => _PeopleManagerScreenState();
}

class _PeopleManagerScreenState extends State<PeopleManagerScreen> {
  final Isar _isar = DatabaseService().isar;

  Future<void> _addPerson() async {
    String name = '';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Person'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name (e.g. Telebirr, Dad)'),
          onChanged: (val) => name = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (name.isNotEmpty) {
                final person = VaultPerson(name: name);
                await _isar.writeTxn(() async {
                  await _isar.vaultPersons.put(person);
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addAlias(VaultPerson person) async {
    String alias = '';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Alias to ${person.name}'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Alias (e.g. 127, M-PESA)'),
          onChanged: (val) => alias = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (alias.isNotEmpty && !person.aliases.contains(alias)) {
                final newAliases = List<String>.from(person.aliases)..add(alias);
                person.aliases = newAliases;
                await _isar.writeTxn(() async {
                  await _isar.vaultPersons.put(person);
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('People & Aliases Manager'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPerson,
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<List<VaultPerson>>(
        stream: _isar.vaultPersons.where().watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final people = snapshot.data!;
          if (people.isEmpty) {
            return const Center(child: Text('No people created yet. Add one to start learning aliases.'));
          }

          return ListView.builder(
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${person.aliases.length} Aliases'),
                  children: [
                    if (person.aliases.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No aliases registered. Tap "Add Alias" to map SMS names to this person.'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        children: person.aliases.map((alias) => Chip(label: Text(alias))).toList()
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Alias'),
                        onPressed: () => _addAlias(person),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
