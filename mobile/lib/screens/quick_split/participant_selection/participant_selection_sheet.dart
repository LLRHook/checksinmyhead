import 'package:checks_frontend/screens/quick_split/bill_entry/bill_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/models/person.dart';

// Models and Providers
import 'models/recent_people_manager.dart';
import 'providers/participants_provider.dart';

// Widgets
import 'widgets/add_person_field.dart';
import 'widgets/recent_people_section.dart';
import 'widgets/current_participants_section.dart';
import 'widgets/empty_state.dart';
import 'widgets/continue_button.dart';

/// A bottom sheet allowing users to select or add participants for bill splitting
/// Provides recent people selection, new person addition, and navigation to bill entry
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

  /// Loads recently used people from database
  Future<void> _loadRecentPeople() async {
    final recentPeople = await RecentPeopleManager.loadRecentPeople();
    setState(() => _recentPeople = recentPeople);
  }

  /// Persists participants to recents for future use
  Future<void> _saveParticipantsToRecent(List<Person> participants) async {
    await RecentPeopleManager.saveRecentPeople(participants, _recentPeople);
  }

  /// Handles continuation to bill entry screen if participants are selected
  void _continueToBillEntry(BuildContext context, List<Person> participants) {
    if (participants.isEmpty) {
      _showRequiredParticipantsMessage(context);
      return;
    }

    _saveParticipantsToRecent(participants);
    HapticFeedback.mediumImpact();
    Navigator.pop(context, participants);
  }

  /// Shows error message when attempting to continue without participants
  void _showRequiredParticipantsMessage(BuildContext context) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
            decoration: _buildSheetDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSheetHandle(),
                _buildSheetHeader(context),
                _buildScrollableContent(),
                _buildContinueButton(context),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Creates the sheet's visual container with rounded corners and shadow
  BoxDecoration _buildSheetDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, -5),
        ),
      ],
    );
  }

  /// Creates the draggable sheet handle indicator
  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(3),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }

  /// Creates the sheet title and close button header
  Widget _buildSheetHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Who's splitting this bill?",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(foregroundColor: Colors.grey.shade700),
        ),
      ],
    );
  }

  /// Creates the scrollable middle content area
  Widget _buildScrollableContent() {
    return Expanded(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const AddPersonField(),
            const SizedBox(height: 24),
            RecentPeopleSection(recentPeople: _recentPeople),
            const SizedBox(height: 24),
            Consumer<ParticipantsProvider>(
              builder:
                  (context, provider, _) =>
                      provider.hasParticipants
                          ? CurrentParticipantsSection(
                            animationController: _animationController,
                          )
                          : const EmptyState(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Creates the continue button at the bottom of the sheet
  Widget _buildContinueButton(BuildContext context) {
    return Consumer<ParticipantsProvider>(
      builder:
          (context, provider, _) => ContinueButton(
            onContinue:
                () => _continueToBillEntry(context, provider.participants),
          ),
    );
  }
}

/// Shows the participant selection sheet and handles navigation to bill entry
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BillEntryScreen(participants: participants),
      ),
    );
  }
}
