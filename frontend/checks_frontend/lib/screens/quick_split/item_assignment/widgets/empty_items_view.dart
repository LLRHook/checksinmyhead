import 'package:flutter/material.dart';
import '/models/person.dart';

class EmptyItemsView extends StatelessWidget {
  final List<Person> participants;
  final Map<Person, double> personFinalShares;
  final Person? birthdayPerson;
  final double unassignedAmount;
  final Function(Person) getPersonBillPercentage;

  const EmptyItemsView({
    Key? key,
    required this.participants,
    required this.personFinalShares,
    required this.birthdayPerson,
    required this.unassignedAmount,
    required this.getPersonBillPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEvenSplitCard(context),
          const SizedBox(height: 24),
          _buildProTipCard(context),
          const SizedBox(height: 16),
          if (birthdayPerson != null) _buildBirthdayCard(context),
        ],
      ),
    );
  }

  Widget _buildEvenSplitCard(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.splitscreen,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Splitting bill evenly',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Since no items were added, the bill will be split evenly among ${birthdayPerson != null ? 'all participants except ${birthdayPerson!.name}' : 'all participants'}.',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Each person pays:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            // Show each person's share
            ...participants.map(
              (person) => _buildPersonShareItem(context, person),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonShareItem(BuildContext context, Person person) {
    final shareAmount = personFinalShares[person] ?? 0.0;
    final sharePercentage = getPersonBillPercentage(person) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: person.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: person.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: person.color,
            radius: 20,
            child: Text(
              person.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sharePercentage.toStringAsFixed(1)}% of total bill',
                  style: TextStyle(fontSize: 12, color: person.color),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: person.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '\$${shareAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: birthdayPerson == person ? Colors.green : person.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProTipCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: Colors.blue.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pro Tip',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Next time, try adding individual items to assign them to specific people for more precise splitting.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (unassignedAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.edit),
                label: const Text('Add Items Now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBirthdayCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pink.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.pink.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cake, color: Colors.pink, size: 24),
          ),
        ],
      ),
    );
  }
}
