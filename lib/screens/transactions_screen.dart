import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class TransactionsScreen extends StatefulWidget {
  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<dynamic> transactions = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    // Check if widget is still mounted before setting state
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await ApiService.getTransactions();

      // Check if widget is still mounted before setting state
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          transactions = result['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          error = result['error'] ?? 'Failed to load transactions';
          isLoading = false;
        });
      }
    } catch (e) {
      // Check if widget is still mounted before setting state
      if (!mounted) return;

      setState(() {
        error = 'Connection error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (transactions.isEmpty) {
      return const Center(
        child: Text('No transactions found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return TransactionCard(transaction: transaction);
        },
      ),
    );
  }
}

class TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionCard({Key? key, required this.transaction})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _buildTransactionTitle(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(transaction['status']),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction['status'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Customer', transaction['name'] ?? 'N/A'),
            _buildInfoRow('Email', transaction['email'] ?? 'N/A'),
            if (transaction['phone'] != null)
              _buildInfoRow('Phone', transaction['phone']),
            _buildInfoRow('Property', transaction['property_title'] ?? 'N/A'),
            _buildInfoRow('ETH Amount', '${transaction['eth_amount']} ETH'),
            _buildInfoRow('TX Hash', _formatTxHash(transaction['tx_hash'])),
            if (transaction['created_at'] != null)
              _buildInfoRow('Date',
                  dateFormat.format(DateTime.parse(transaction['created_at']))),
          ],
        ),
      ),
    );
  }

  String _buildTransactionTitle() {
    final transactionId = transaction['Id_transaksi'];

    // Jika ID transaksi null atau kosong, hanya tampilkan "Transaction"
    if (transactionId == null || transactionId.toString().isEmpty) {
      return 'Transaction';
    }

    // Jika ID transaksi ada, tampilkan dengan format "Transaction #ID"
    return 'Transaction #$transactionId';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTxHash(String? txHash) {
    if (txHash == null || txHash.isEmpty) return 'N/A';
    if (txHash.length > 20) {
      return '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 10)}';
    }
    return txHash;
  }
}
