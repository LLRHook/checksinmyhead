import 'package:flutter_test/flutter_test.dart';
import 'package:checks_frontend/models/tab.dart';

void main() {
  AppTab makeTab({
    int? id,
    int? backendId,
    String? accessToken,
    bool finalized = false,
    String? memberToken,
    String? role,
    bool isRemote = false,
  }) {
    return AppTab(
      id: id,
      name: 'Test Tab',
      createdAt: DateTime(2025, 1, 1),
      billIds: [1, 2, 3],
      backendId: backendId,
      accessToken: accessToken,
      finalized: finalized,
      memberToken: memberToken,
      role: role,
      isRemote: isRemote,
    );
  }

  group('AppTab.parseBillIds', () {
    test('parses comma-separated string', () {
      expect(AppTab.parseBillIds('1,2,3'), equals([1, 2, 3]));
    });

    test('parses single id', () {
      expect(AppTab.parseBillIds('42'), equals([42]));
    });

    test('returns empty list for empty string', () {
      expect(AppTab.parseBillIds(''), equals([]));
    });
  });

  group('AppTab.billIdsJson', () {
    test('serializes bill ids to comma-separated string', () {
      final tab = makeTab();
      expect(tab.billIdsJson, equals('1,2,3'));
    });

    test('round-trips through parse', () {
      final tab = makeTab();
      final parsed = AppTab.parseBillIds(tab.billIdsJson);
      expect(parsed, equals(tab.billIds));
    });
  });

  group('AppTab.isSynced', () {
    test('returns true when backendId is set', () {
      final tab = makeTab(backendId: 123);
      expect(tab.isSynced, isTrue);
    });

    test('returns false when backendId is null', () {
      final tab = makeTab();
      expect(tab.isSynced, isFalse);
    });
  });

  group('AppTab.isFinalized', () {
    test('returns true when finalized', () {
      final tab = makeTab(finalized: true);
      expect(tab.isFinalized, isTrue);
    });

    test('returns false when not finalized', () {
      final tab = makeTab();
      expect(tab.isFinalized, isFalse);
    });
  });

  group('AppTab.isCreator', () {
    test('returns true when role is creator', () {
      final tab = makeTab(role: 'creator');
      expect(tab.isCreator, isTrue);
    });

    test('returns false when role is member', () {
      final tab = makeTab(role: 'member');
      expect(tab.isCreator, isFalse);
    });

    test('returns false when role is null', () {
      final tab = makeTab();
      expect(tab.isCreator, isFalse);
    });
  });

  group('AppTab.isMember', () {
    test('returns true when memberToken is set', () {
      final tab = makeTab(memberToken: 'tok_123');
      expect(tab.isMember, isTrue);
    });

    test('returns false when memberToken is null', () {
      final tab = makeTab();
      expect(tab.isMember, isFalse);
    });
  });

  group('AppTab.getTotalAmount', () {
    test('sums bill totals', () {
      final tab = makeTab();
      expect(tab.getTotalAmount([10.0, 20.0, 30.0]), equals(60.0));
    });

    test('returns 0 for empty list', () {
      final tab = makeTab();
      expect(tab.getTotalAmount([]), equals(0.0));
    });

    test('handles single bill', () {
      final tab = makeTab();
      expect(tab.getTotalAmount([42.50]), equals(42.50));
    });
  });

  group('AppTab.copyWith', () {
    test('preserves all fields when no arguments given', () {
      final tab = makeTab(
        id: 1,
        backendId: 10,
        accessToken: 'tok',
        finalized: true,
      );
      final copy = tab.copyWith();
      expect(copy.id, equals(1));
      expect(copy.name, equals('Test Tab'));
      expect(copy.backendId, equals(10));
      expect(copy.accessToken, equals('tok'));
      expect(copy.isFinalized, isTrue);
      expect(copy.billIds, equals([1, 2, 3]));
    });

    test('updates name only', () {
      final tab = makeTab();
      final copy = tab.copyWith(name: 'New Name');
      expect(copy.name, equals('New Name'));
      expect(copy.billIds, equals([1, 2, 3]));
    });

    test('updates finalized status', () {
      final tab = makeTab();
      final copy = tab.copyWith(finalized: true);
      expect(copy.isFinalized, isTrue);
    });
  });
}
