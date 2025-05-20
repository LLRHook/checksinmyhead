# Technical Deep Dive: Checkmate

This document provides an in-depth technical analysis of Checkmate's actual architecture, performance, and engineering implementation as found in the codebase.

## Architecture Overview

Checkmate is built as a Flutter mobile application with a focus on privacy and performance:

- **Frontend**: Flutter/Dart with Material Design UI
- **State Management**: Provider pattern
- **Database**: SQLite via Drift ORM
- **Platform**: iOS and Android support

## Database Architecture

### Drift ORM Implementation

Checkmate uses Drift (formerly Moor) for type-safe database operations:

```dart
@DriftDatabase(tables: [People, TutorialStates, UserPreferences, RecentBills])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 2;
  
  static const int maxRecentPeople = 12;
  static const int maxRecentBills = 30;
}
```

### Table Structure

Four main tables power the application:

1. **People Table**
```dart
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  DateTimeColumn get lastUsed => dateTime()();
}
```

2. **TutorialStates Table**
```dart
class TutorialStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tutorialKey => text().unique()();
  BoolColumn get hasBeenSeen => boolean()();
  DateTimeColumn get lastShownDate => dateTime().nullable()();
}
```

3. **UserPreferences Table**
Stores user settings, payment methods, and tip preferences

4. **RecentBills Table**
Stores bill history with participant and item details

## Bill Splitting Algorithm

The actual bill splitting implementation uses a straightforward calculation approach:

```dart
class CalculationUtils {
  static Map<String, double> calculatePersonAmounts({
    required Person person,
    required List<Person> participants,
    required Map<Person, double> personShares,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
    required Person? birthdayPerson,
  }) {
    double personSubtotal = 0.0;

    if (items.isNotEmpty) {
      // Itemized approach: Sum costs of items assigned to this person
      for (var item in items) {
        personSubtotal += item.amountForPerson(person);
      }
    } else {
      // Proportional approach based on person's share
      final personTotal = personShares[person] ?? 0.0;
      final totalWithoutExtras = subtotal;
      final extras = tax + tipAmount;

      if (personTotal <= 0) {
        return {'subtotal': 0.0, 'tax': 0.0, 'tip': 0.0, 'total': 0.0};
      }

      final proportion = personTotal / (totalWithoutExtras + extras);
      personSubtotal = proportion * totalWithoutExtras;
    }

    // Calculate tax and tip proportionally to subtotal
    final proportion = personSubtotal / subtotal;
    final personTax = tax * proportion;
    final personTip = tipAmount * proportion;

    return {
      'subtotal': personSubtotal,
      'tax': personTax,
      'tip': personTip,
      'total': personSubtotal + personTax + personTip,
    };
  }
}
```

## Animation System

Checkmate uses Flutter's built-in AnimationController extensively:

### Splash Screen Animation
```dart
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
    ));
  }
}
```

### Loading Animations
```dart
class LoadingDots extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: dots.map((dot) {
            final delay = dots.indexOf(dot) * 0.2;
            final value = (_animationController.value - delay).clamp(0.0, 1.0);
            return AnimatedOpacity(
              opacity: 0.2 + (0.8 * value),
              duration: Duration(milliseconds: 300),
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
```

## State Management

Provider pattern implementation for state management:

```dart
class AssignmentProvider extends ChangeNotifier {
  final Map<BillItem, Map<Person, double>> _assignments = {};
  
  void updateAssignment(BillItem item, Person person, double percentage) {
    if (!_assignments.containsKey(item)) {
      _assignments[item] = {};
    }
    _assignments[item]![person] = percentage;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _assignments.clear();
    super.dispose();
  }
}
```

## Tutorial System

One-time tutorial guidance with database persistence:

```dart
class TutorialManager with ChangeNotifier {
  final AppDatabase _database;
  static const String assignmentTutorialKey = 'assignment_tutorial';
  
  Future<void> markTutorialSeen(String tutorialKey) async {
    await _database.insertTutorialState(TutorialState(
      tutorialKey: tutorialKey,
      hasBeenSeen: true,
      lastShownDate: DateTime.now(),
    ));
    notifyListeners();
  }
  
  Future<bool> shouldShowTutorial(String tutorialKey) async {
    final state = await _database.getTutorialState(tutorialKey);
    return state?.hasBeenSeen != true;
  }
}
```

## Memory Management

Proper resource disposal throughout the codebase:

```dart
@override
void dispose() {
  _controller.dispose();
  _animationController.dispose();
  _fadeController.dispose();
  super.dispose();
}
```

## Testing Infrastructure

The app includes unit tests for core functionality:

### Test Coverage
- **bill_item_test.dart**: Bill item model testing
- **calculation_utils_test.dart**: Bill calculation logic
- **currency_formatter_test.dart**: Currency formatting
- **person_model_test.dart**: Person model testing
- **validation_utils_test.dart**: Input validation

Example test implementation:
```dart
test('calculatePersonAmounts with items', () {
  final result = CalculationUtils.calculatePersonAmounts(
    person: person1,
    participants: [person1, person2],
    personShares: {},
    items: items,
    subtotal: 100.0,
    tax: 10.0,
    tipAmount: 15.0,
    birthdayPerson: null,
  );
  
  expect(result['subtotal'], 50.0);
  expect(result['tax'], 5.0);
  expect(result['tip'], 7.5);
  expect(result['total'], 62.5);
});
```

## Performance Features

### Key Features
1. **Limited data retention**: Max 12 recent people, 30 recent bills
2. **Smooth animations**: Animations with proper disposal
3. **Local storage**: All data stored on device
4. **Quick start**: Minimal initialization on app launch

### Animation Implementation
```dart
// Animations with proper lifecycle management
_controller = AnimationController(
  duration: const Duration(milliseconds: 300),
  vsync: this,
);
```

## Security & Privacy

### Zero-Network Architecture
- No internet permissions required
- All data stored locally in SQLite
- No external API calls or analytics

### Data Management
```dart
// Recent data limits
static const int maxRecentPeople = 12;
static const int maxRecentBills = 30;

// Data cleanup handled during save operation
// Excerpt from saveBill() method that handles cleanup
// when total bills exceed the maximum limit
if (count >= maxRecentBills) {
  // Find and delete oldest bill
  final oldestBill = await (select(recentBills)
    ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
    ..limit(1))
    .getSingle();
  await delete(recentBills).delete(oldestBill);
}
```

## Conclusion

Checkmate demonstrates solid mobile development practices:

1. **Architecture**: Clean separation with Provider pattern and Drift ORM
2. **Performance**: Efficient animations and memory management
3. **Privacy**: Complete offline functionality with local storage
4. **Code Quality**: Organized structure with unit tests
5. **User Experience**: Smooth animations and tutorial guidance

These implementations showcase practical Flutter development skills suitable for production applications.