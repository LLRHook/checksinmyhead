// mobile/lib/screens/tabs/tabs_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/screens/tabs/tab_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  List<AppTab> _tabs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  Future<void> _loadTabs() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final tabsJson = prefs.getString('tabs') ?? '[]';
    final List<dynamic> tabsList = jsonDecode(tabsJson);
    
    setState(() {
      _tabs = tabsList.map((json) => AppTab(
        id: json['id'],
        name: json['name'],
        createdAt: DateTime.parse(json['createdAt']),
        billIds: AppTab.parseBillIds(json['billIds'] ?? ''),
      )).toList();
      _isLoading = false;
    });
  }

  Future<void> _saveTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final tabsJson = jsonEncode(_tabs.map((tab) => {
      'id': tab.id ?? DateTime.now().millisecondsSinceEpoch,
      'name': tab.name,
      'createdAt': tab.createdAt.toIso8601String(),
      'billIds': tab.billIdsJson,
    }).toList());
    await prefs.setString('tabs', tabsJson);
  }

  void _createNewTab() async {
    final TextEditingController controller = TextEditingController();
    
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Tab'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Utah Trip',
            labelText: 'Tab Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      HapticFeedback.mediumImpact();
      
      final newTab = AppTab(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name.trim(),
        createdAt: DateTime.now(),
        billIds: [],
      );
      
      setState(() {
        _tabs.add(newTab);
      });
      
      await _saveTabs();
      
      // Navigate to the new tab
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TabDetailScreen(tab: newTab),
          ),
        );
        
        // Reload if changes were made
        if (result == true) {
          _loadTabs();
        }
      }
    }
  }

  Future<void> _deleteTab(AppTab tab) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tab'),
        content: Text('Delete "${tab.name}"? Bills will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _tabs.remove(tab);
      });
      await _saveTabs();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${tab.name}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    final scaffoldBgColor =
        brightness == Brightness.dark ? colorScheme.surface : Colors.grey[50];

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        title: const Text(
          'Tabs',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabs.isEmpty
              ? _buildEmptyState()
              : _buildTabsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTab,
        icon: const Icon(Icons.add),
        label: const Text('New Tab'),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tab,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Tabs Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a tab to group bills from a trip or event',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsList() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tabs.length,
      itemBuilder: (context, index) {
        final tab = _tabs[index];
        
        return Dismissible(
          key: Key('tab_${tab.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Tab'),
                content: Text('Delete "${tab.name}"? Bills will not be deleted.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            setState(() {
              _tabs.remove(tab);
            });
            _saveTabs();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: brightness == Brightness.dark 
                  ? colorScheme.surface 
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.folder_outlined,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(
                tab.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${tab.billIds.length} bill${tab.billIds.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onTap: () async {
                HapticFeedback.selectionClick();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TabDetailScreen(tab: tab),
                  ),
                );
                
                // Reload if changes were made
                if (result == true) {
                  _loadTabs();
                }
              },
            ),
          ),
        );
      },
    );
  }
}