import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';
import '../bill_entry/bill_entry_screen.dart';

// Models
import 'models/recent_people_manager.dart';

// Providers
import 'providers/participants_provider.dart';

// Widgets
import 'widgets/add_person_field.dart';
import 'widgets/recent_people_section.dart';
import 'widgets/current_participants_section.dart';
import 'widgets/empty_state.dart';
import 'widgets/continue_button.dart';

class ParticipantSelectionSheet extends StatefulWidget {
  const ParticipantSelectionSheet({super.key});

  @override
  State<ParticipantSelectionSheet> createState() =>
      _ParticipantSelectionSheetState();
}

class _ParticipantSelectionSheetState extends State<ParticipantSelectionSheet>
    with SingleTickerProviderStateMixin {
  List<Person> _recentPeople = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadRecentPeople();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Load recent people from storage
  Future<void> _loadRecentPeople() async {
    final recentPeople = await RecentPeopleManager.loadRecentPeople();
    setState(() {
      _recentPeople = recentPeople;
    });
  }

  // Save participants to recent people list
  Future<void> _saveParticipantsToRecent(List<Person> participants) async {
    await RecentPeopleManager.saveRecentPeople(participants, _recentPeople);
  }

  void _continueToBillEntry(BuildContext context, List<Person> participants) {
    if (participants.isNotEmpty) {
      // Save participants to recent people list
      _saveParticipantsToRecent(participants);

      // Vibrate to confirm continuation
      HapticFeedback.mediumImpact();

      // Close the sheet and navigate to the bill entry screen
      Navigator.pop(context, participants);
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ParticipantsProvider(),
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: 10,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

                        // Input field for adding new people
                        const AddPersonField(),

                        const SizedBox(height: 24),

                        // Recent people section
                        RecentPeopleSection(recentPeople: _recentPeople),

                        const SizedBox(height: 24),

                        // Current participants section
                        Consumer<ParticipantsProvider>(
                          builder:
                              (context, provider, _) =>
                                  provider.hasParticipants
                                      ? CurrentParticipantsSection(
                                        animationController:
                                            _animationController,
                                      )
                                      : const EmptyState(),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Continue button
                Consumer<ParticipantsProvider>(
                  builder:
                      (context, provider, _) => ContinueButton(
                        onContinue:
                            () => _continueToBillEntry(
                              context,
                              provider.participants,
                            ),
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Function to show the participant selection bottom sheet
Future<void> showParticipantSelectionSheet(BuildContext context) async {
  final participants = await showModalBottomSheet<List<Person>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => const FractionallySizedBox(
          heightFactor: 0.9,
          child: ParticipantSelectionSheet(),
        ),
  );

  if (participants != null && participants.isNotEmpty && context.mounted) {
    // Navigate to the bill entry screen with the participants
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BillEntryScreen(participants: participants),
      ),
    );
  }
}
