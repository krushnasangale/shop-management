import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:flashbill/pages/profile/customer/customer_history.dart';

class Customers extends StatefulWidget {
  const Customers({super.key});

  @override
  State<Customers> createState() => _CustomersState();
}

class _CustomersState extends State<Customers> {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _customersSubscription;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _customersSubscription?.cancel();
    super.dispose();
  }

  void _loadCustomers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final database = FirebaseDatabase.instance;
    final customersRef = database.ref('customers/${user.uid}');

    _customersSubscription = customersRef.onValue.listen((event) {
      if (mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final customers = data.entries.map((e) {
            return {
              'id': e.key,
              'name': e.value['name'] ?? '',
              'mobileNumber': e.value['mobileNumber'] ?? '',
              'vehicleNumber': e.value['vehicleNumber'] ?? '',
            };
          }).toList();
          setState(() {
            _customers = customers;
            _isLoading = false;
          });
        } else {
          setState(() {
            _customers = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _deleteCustomer(String customerId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseDatabase.instance
          .ref('customers/${user.uid}/$customerId')
          .remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting customer: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
          ? const Center(child: Text('No customers added yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _customers.length,
              itemBuilder: (context, index) {
                final customer = _customers[index];
                final initials = _getInitials(customer['name']);
                final avatarColor = _getAvatarColor(index);
                return _buildCustomerCard(
                  context,
                  customer,
                  initials,
                  avatarColor,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _getAvatarColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Widget _buildCustomerCard(
    BuildContext context,
    Map<String, dynamic> customer,
    String initials,
    Color avatarColor,
  ) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(
          color: secondaryTextColor!.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 10.0,
          bottom: 0.0,
          left: 10.0,
          right: 10.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Initials Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Customer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer['name'],
                        style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            customer['mobileNumber'],
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            customer['vehicleNumber'].isEmpty
                                ? 'No vehicle'
                                : customer['vehicleNumber'],
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _showCustomerHistory(context, customer),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _showAddEditDialog(context, customer: customer),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                TextButton.icon(
                  onPressed: () => _showDeleteConfirmation(customer),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> customer) async {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Customer',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          content: const Text('Are you sure you want to delete this customer?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteCustomer(customer['id']);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddEditDialog(
    BuildContext context, {
    Map<String, dynamic>? customer,
  }) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final isEditing = customer != null;
    final nameController = TextEditingController(
      text: isEditing ? customer['name'] : '',
    );
    final mobileController = TextEditingController(
      text: isEditing ? customer['mobileNumber'] : '',
    );
    final vehicleController = TextEditingController(
      text: isEditing ? customer['vehicleNumber'] : '',
    );

    String? nameError;
    String? mobileError;
    String? vehicleError;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Customer' : 'Add Customer',
                style: TextStyle(color: primaryTextColor),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name Field
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name*',
                        hintText: 'Enter customer name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: nameError,
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          if (value.isEmpty) {
                            nameError = 'Name is required';
                          } else {
                            nameError = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Mobile Number Field
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number*',
                        hintText: 'Enter mobile number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: mobileError,
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          if (value.isEmpty) {
                            mobileError = 'Mobile number is required';
                          } else if (value.length < 10) {
                            mobileError =
                                'Mobile number must be at least 10 digits';
                          } else {
                            mobileError = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Vehicle Number Field
                    TextField(
                      controller: vehicleController,
                      decoration: InputDecoration(
                        labelText: 'Vehicle Number',
                        hintText: 'Enter vehicle number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: vehicleError,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validate fields
                    bool hasErrors = false;
                    setStateDialog(() {
                      if (nameController.text.isEmpty) {
                        nameError = 'Name is required';
                        hasErrors = true;
                      } else {
                        nameError = null;
                      }

                      if (mobileController.text.isEmpty) {
                        mobileError = 'Mobile number is required';
                        hasErrors = true;
                      } else if (mobileController.text.length < 10) {
                        mobileError =
                            'Mobile number must be at least 10 digits';
                        hasErrors = true;
                      } else {
                        mobileError = null;
                      }

                      vehicleError = null;
                    });

                    if (hasErrors) return;

                    _saveCustomer(
                      nameController.text,
                      mobileController.text,
                      vehicleController.text,
                      customerId: isEditing ? customer['id'] : null,
                    );

                    Navigator.of(context).pop();
                  },
                  child: Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveCustomer(
    String name,
    String mobileNumber,
    String vehicleNumber, {
    String? customerId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final database = FirebaseDatabase.instance;
      final customerData = {
        'name': name,
        'mobileNumber': mobileNumber,
        'vehicleNumber': vehicleNumber,
        'lastUpdated': DateTime.now().toString(),
      };

      if (customerId != null) {
        // Update existing customer
        await database
            .ref('customers/${user.uid}/$customerId')
            .update(customerData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer updated successfully')),
          );
        }
      } else {
        // Add new customer
        await database.ref('customers/${user.uid}').push().set(customerData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer added successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving customer: $e')));
      }
    }
  }

  void _showCustomerHistory(BuildContext context, Map<String, dynamic> customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerHistoryScreen(
          customerId: customer['id'],
          customerName: customer['name'],
          customerMobile: customer['mobileNumber'],
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
      ),
    );
  }
}
