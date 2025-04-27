import 'package:flutter/material.dart';
import '/models/person.dart';

class EmptyItemsView extends StatelessWidget {
  final List<Person> participants;
  final Map<Person, double> personFinalShares;
  final Person? birthdayPerson;
  final double unassignedAmount;
  final double Function(Person) getPersonBillPercentage;

  const EmptyItemsView({
    super.key,
    required this.participants,
    required this.personFinalShares,
    required this.birthdayPerson,
    required this.unassignedAmount,
    required this.getPersonBillPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state illustration
            Container(
              width: 100, // Reduced from 120
              height: 100, // Reduced from 120
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 48, // Reduced from 60
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16), // Reduced from 24
            
            // Title
            Text(
              'No Items Added',
              style: TextStyle(
                fontSize: 18, // Reduced from 20
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8), // Reduced from 12
            
            // Description
            Text(
              'Bill total will be split evenly',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, // Reduced from 16
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 20), // Reduced from 40
            
            // Current split info
            _buildCurrentSplitInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSplitInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Current Split',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Participant shares - limit to showing max 4 participants
          ...participants.take(4).map((person) => _buildPersonShare(person, context)),
          
          // Show "View All" button if more than 4 participants
          if (participants.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    // Could show a modal with all participants
                  },
                  icon: const Icon(Icons.people, size: 16),
                  label: Text(
                    '+ ${participants.length - 4} more participants',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonShare(Person person, BuildContext context) {
    final share = personFinalShares[person] ?? 0.0;
    final percentage = getPersonBillPercentage(person) * 100;
    final isBirthdayPerson = birthdayPerson == person;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10), // Reduced from 12
      child: Row(
        children: [
          // Person avatar
          CircleAvatar(
            backgroundColor: person.color,
            radius: 14, // Reduced from 16
            child: Text(
              person.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10, // Reduced from 12
              ),
            ),
          ),
          
          const SizedBox(width: 10), // Reduced from 12
          
          // Person name and special status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14, // Reduced from 15
                  ),
                ),
                if (isBirthdayPerson)
                  Row(
                    children: [
                      Icon(
                        Icons.cake,
                        color: Colors.pink[300],
                        size: 12, // Reduced from 14
                      ),
                      const SizedBox(width: 2), // Reduced from 4
                      Text(
                        'Birthday (pays \$0.00)',
                        style: TextStyle(
                          fontSize: 10, // Reduced from 12
                          color: Colors.pink[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Share amount and percentage
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${share.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Reduced from 16
                  color: isBirthdayPerson ? Colors.grey : Colors.black87,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10, // Reduced from 12
                  color: person.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 6), // Reduced from 8
          
          // Progress bar indicator
          SizedBox(
            height: 30, // Reduced from 36
            width: 4, // Reduced from 6
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.shade200,
                color: person.color,
                minHeight: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}