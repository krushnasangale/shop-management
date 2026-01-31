import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flashbill/pages/admin/add_user_page.dart';
import 'package:flashbill/pages/widgets/users_list_widget.dart';
import 'package:flashbill/services/profile_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_OverviewTab(), _UsersTab()],
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late final ProfileService _profileService;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
  }

  @override
  void dispose() {
    _profileService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome to admin panel',
            style: TextStyle(color: secondaryTextColor, fontSize: 14),
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shop-profile')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(color: Colors.blue[600]),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Card(
                  color: Colors.red.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[600],
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final totalUsers = snapshot.data?.docs.length ?? 0;
              return Card(
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Users',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$totalUsers',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.people,
                              size: 48,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(
              bottom: BorderSide(
                color: secondaryTextColor?.withOpacity(0.2) ?? Colors.grey,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Users Management',
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add, edit, and manage user accounts',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddUserPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: UsersListWidget(),
          ),
        ),
      ],
    );
  }
}
