import 'dart:async';

import 'package:checks_frontend/database/database.dart' hide Tab;
import 'package:checks_frontend/database/database_provider.dart';
import 'package:checks_frontend/models/tab.dart';
import 'package:checks_frontend/services/api_service.dart';
import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
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
      final tabs = await Future.wait(tabsData.map(_tabDataToAppTab));
      if (!_tabsStreamController.isClosed) {
        _tabsStreamController.add(tabs);
      }
      return tabs;
    } catch (e) {
      debugPrint('Error fetching tabs');
      return [];
    }
  }

  Future<AppTab?> createTab(
    String name, {
    String description = '',
    String? creatorDisplayName,
  }) async {
    try {
      final id = await DatabaseProvider.db.insertTab(
        TabsCompanion(
          name: Value(name),
          description: Value(description),
          billIds: const Value(''),
          createdAt: Value(DateTime.now()),
        ),
      );

      await _syncTabToBackend(
        id,
        name,
        description,
        creatorDisplayName: creatorDisplayName,
      );

      final tabData = await DatabaseProvider.db.getTabById(id);
      if (tabData == null) return null;

      final tab = await _tabDataToAppTab(tabData);
      notifyListeners();
      return tab;
    } catch (e) {
      debugPrint('Error creating tab');
      return null;
    }
  }

  Future<void> deleteTab(int id) async {
    try {
      await DatabaseProvider.db.deleteTab(id);
      await getAllTabs();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting tab');
    }
  }

  Future<bool> addBillsToTab(int tabId, List<int> billIds) async {
    try {
      final tabData = await DatabaseProvider.db.getTabById(tabId);
      if (tabData == null) return false;

      final existingIds = AppTab.parseBillIds(tabData.billIds);
      final attachedIds = <int>[];

      if (tabData.accessToken != null && tabData.backendId != null) {
        final apiService = ApiService();

        var syncSucceeded = true;
        for (final localBillId in billIds) {
          if (existingIds.contains(localBillId)) continue;
          final billData = await DatabaseProvider.db.getBillById(localBillId);
          final shareUrl = billData?.shareUrl;
          final backendBill = _parseBillShareUrl(shareUrl);
          if (backendBill == null) {
            debugPrint('Skipping backend tab sync for bill without share URL');
            syncSucceeded = false;
            continue;
          }

          try {
            await apiService.addBillToTab(
              tabData.backendId!,
              backendBill.id,
              tabData.accessToken!,
              billToken: backendBill.token,
              memberToken: tabData.memberToken,
            );
            attachedIds.add(localBillId);
          } on ApiException {
            syncSucceeded = false;
          }
        }
        await DatabaseProvider.db.updateTab(
          tabId,
          TabsCompanion(
            billIds: Value([...existingIds, ...attachedIds].join(',')),
          ),
        );
        notifyListeners();
        return syncSucceeded;
      }

      attachedIds.addAll(billIds.where((id) => !existingIds.contains(id)));
      await DatabaseProvider.db.updateTab(
        tabId,
        TabsCompanion(
          billIds: Value([...existingIds, ...attachedIds].join(',')),
        ),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding bills to tab');
      return false;
    }
  }

  Future<void> _syncTabToBackend(
    int localId,
    String name,
    String description, {
    String? creatorDisplayName,
  }) async {
    try {
      final apiService = ApiService();
      final response = await apiService.createTab(
        name,
        description,
        creatorDisplayName: creatorDisplayName,
      );

      final companion = TabsCompanion(
        backendId: Value(response.tabId),
        accessToken: Value(response.accessToken),
        shareUrl: Value(response.shareUrl),
        memberToken: Value(response.memberToken),
        role: Value(response.memberToken != null ? 'creator' : null),
      );
      await DatabaseProvider.db.updateTab(localId, companion);
      notifyListeners();
    } on ApiException {
      debugPrint('Error syncing tab to backend');
    } catch (_) {
      debugPrint('Error syncing tab to backend');
    }
  }

  /// Retries backend setup for a locally-created tab whose invite URL was not
  /// available when the tab was first created.
  Future<AppTab?> retryTabSync(
    int localId, {
    String? creatorDisplayName,
  }) async {
    final tabData = await DatabaseProvider.db.getTabById(localId);
    if (tabData == null) return null;
    if (tabData.shareUrl != null && tabData.shareUrl!.isNotEmpty) {
      return _tabDataToAppTab(tabData);
    }

    await _syncTabToBackend(
      localId,
      tabData.name,
      tabData.description,
      creatorDisplayName: creatorDisplayName,
    );
    return getTabById(localId);
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
      debugPrint('Error removing bill from tab');
    }
  }

  Future<AppTab?> getTabById(int id) async {
    try {
      final tabData = await DatabaseProvider.db.getTabById(id);
      if (tabData == null) return null;
      return _tabDataToAppTab(tabData);
    } catch (e) {
      debugPrint('Error fetching tab');
      return null;
    }
  }

  Future<bool> finalizeTab(int localId) async {
    try {
      final tabData = await DatabaseProvider.db.getTabById(localId);
      if (tabData == null) return false;
      if (tabData.backendId == null || tabData.accessToken == null) {
        return false;
      }

      final apiService = ApiService();
      final settlements = await apiService.finalizeTab(
        tabData.backendId!,
        tabData.accessToken!,
        memberToken: tabData.memberToken,
      );

      if (settlements.isEmpty) return false;

      await DatabaseProvider.db.updateTab(
        localId,
        const TabsCompanion(finalized: Value(true)),
      );

      notifyListeners();
      return true;
    } on ApiException {
      debugPrint('Error finalizing tab');
      return false;
    } catch (_) {
      debugPrint('Error finalizing tab');
      return false;
    }
  }

  /// Joins a remote tab via share URL
  Future<AppTab?> joinTab(String shareUrl, String displayName) async {
    try {
      // Parse and validate URL: https://billingtonapp.vercel.app/t/{id}?t={token}
      final uri = Uri.parse(shareUrl);

      const allowedHosts = {'billingtonapp.vercel.app', 'billington.app'};
      if (uri.scheme != 'https' || !allowedHosts.contains(uri.host)) {
        return null;
      }

      final pathSegments = uri.pathSegments;
      if (pathSegments.length < 2 || pathSegments[0] != 't') return null;

      final tabId = int.tryParse(pathSegments[1]);
      final accessToken = uri.queryParameters['t'];
      if (tabId == null || accessToken == null) return null;

      final apiService = ApiService();

      // Join the tab
      final existing = (await DatabaseProvider.db.getAllTabs()).where(
        (tab) =>
            tab.backendId == tabId &&
            tab.accessToken == accessToken &&
            tab.memberToken != null,
      );
      if (existing.isNotEmpty) {
        return _tabDataToAppTab(existing.first);
      }

      final joinResponse = await apiService.joinTab(
        tabId,
        accessToken,
        displayName,
      );

      // Fetch full tab data
      final tabData = await apiService.getTabData(tabId, accessToken);

      // Insert as remote tab in local DB
      final localId = await DatabaseProvider.db.insertTab(
        TabsCompanion(
          name: Value(tabData['name'] ?? 'Joined Tab'),
          description: Value(tabData['description'] ?? ''),
          billIds: const Value(''),
          backendId: Value(tabId),
          accessToken: Value(accessToken),
          shareUrl: Value(shareUrl),
          memberToken: Value(joinResponse.memberToken),
          role: Value(joinResponse.role),
          isRemote: const Value(true),
          createdAt: Value(DateTime.now()),
        ),
      );

      final insertedTab = await DatabaseProvider.db.getTabById(localId);
      if (insertedTab == null) return null;

      final displayCurrency =
          (tabData['display_currency'] as String? ?? 'USD').toUpperCase();
      await PreferencesService().setTabDisplayCurrency(
        localId,
        displayCurrency,
      );

      final tab = await _tabDataToAppTab(insertedTab);
      notifyListeners();
      return tab;
    } on ApiException {
      debugPrint('Error joining tab');
      rethrow;
    } catch (_) {
      debugPrint('Error joining tab');
      return null;
    }
  }

  Future<bool> leaveTab(int localId) async {
    try {
      final tabData = await DatabaseProvider.db.getTabById(localId);
      if (tabData == null ||
          tabData.backendId == null ||
          tabData.accessToken == null ||
          tabData.memberToken == null) {
        return false;
      }
      await ApiService().leaveTab(
        tabData.backendId!,
        tabData.accessToken!,
        tabData.memberToken!,
      );
      await DatabaseProvider.db.deleteTab(localId);
      await getAllTabs();
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Use the Drift-generated Tab type (not Flutter's Tab widget)
  Future<AppTab> _tabDataToAppTab(dynamic tabData) async {
    final appTab = AppTab(
      id: tabData.id,
      name: tabData.name,
      description: tabData.description,
      createdAt: tabData.createdAt,
      billIds: AppTab.parseBillIds(tabData.billIds),
      backendId: tabData.backendId,
      accessToken: tabData.accessToken,
      shareUrl: tabData.shareUrl,
      finalized: tabData.finalized,
      memberToken: tabData.memberToken,
      role: tabData.role,
      isRemote: tabData.isRemote,
      displayCurrency: 'USD',
    );
    if (appTab.id == null) return appTab;
    final currency = await PreferencesService().getTabDisplayCurrency(
      appTab.id!,
    );
    return appTab.copyWith(displayCurrency: currency);
  }

  _BackendBillRef? _parseBillShareUrl(String? shareUrl) {
    if (shareUrl == null || shareUrl.isEmpty) return null;

    final uri = Uri.tryParse(shareUrl);
    if (uri == null || uri.pathSegments.length < 2) return null;
    if (uri.pathSegments[uri.pathSegments.length - 2] != 'b') return null;

    final billId = int.tryParse(uri.pathSegments.last);
    final token = uri.queryParameters['t'];
    if (billId == null || token == null || token.isEmpty) return null;

    return _BackendBillRef(billId, token);
  }
}

class _BackendBillRef {
  final int id;
  final String token;

  const _BackendBillRef(this.id, this.token);
}
