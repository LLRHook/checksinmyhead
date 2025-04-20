import 'package:flutter/material.dart';
import '/models/person.dart';
import '/screens/quick_split/bill_entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class QuickSplitSheet extends StatefulWidget {
  const QuickSplitSheet({super.key});

  @override
  State<QuickSplitSheet> createState() => _QuickSplitSheetState();
}

class _QuickSplitSheetState extends State<QuickSplitSheet> {
  final _nameController = TextEditingController();
  final List<Person> _participants = [];
  List<Person> _recentPeople = [];

  // A list of colors to assign to new participants
  final List<Color> _colors = [
    Colors.orangeAccent,
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.lightGreenAccent,
    Colors.deepPurpleAccent,
    Colors.yellowAccent,
    Colors.indigoAccent,
    Colors.limeAccent,
    Colors.deepOrangeAccent,
    Colors.tealAccent,
    Colors.amberAccent,
    Colors.purpleAccent,
    Colors.greenAccent,
    Colors.redAccent,
    Colors.lightBlueAccent,
    Colors.blueAccent,
  ];

  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRecentPeople();
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

    // Convert Person objects to JSON strings
    final recentPeopleJson =
        _participants.map((person) {
          return jsonEncode({'name': person.name, 'color': person.color.value});
        }).toList();

    // Save the list (up to 5 or however many you want to keep)
    await prefs.setStringList(
      'recent_people',
      recentPeopleJson.take(5).toList(),
    );
  }

  void _addPerson(String name) {
    if (name.isNotEmpty) {
      setState(() {
        _participants.add(
          Person(name: name, color: _colors[_colorIndex % _colors.length]),
        );
        _colorIndex++;
        _nameController.clear();
      });
    }
  }

  void _addRecentPerson(Person person) {
    setState(() {
      if (!_participants.any((p) => p.name == person.name)) {
        _participants.add(person);
      }
    });
  }

  void _removePerson(int index) {
    setState(() {
      _participants.removeAt(index);
    });
  }

  void _continueToBillEntry() {
    if (_participants.isNotEmpty) {
      // Save participants to recent people list
      _saveRecentPeople();

      // Close the sheet and navigate to the bill entry screen
      Navigator.pop(context, _participants);
    } else {
      // Show an error or notification that at least one person is needed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one person to continue'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Who's splitting this bill?",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // Use Expanded with SingleChildScrollView for the middle content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Input field for adding new people
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: "Add person by name",
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: _addPerson,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        onPressed: () => _addPerson(_nameController.text),
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Recent people chips
                  if (_recentPeople.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Recent people",
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children:
                              _recentPeople.map((person) {
                                final isSelected = _participants.any(
                                  (p) => p.name == person.name,
                                );
                                return FilterChip(
                                  label: Text(person.name),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      _addRecentPerson(person);
                                    } else {
                                      setState(() {
                                        _participants.removeWhere(
                                          (p) => p.name == person.name,
                                        );
                                      });
                                    }
                                  },
                                  selectedColor: person.color.withOpacity(0.2),
                                  checkmarkColor: person.color,
                                  side: BorderSide(
                                    color:
                                        isSelected
                                            ? person.color
                                            : Colors.grey.shade300,
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Added participants
                  if (_participants.isNotEmpty) ...[
                    Text(
                      "Current participants",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    // Replace AnimatedList with ListView.builder for simplicity
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _participants.length,
                      itemBuilder: (context, index) {
                        final person = _participants[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: person.color.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: person.color.withOpacity(0.3),
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
                            title: Text(person.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removePerson(index),
                              color: colorScheme.error,
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Continue button (outside the scrollable area)
          ElevatedButton(
            onPressed: _continueToBillEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              "Continue (${_participants.length} ${_participants.length == 1 ? 'person' : 'people'})",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// Usage example function to show the sheet (can be placed in another file if needed)
void showQuickSplitSheet(BuildContext context) {
  showModalBottomSheet<List<Person>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
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
