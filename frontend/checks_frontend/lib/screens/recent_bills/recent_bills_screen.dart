// lib/screens/recent_bills/recent_bills_screen.dart
import 'package:flutter/material.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/recent_bill_manager.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/models/recent_bill_model.dart';

// Import components
import 'components/empty_bills_state.dart';
import 'components/bills_list.dart';

class RecentBillsScreen extends StatefulWidget {
  const RecentBillsScreen({super.key});

  @override
  State<RecentBillsScreen> createState() => _RecentBillsScreenState();
}

class _RecentBillsScreenState extends State<RecentBillsScreen> {
  bool _isLoading = true;
  List<RecentBillModel> _bills = [];

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    try {
      final bills = await RecentBillsManager.getRecentBills();
      if (mounted) {
        setState(() {
          _bills = bills;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load recent bills'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Recent Bills',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3,
                ),
              )
              : _bills.isEmpty
              ? const EmptyBillsState()
              : BillsList(bills: _bills, onBillDeleted: _loadBills),
    );
  }
}
