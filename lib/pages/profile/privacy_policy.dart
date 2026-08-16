import 'package:material_ui/material_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.privacyPolicy ?? 'Privacy Policy'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Adaptive.box(
          context: context,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header
            Text(
              loc?.privacyPolicy ?? 'Privacy Policy',
              style: context.headingLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: December 29, 2025',
              style: context.subtitleSmall,
            ),
            const SizedBox(height: 24),

            // Introduction
            _buildSection(
              context,
              'Introduction',
              'FlashBill ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our shop management application.',
            ),

            _buildSection(
              context,
              'Information We Collect',
              'We collect information that you provide directly to us when using FlashBill:',
            ),

            _buildBulletPoint(
              context,
              'Account Information: Email address and shop name',
            ),
            _buildBulletPoint(
              context,
              'Business Data: Product information, supplier details, customer information, purchase records, and inventory data',
            ),
            _buildBulletPoint(
              context,
              'Device Information: Device type, operating system, and unique device identifiers for logged-in device tracking',
            ),
            _buildBulletPoint(
              context,
              'Usage Data: How you interact with the app, features used, and error logs',
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'How We Use Your Information',
              'We use the collected information for the following purposes:',
            ),

            _buildBulletPoint(
              context,
              'To provide, maintain, and improve our services',
            ),
            _buildBulletPoint(
              context,
              'To manage your account and authenticate your identity',
            ),
            _buildBulletPoint(
              context,
              'To store and sync your business data across devices',
            ),

            _buildBulletPoint(
              context,
              'To analyze usage patterns and improve user experience',
            ),
            _buildBulletPoint(
              context,
              'To detect and prevent fraud or security issues',
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'Data Storage and Security',
              'Your data is stored securely using Google Firebase services:',
            ),

            _buildBulletPoint(
              context,
              'All data is encrypted in transit using SSL/TLS',
            ),
            _buildBulletPoint(
              context,
              'Data is stored on secure Firebase Cloud Firestore servers',
            ),
            _buildBulletPoint(
              context,
              'Access to your data is protected by Firebase Authentication',
            ),
            _buildBulletPoint(
              context,
              'We implement industry-standard security measures to protect your information',
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'Data Sharing and Disclosure',
              'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:',
            ),

            _buildBulletPoint(
              context,
              'With service providers (Google Firebase) who help us operate our app',
            ),
            _buildBulletPoint(
              context,
              'When required by law or to protect our legal rights',
            ),
            _buildBulletPoint(context, 'With your explicit consent'),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'Your Data Rights',
              'You have the following rights regarding your data:',
            ),

            _buildBulletPoint(
              context,
              'Access: You can view all your data within the app',
            ),
            _buildBulletPoint(
              context,
              'Correction: You can edit and update your information at any time',
            ),

            _buildBulletPoint(
              context,
              'Export: You can export your data in PDF or CSV format',
            ),
            _buildBulletPoint(
              context,
              'Portability: You can transfer your data to another service',
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'Data Retention',
              'We retain your data for as long as your account is active. Your data is securely stored in Firebase Cloud Firestore and remains accessible across all your logged-in devices.',
            ),

            _buildSection(
              context,
              'Third-Party Services',
              'FlashBill uses the following third-party services:',
            ),

            _buildBulletPoint(
              context,
              'Google Firebase: For authentication, database, and cloud storage',
            ),

            const SizedBox(height: 8),
            Text(
              'These services have their own privacy policies governing their use of your information.',
              style: context.subtitleMedium?.copyWith(height: 1.5),
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'Cookies and Tracking',
              'We do not use cookies or tracking technologies in our mobile application. However, Firebase services may use similar technologies for authentication and analytics purposes.',
            ),

            _buildSection(
              context,
              'Children\'s Privacy',
              'FlashBill is not intended for use by children under the age of 13. We do not knowingly collect personal information from children under 13.',
            ),

            _buildSection(
              context,
              'Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any changes by updating the "Last Updated" date at the top of this policy. Your continued use of the app after such changes constitutes acceptance of the updated policy.',
            ),

            _buildSection(
              context,
              'Contact Us',
              'If you have any questions or concerns about this Privacy Policy or our data practices, please contact us at:',
            ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Email: support@flashbill.com',
                        style: context.bodyMediumText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.business, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'FlashBill - Shop Management',
                          style: context.bodyMediumText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Footer
            Center(
              child: Text(
                '© 2025 FlashBill. All rights reserved.',
                style: context.captionLarge,
              ),
            ),

            const SizedBox(height: 24),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.headingSmall),
          const SizedBox(height: 8),
          Text(content, style: context.subtitleMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: context.subtitleMedium?.copyWith(height: 1.5)),
          Expanded(
            child: Text(
              text,
              style: context.subtitleMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
