# Engineering Decisions & Trade-offs

This document details the key engineering decisions made during Checkmate's development, the alternatives considered, and the rationale behind each choice. These decisions showcase the thoughtful approach to solving technical challenges while maintaining our privacy-first principles.

## State Management: Provider Pattern

### Decision: Provider for State Management

We chose the Provider pattern, Flutter's recommended state management solution:

**Why Provider:**
- Native Flutter team recommendation
- Simple and intuitive API
- Minimal boilerplate
- Built into Flutter ecosystem
- Perfect for small to medium apps

**Implementation Example:**
```dart
// From assignment_provider.dart
class AssignmentProvider extends ChangeNotifier {
  final Map<BillItem, Map<Person, double>> _assignments = {};
  
  void updateAssignment(BillItem item, Person person, double percentage) {
    if (!_assignments.containsKey(item)) {
      _assignments[item] = {};
    }
    _assignments[item]![person] = percentage;
    notifyListeners();
  }
}
```

**Trade-offs:**
- ✅ Easy to understand and implement
- ✅ Great Flutter integration
- ✅ Small bundle size impact
- ❌ Can become complex for very large apps
- ❌ Manual optimization needed for performance

## Database: Drift ORM

### Decision: Drift for Database Management

Selected Drift (formerly Moor) for type-safe SQLite access:

**Why Drift:**
```dart
// From database.dart - Type-safe table definitions
@DriftDatabase(tables: [People, TutorialStates, UserPreferences, RecentBills])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 2;
  
  static const int maxRecentPeople = 12;
  static const int maxRecentBills = 30;
}

// Clean, type-safe queries
Stream<List<PersonData>> watchPeople() => select(people).watch();
```

**Trade-offs:**
- ✅ Type-safe queries prevent runtime errors
- ✅ Built-in migration support
- ✅ Excellent code generation
- ❌ Requires build step
- ❌ Learning curve for SQL newcomers

## Animation System: Flutter's Built-in

### Decision: Native Flutter Animations

Used Flutter's AnimationController for all animations:

**Implementation:**
```dart
// From splash_screen.dart
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );
  }
}
```

**Trade-offs:**
- ✅ Native performance
- ✅ No external dependencies
- ✅ Full control over animations
- ❌ More code than animation libraries
- ❌ Manual lifecycle management

## Architecture: 100% Offline

### Decision: Zero-Network Architecture

Committed to complete offline functionality:

**Implementation:**
- No internet permissions in manifest
- All data stored locally in SQLite
- No analytics or telemetry
- No external API calls

**Trade-offs:**
- ✅ Perfect privacy
- ✅ Always works offline
- ✅ Zero server costs
- ✅ Instant operations
- ❌ No cloud backup
- ❌ No cross-device sync

## UI Framework: Flutter

### Decision: Flutter for Cross-Platform

Chose Flutter for iOS and Android development:

**Why Flutter:**
- Single codebase for both platforms
- Native performance
- Rich widget library
- Excellent developer experience
- Strong community support

**Performance Focus:**
- Fast startup time
- Smooth animations
- Reasonable memory usage

## Algorithm Design: Practical Simplicity

### Decision: Straightforward Calculation

Implemented clear, understandable bill splitting:

```dart
// From calculation_utils.dart
class CalculationUtils {
  static Map<String, double> calculatePersonAmounts({
    required Person person,
    required List<BillItem> items,
    required double subtotal,
    required double tax,
    required double tipAmount,
  }) {
    double personSubtotal = 0.0;
    
    // Simple item-based calculation
    if (items.isNotEmpty) {
      for (var item in items) {
        personSubtotal += item.amountForPerson(person);
      }
    }
    
    // Proportional tax and tip
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

**Trade-offs:**
- ✅ Easy to understand and verify
- ✅ Handles all common cases
- ✅ Fast enough for typical use
- ❌ Not optimized for extreme cases

## Testing Strategy: Unit Test Focus

### Decision: Comprehensive Unit Tests

Focused on testing core calculation logic:

**Test Coverage:**
- `calculation_utils_test.dart`: Bill calculations
- `currency_formatter_test.dart`: Number formatting
- `bill_item_test.dart`: Model logic
- `person_model_test.dart`: Data models
- `validation_utils_test.dart`: Input validation

**Trade-offs:**
- ✅ Critical logic well-tested
- ✅ Fast test execution
- ✅ Easy to maintain
- ❌ Limited integration testing
- ❌ UI testing minimal (done manually)

## Data Limits: Practical Constraints

### Decision: Reasonable Data Limits

Implemented sensible limits for performance:

```dart
// From database.dart
static const int maxRecentPeople = 12;
static const int maxRecentBills = 30;
```

**Trade-offs:**
- ✅ Predictable performance
- ✅ Manageable memory usage
- ✅ Simple cleanup logic
- ❌ Old data automatically removed

## Error Handling: User-Friendly

### Decision: Graceful Error Handling

Focused on user experience over technical errors:

**Implementation:**
- Input validation with clear messages
- Graceful handling of edge cases
- No app crashes from user input

**Trade-offs:**
- ✅ Better user experience
- ✅ Stable app performance
- ❌ Some errors handled silently/with logging

## Theme System: Material Design

### Decision: Standard Material Theme

Used Flutter's built-in theming system:

```dart
// From theme.dart
final appTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFFB8336A),
  // ... standard Material components
);
```

**Trade-offs:**
- ✅ Consistent with platform
- ✅ Minimal custom styling needed
- ✅ Accessibility built-in
- ❌ Less unique visual identity

## Conclusion

These engineering decisions reflect our priorities:

1. **Privacy First**: No network, no tracking, no data collection
2. **User Experience**: Simple, fast, reliable
3. **Code Quality**: Clean, testable, maintainable
4. **Practical Performance**: Optimized for real-world use

Each decision balanced complexity against benefit, always favoring user privacy and experience. The result is an app that works reliably offline while maintaining excellent performance.