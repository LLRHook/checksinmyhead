// Billington: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:checks_frontend/screens/quick_split/bill_entry/bill_entry_screen.dart';
import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:checks_frontend/models/person.dart';

// Models and Providers
import 'models/recent_people_manager.dart';
import 'models/group_manager.dart';
import 'providers/participants_provider.dart';

// Widgets
import 'widgets/add_person_field.dart';
import 'widgets/recent_people_section.dart';
import 'widgets/current_participants_section.dart';
import 'widgets/empty_state.dart';
import 'widgets/continue_button.dart';
import 'widgets/groups_section.dart';

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
  bool _didAutoAdd = false;
  int _selectedTab = 0; // 0 = Recents, 1 = Groups
  List<PeopleGroupWithMembers> _savedGroups = [];
  List<PeopleGroupWithMembers> _suggestedGroups = [];

  @override
  void initState() {
    super.initState();
    _loadRecentPeople();
    _loadGroups();
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
    if (!mounted) return;
    setState(() => _recentPeople = recentPeople);
  }

  /// Loads saved and suggested groups from database
  Future<void> _loadGroups() async {
    final saved = await GroupManager.loadSavedGroups();
    final suggested = await GroupManager.loadSuggestedGroups();
    if (!mounted) return;
    setState(() {
      _savedGroups = saved;
      _suggestedGroups = suggested;
    });
  }

  /// Auto-adds the user as a participant if the preference is enabled
  Future<void> _autoAddSelf(ParticipantsProvider provider) async {
    final prefsService = PreferencesService();
    final autoAdd = await prefsService.getAutoAddSelf();
    if (!autoAdd) return;
    final displayName = await prefsService.getDisplayName();
    if (displayName == null || displayName.trim().isEmpty) return;
    if (!mounted) return;

    provider.addPerson(displayName.trim());
  }

  /// Adds all members of a group as participants
  void _onGroupTapped(PeopleGroupWithMembers group, ParticipantsProvider provider) {
    for (final member in group.members) {
      provider.addRecentPerson(member);
    }
    GroupManager.markGroupUsed(group.group.id);
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = 0); // Switch back to Recents
  }

  /// Saves a suggested group with a user-provided name
  Future<void> _onGroupSaved(int groupId, String name) async {
    await GroupManager.saveSuggestedGroup(groupId, name);
    await _loadGroups();
  }

  /// Deletes a group
  Future<void> _onGroupDeleted(int groupId) async {
    await GroupManager.deleteGroup(groupId);
    await _loadGroups();
  }

  /// Renames a group
  Future<void> _onGroupRenamed(int groupId, String newName) async {
    await GroupManager.renameGroup(groupId, newName);
    await _loadGroups();
  }

  /// Creates a new group
  Future<void> _onCreateGroup(String name, List<Person> members) async {
    await GroupManager.createGroup(name, members);
    await _loadGroups();
  }

  /// Persists participants to recents for future use
  Future<void> _saveParticipantsToRecent(List<Person> participants) async {
    await RecentPeopleManager.saveRecentPeople(participants, _recentPeople);
    GroupManager.refreshSuggestions(); // fire-and-forget
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
          if (!_didAutoAdd) {
            _didAutoAdd = true;
            final provider = Provider.of<ParticipantsProvider>(context, listen: false);
            _autoAddSelf(provider);
          }
          return Container(
            padding: const EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: 10,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sheet handle (decorative)
                ExcludeSemantics(
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSheetHeader(context),
                const SizedBox(height: 20),
                _buildScrollableContent(context),
                _buildContinueButton(context),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Creates the sheet title and close button header
  Widget _buildSheetHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 32), // Balance the close button
          Expanded(
            child: Text(
              "Who's splitting this bill?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Close button
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the segmented control toggle between Recents and Groups
  Widget _buildSegmentedControl() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildSegmentButton(
            label: 'Recents',
            index: 0,
            colorScheme: colorScheme,
          ),
          _buildSegmentButton(
            label: 'Groups',
            index: 1,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  /// Builds a single segment button within the segmented control
  Widget _buildSegmentButton({
    required String label,
    required int index,
    required ColorScheme colorScheme,
  }) {
    final isActive = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != index) {
            HapticFeedback.selectionClick();
            setState(() => _selectedTab = index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  /// Creates the scrollable middle content area
  Widget _buildScrollableContent(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AddPersonField(),
            const SizedBox(height: 16),
            _buildSegmentedControl(),
            const SizedBox(height: 16),
            AnimatedCrossFade(
              firstChild: RecentPeopleSection(recentPeople: _recentPeople),
              secondChild: GroupsSection(
                savedGroups: _savedGroups,
                suggestedGroups: _suggestedGroups,
                onGroupTapped: (group) => _onGroupTapped(
                  group,
                  Provider.of<ParticipantsProvider>(context, listen: false),
                ),
                onGroupSaved: _onGroupSaved,
                onGroupDeleted: _onGroupDeleted,
                onGroupRenamed: _onGroupRenamed,
                onCreateGroup: _onCreateGroup,
                recentPeople: _recentPeople,
              ),
              crossFadeState: _selectedTab == 0
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 300),
            ),
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
