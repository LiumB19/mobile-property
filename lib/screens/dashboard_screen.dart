import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'properties_screen.dart';
import 'transactions_screen.dart';
import 'add_property_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? userData;

  final List<Widget> _screens = [
    DashboardHome(),
    PropertiesScreen(),
    TransactionsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  _loadUserData() async {
    final data = await AuthService.getUserData();
    setState(() {
      userData = data;
    });
  }

  void _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Admin'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Properties',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Transactions',
          ),
        ],
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  @override
  _DashboardHomeState createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  Map<String, dynamic>? dashboardStats;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await ApiService.getDashboardStats();

      if (response['success']) {
        setState(() {
          dashboardStats = response['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          error = response['error'] ?? 'Failed to load dashboard stats';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _navigateToAddProperty() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPropertyScreen()),
    );

    // Refresh dashboard stats jika property berhasil ditambahkan
    if (result == true) {
      _loadDashboardStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Loading atau Error State
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Error: $error',
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadDashboardStats,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (dashboardStats != null) ...[
              // Stats Cards - Only Total Properties and Total Transactions
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Properties',
                      value: '${dashboardStats!['totalProperties'] ?? 0}',
                      icon: Icons.home,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Transactions',
                      value: '${dashboardStats!['totalTransactions'] ?? 0}',
                      icon: Icons.receipt,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Add Property Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navigateToAddProperty,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Property Baru'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recent Transactions
              if (dashboardStats!['recentTransactions'] != null &&
                  (dashboardStats!['recentTransactions'] as List)
                      .isNotEmpty) ...[
                const Text(
                  'Transaksi Terbaru',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      for (var transaction
                          in (dashboardStats!['recentTransactions'] as List)
                              .take(5))
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Icon(
                              Icons.receipt,
                              color: Colors.green.shade700,
                            ),
                          ),
                          title: Text(
                            transaction['property_title'] ?? 'Unknown Property',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${transaction['name']} - ${transaction['email']}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${transaction['eth_amount']} ETH',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                transaction['status'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: transaction['status'] == 'Completed'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.trending_up, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
