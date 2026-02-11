import 'dart:async';

import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' hide Tab;

class TabManager extends ChangeNotifier {
  static final TabManager _instance = TabManager._internal();

  factory TabManager() => _instance;

  final _tabsStreamController = StreamController<List<AppTab>>.broadcast();

  Stream<List<AppTab>> get tabsStream => _tabsStreamController.stream;

  TabManager._internal();

  @override
  void dispose() {
    _tabsStreamController.close();
    super.dispose();
  }

  Future<List<AppTab>> getAllTabs() async {
    try {
      final tabsData = await DatabaseProvider.db.getAllTabs();
      final tabs = tabsData.map(_tabDataToAppTab).toList();
      _tabsStreamController.add(tabs);
      return tabs;
    } catch (e) {
      debugPrint('Error fetching tabs: $e');
      return [];
    }
  }

  Future<AppTab?> createTab(String name, {String description = ''}) async {
    try {
      final id = await DatabaseProvider.db.insertTab(
        TabsCompanion(
          name: Value(name),
          description: Value(description),
          billIds: const Value(''),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Fire-and-forget backend sync
      _syncTabToBackend(id, name, description);

      final tabData = await DatabaseProvider.db.getTabById(id);
      if (tabData == null) return null;

      final tab = _tabDataToAppTab(tabData);
      notifyListeners();
      return tab;
    } catch (e) {
      debugPrint('Error creating tab: $e');
      return null;
    }
  }

  Future<void> deleteTab(int id) async {
    try {
      await DatabaseProvider.db.deleteTab(id);
      await getAllTabs();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting tab: $e');
    }
  }

  Future<void> addBillsToTab(int tabId, List<int> billIds) async {
    try {
      final tabData = await DatabaseProvider.db.getTabById(tabId);
      if (tabData == null) return;

      final existingIds = AppTab.parseBillIds(tabData.billIds);
      final updatedIds = [...existingIds, ...billIds];

      await DatabaseProvider.db.updateTab(
        tabId,
        TabsCompanion(billIds: Value(updatedIds.join(','))),
      );

      // Fire-and-forget backend sync for each bill
      if (tabData.accessToken != null && tabData.backendId != null) {
        final apiService = ApiService();
        for (final billId in billIds) {
          apiService.addBillToTab(
            tabData.backendId!,
            billId,
            tabData.accessToken!,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding bills to tab: $e');
    }
  }

  Future<void> removeBillFromTab(int tabId, int billId) async {
    try {
      final tabData = await DatabaseProvider.db.getTabById(tabId);
      if (tabData == null) return;

      final existingIds = AppTab.parseBillIds(tabData.billIds);
      existingIds.remove(billId);

      await DatabaseProvider.db.updateTab(
        tabId,
        TabsCompanion(billIds: Value(existingIds.join(','))),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error removing bill from tab: $e');
    }
  }

  Future<AppTab?> getTabById(int id) async {
    try {
      final tabData = await DatabaseProvider.db.getTabById(id);
      if (tabData == null) return null;
      return _tabDataToAppTab(tabData);
    } catch (e) {
      debugPrint('Error fetching tab: $e');
      return null;
    }
  }

  Future<void> _syncTabToBackend(
    int localId,
    String name,
    String description,
  ) async {
    try {
      final apiService = ApiService();
      final response = await apiService.createTab(name, description);

      if (response != null) {
        await DatabaseProvider.db.updateTab(
          localId,
          TabsCompanion(
            backendId: Value(response.tabId),
            accessToken: Value(response.accessToken),
            shareUrl: Value(response.shareUrl),
          ),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing tab to backend: $e');
    }
  }

  Future<bool> finalizeTab(int localId) async {
    try {
      final tabData = await DatabaseProvider.db.getTabById(localId);
      if (tabData == null) return false;
      if (tabData.backendId == null || tabData.accessToken == null) return false;

      final apiService = ApiService();
      final settlements = await apiService.finalizeTab(
        tabData.backendId!,
        tabData.accessToken!,
      );

      if (settlements.isEmpty) return false;

      await DatabaseProvider.db.updateTab(
        localId,
        const TabsCompanion(finalized: Value(true)),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error finalizing tab: $e');
      return false;
    }
  }

  // Use the Drift-generated Tab type (not Flutter's Tab widget)
  AppTab _tabDataToAppTab(dynamic tabData) {
    return AppTab(
      id: tabData.id,
      name: tabData.name,
      description: tabData.description,
      createdAt: tabData.createdAt,
      billIds: AppTab.parseBillIds(tabData.billIds),
      backendId: tabData.backendId,
      accessToken: tabData.accessToken,
      shareUrl: tabData.shareUrl,
      finalized: tabData.finalized,
    );
  }
}
