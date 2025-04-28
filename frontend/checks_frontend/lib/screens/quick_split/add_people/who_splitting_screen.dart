import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/models/person.dart';
import '../bill_entry/bill_entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class QuickSplitSheet extends StatefulWidget {
  const QuickSplitSheet({super.key});

  @override
  State<QuickSplitSheet> createState() => _QuickSplitSheetState();
}

class _QuickSplitSheetState extends State<QuickSplitSheet>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<Person> _participants = [];
  List<Person> _recentPeople = [];
  late AnimationController _animationController;

  // Map to track animation values for each list item
  final Map<String, Animation<double>> _listItemAnimations = {};

  // A list of modern, visually distinct colors for participants
  final List<Color> _colors = [
    const Color(0xFF5E35B1), // Deep Purple
    const Color(0xFF00ACC1), // Cyan
    const Color(0xFFD81B60), // Pink
    const Color(0xFF43A047), // Green
    const Color(0xFF6200EA), // Deep Purple A700
    const Color(0xFFFFB300), // Amber
    const Color(0xFF3949AB), // Indigo
    const Color(0xFF00897B), // Teal
    const Color(0xFFE64A19), // Deep Orange
    const Color(0xFF1E88E5), // Blue
    const Color(0xFF8E24AA), // Purple
    const Color(0xFFC0CA33), // Lime
    const Color(0xFFF4511E), // Deep Orange
    const Color(0xFF039BE5), // Light Blue
    const Color(0xFF7CB342), // Light Green
    const Color(0xFFD50000), // Red A700
  ];

  int _colorIndex = 0;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadRecentPeople();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  // Load recent people from storage
  Future<void> _loadRecentPeople() async {
    final prefs = await SharedPreferences.getInstance();
    final recentPeopleJson = prefs.getStringList('recent_people') ?? [];

    setState(() {
      if (recentPeopleJson.isNotEmpty) {
        _recentPeople =
            recentPeopleJson.map((json) {
              final map = jsonDecode(json);
              return Person(name: map['name'], color: Color(map['color']));
            }).toList();
      }
    });
  }

  // Save people to recent list
  Future<void> _saveRecentPeople() async {
    final prefs = await SharedPreferences.getInstance();

    // Create a combined list prioritizing current participants
    final combinedList = [..._participants];

    // Add recent people not in current participants
    for (final person in _recentPeople) {
      if (!combinedList.any((p) => p.name == person.name)) {
        combinedList.add(person);
      }
    }

    // Convert Person objects to JSON strings
    final recentPeopleJson =
        combinedList.map((person) {
          return jsonEncode({'name': person.name, 'color': person.color.value});
        }).toList();

    // Save the list (up to 8 recent people)
    await prefs.setStringList(
      'recent_people',
      recentPeopleJson.take(8).toList(),
    );
  }

  // Helper to get a darkened version of a color for better contrast
  Color _getDarkenedColor(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
    );
  }

  void _addPerson(String name) {
    if (name.trim().isNotEmpty) {
      setState(() {
        // Check if this name already exists
        if (_participants.any(
          (p) => p.name.toLowerCase() == name.trim().toLowerCase(),
        )) {
          // Show a snackbar indicating the name already exists
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name is already in the list'),
              behavior: SnackBarBehavior.floating,
              width: 280,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }

        // Add new person
        _participants.add(
          Person(
            name: name.trim(),
            color: _colors[_colorIndex % _colors.length],
          ),
        );
        _colorIndex++;
        _nameController.clear();
        _isAdding = false;

        // Vibrate to confirm addition
        HapticFeedback.lightImpact();
      });
    }
  }

  void _addRecentPerson(Person person) {
    setState(() {
      if (!_participants.any(
        (p) => p.name.toLowerCase() == person.name.toLowerCase(),
      )) {
        _participants.add(person);

        // Vibrate to confirm selection
        HapticFeedback.selectionClick();
      }
    });
  }

  void _removePerson(int index) {
    // Get the person for animation purposes
    final person = _participants[index];

    // Create a sliding animation for this specific person
    final slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0), // Slide right and off-screen
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Store the animation reference with person's name as key
    _listItemAnimations[person.name] = _animationController.drive(
      Tween<double>(begin: 1.0, end: 0.0),
    );

    // Reset the animation controller
    _animationController.reset();

    // Run the animation
    _animationController.forward().then((_) {
      // Once animation completes, actually remove the person
      setState(() {
        _participants.removeAt(index);
        _listItemAnimations.remove(person.name);
      });
    });

    // Vibrate to confirm removal
    HapticFeedback.mediumImpact();
  }

  void _continueToBillEntry() {
    if (_participants.isNotEmpty) {
      // Save participants to recent people list
      _saveRecentPeople();

      // Vibrate to confirm continuation
      HapticFeedback.mediumImpact();

      // Close the sheet and navigate to the bill entry screen
      Navigator.pop(context, _participants);
    } else {
      // Show an error with a more polished snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.person_off, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text('Add at least one person to continue'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          width: 280,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sheet handle indicator
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
              margin: const EdgeInsets.only(bottom: 16),
            ),
          ),

          // Header with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Who's splitting this bill?",
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          // Use Expanded with SingleChildScrollView for the middle content
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Input field for adding new people - with animation
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child:
                        _isAdding
                            ? Form(
                              key: _formKey,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nameController,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        hintText: "Enter name",
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      onFieldSubmitted: _addPerson,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter a name';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            _addPerson(_nameController.text);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.all(14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Add'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                            : ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isAdding = true;
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("Add Person"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.surface,
                                foregroundColor: colorScheme.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                side: BorderSide(
                                  color: colorScheme.primary.withOpacity(0.5),
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                  ),

                  const SizedBox(height: 24),

                  // Replace the Recent people chips section with this improved version
                  if (_recentPeople.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Recent People",
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _recentPeople.map((person) {
                                final isSelected = _participants.any(
                                  (p) =>
                                      p.name.toLowerCase() ==
                                      person.name.toLowerCase(),
                                );

                                // Get darker shades for better contrast
                                final darkColor = _getDarkenedColor(
                                  person.color,
                                  0.3,
                                );

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  child: InkWell(
                                    onTap: () {
                                      if (isSelected) {
                                        setState(() {
                                          _participants.removeWhere(
                                            (p) =>
                                                p.name.toLowerCase() ==
                                                person.name.toLowerCase(),
                                          );
                                          HapticFeedback.selectionClick();
                                        });
                                      } else {
                                        _addRecentPerson(person);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? person.color.withOpacity(0.12)
                                                : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? person.color
                                                  : Colors.grey.shade300,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Animated selection indicator
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            width: isSelected ? 8 : 0,
                                            height: isSelected ? 8 : 0,
                                            margin: EdgeInsets.only(
                                              right: isSelected ? 6 : 0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: person.color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            style: TextStyle(
                                              color:
                                                  isSelected
                                                      ? darkColor
                                                      : Colors.grey.shade700,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                            child: Text(person.name),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Added participants with animated deletion
                  if (_participants.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Current Participants",
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const Spacer(),
                        if (_participants.length > 1)
                          TextButton.icon(
                            onPressed: () {
                              // Vibrate for feedback
                              HapticFeedback.mediumImpact();

                              // Clear all participants with confirmation
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text(
                                        "Clear all participants?",
                                      ),
                                      content: const Text(
                                        "This will remove all people from your current list.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: Text(
                                            "Cancel",
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _participants.clear();
                                            });
                                            Navigator.pop(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text("Clear All"),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            icon: Icon(
                              Icons.clear_all,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            label: Text(
                              "Clear All",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Animated list items
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _participants.length,
                      itemBuilder: (context, index) {
                        final person = _participants[index];

                        // Get darker shade for text
                        final textColor = _getDarkenedColor(person.color, 0.3);

                        // Get the animation for this person (if being deleted)
                        final animation = _listItemAnimations[person.name];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SlideTransition(
                            position:
                                animation != null
                                    ? Tween<Offset>(
                                      begin: Offset.zero,
                                      end: const Offset(
                                        1.5,
                                        0,
                                      ), // Slide right off screen
                                    ).animate(
                                      CurvedAnimation(
                                        parent: _animationController,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    )
                                    : const AlwaysStoppedAnimation<Offset>(
                                      Offset.zero,
                                    ),
                            child: FadeTransition(
                              opacity:
                                  animation ??
                                  const AlwaysStoppedAnimation<double>(1.0),
                              child: SizeTransition(
                                sizeFactor:
                                    animation ??
                                    const AlwaysStoppedAnimation<double>(1.0),
                                axisAlignment: 0.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: person.color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: person.color.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: person.color,
                                      child: Text(
                                        person.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      person.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red.shade400,
                                      ),
                                      onPressed: () => _removePerson(index),
                                      tooltip: "Remove ${person.name}",
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // Empty state illustration when no participants
                  if (_participants.isEmpty) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Premium illustration container
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey.shade50,
                                  Colors.grey.shade100,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Background soft circle
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  // People icon with gradient
                                  ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback:
                                        (Rect bounds) => LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            colorScheme.primary.withOpacity(
                                              0.6,
                                            ),
                                            colorScheme.primary.withOpacity(
                                              0.3,
                                            ),
                                          ],
                                        ).createShader(bounds),
                                    child: Icon(
                                      Icons.group_outlined,
                                      size: 64,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  // Small add icon with circle background
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withOpacity(0.4),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Premium text with gradient - Checkmate pun
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback:
                                (Rect bounds) => LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    colorScheme.primary.withOpacity(0.9),
                                    colorScheme.primary.withOpacity(0.7),
                                  ],
                                ).createShader(bounds),
                            child: const Text(
                              "Your Move",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Add someone to split the bill",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),

          // Continue button with dynamic styling
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              onPressed: _continueToBillEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _participants.isEmpty
                        ? Colors.grey.shade200
                        : colorScheme.primary,
                foregroundColor:
                    _participants.isEmpty ? Colors.grey.shade500 : Colors.white,
                elevation: _participants.isEmpty ? 0 : 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: colorScheme.primary.withOpacity(0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          _participants.isEmpty
                              ? Colors.grey.shade600
                              : Colors.white,
                    ),
                  ),
                  if (_participants.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_participants.length} ${_participants.length == 1 ? 'person' : 'people'}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Usage example function to show the sheet
void showQuickSplitSheet(BuildContext context) {
  showModalBottomSheet<List<Person>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => FractionallySizedBox(
          heightFactor: 0.9,
          child: const QuickSplitSheet(),
        ),
  ).then((participants) {
    if (participants != null && participants.isNotEmpty) {
      // Navigate to the bill entry screen with the participants
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BillEntryScreen(participants: participants),
        ),
      );
    }
  });
}

// Extension for easier Color manipulation
extension ColorExtension on Color {
  Color withValues({int? red, int? green, int? blue, double? alpha}) {
    return Color.fromARGB(
      alpha != null ? (alpha * 255).round() : this.alpha,
      red ?? this.red,
      green ?? this.green,
      blue ?? this.blue,
    );
  }
}
