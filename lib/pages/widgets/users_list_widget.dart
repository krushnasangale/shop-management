import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/profile_service.dart';

class UsersListWidget extends StatefulWidget {
  const UsersListWidget({super.key});

  @override
  State<UsersListWidget> createState() => _UsersListWidgetState();
}

class _UsersListWidgetState extends State<UsersListWidget> {
  final ProfileService _profileService = ProfileService();

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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('shop-profile').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.blue[600]),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[600]),
                const SizedBox(height: 12),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: secondaryTextColor),
                ),
              ],
            ),
          );
        }

        final userDocs = snapshot.data?.docs ?? [];

        if (userDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No users added yet',
                  style: TextStyle(color: secondaryTextColor, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: userDocs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final userDoc = userDocs[index];
            final userData = userDoc.data() as Map<String, dynamic>;

            return _buildUserCard(
              context,
              userData,
              userDoc.id,
              cardColor,
              primaryTextColor,
              secondaryTextColor,
            );
          },
        );
      },
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    Map<String, dynamic> userData,
    String userId,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    final shopName = userData['shopName'] ?? 'N/A';
    final email = userData['email'] ?? 'N/A';
    final shopPhone = userData['shopPhone'] ?? 'N/A';
    final isActive = userData['isActive'] ?? true;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header with Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.green[600] : Colors.orange[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contact Info
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: secondaryTextColor),
                const SizedBox(width: 6),
                Text(
                  shopPhone,
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Shop Details
            if (userData['shopAddress'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        userData['shopAddress'] ?? '',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons
            Divider(color: secondaryTextColor?.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildActionButton(
                    label: 'View Details',
                    icon: Icons.visibility,
                    onTap: () => _showUserDetails(context, userData, shopName),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  if (isActive)
                    _buildActionButton(
                      label: 'Deactivate',
                      icon: Icons.block,
                      onTap: () => _deactivateUser(context, userId, shopName),
                      color: Colors.orange,
                    )
                  else
                    _buildActionButton(
                      label: 'Activate',
                      icon: Icons.check_circle,
                      onTap: () => _activateUser(context, userId, shopName),
                      color: Colors.green,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(
    BuildContext context,
    Map<String, dynamic> userData,
    String shopName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shopName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', userData['email'] ?? 'N/A'),
              _buildDetailRow('Phone', userData['shopPhone'] ?? 'N/A'),
              _buildDetailRow('Address', userData['shopAddress'] ?? 'N/A'),
              _buildDetailRow('Owner Name', userData['ownerName'] ?? 'N/A'),
              if (userData['licenseNumber'] != null)
                _buildDetailRow('License', userData['licenseNumber']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _deactivateUser(BuildContext context, String userId, String shopName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text('Are you sure you want to deactivate $shopName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('shop-profile')
                    .doc(userId)
                    .update({'isActive': false});

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User deactivated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _activateUser(BuildContext context, String userId, String shopName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate User'),
        content: Text('Are you sure you want to activate $shopName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('shop-profile')
                    .doc(userId)
                    .update({'isActive': true});

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User activated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }
}
