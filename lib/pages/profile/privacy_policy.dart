import 'package:material_ui/material_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

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
              'Last Updated: September 25, 2026',
              style: context.subtitleSmall,
            ),
            const SizedBox(height: 24),

            _buildSection(
              context,
              'Introduction',
              'FlashBill is a shop management app for billing, stock, purchases, expenses, and daily shop work. This Privacy Policy explains that we do not collect your information, that the app has no payments, and how FlashBill works.',
            ),

            _buildSection(
              context,
              'We Do Not Collect Information',
              'FlashBill does not collect personal information from you. We do not gather, store, sell, rent, or share your data for advertising, marketing, analytics, or any other purpose.',
            ),
            _buildBulletPoint(
              context,
              'We do not collect your name, phone number, location, contacts, photos, or payment details.',
            ),
            _buildBulletPoint(
              context,
              'We do not track how you use the app, and we do not use advertising or tracking SDKs.',
            ),
            _buildBulletPoint(
              context,
              'Anything you type in the app (shop name, products, bills, customers) stays for your own shop use. We do not use it.',
            ),
            _buildBulletPoint(
              context,
              'Sign-in with email or Google is only so you can open your shop in the app. We do not use that account for any other purpose.',
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'No Payments in the App',
              'FlashBill has no payments, purchases, subscriptions, or in-app billing.',
            ),
            _buildBulletPoint(
              context,
              'You never pay inside the app. There is no checkout, card, UPI, wallet, or subscription screen.',
            ),
            _buildBulletPoint(
              context,
              'Bills and pending-payment screens are only for your shop records. They are not payments to FlashBill.',
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'Permissions',
              'FlashBill asks for only one permission: notifications.',
            ),
            _buildBulletPoint(
              context,
              'Notifications are optional. You can allow or skip them during onboarding, and you can still use every feature if you decline.',
            ),
            _buildBulletPoint(
              context,
              'If you allow notifications, we may send alerts for low stock, pending payments, and daily shop updates.',
            ),
            _buildBulletPoint(
              context,
              'We do not ask for contacts, camera, location, microphone, or storage as a condition of using the app.',
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'App Functionality',
              'FlashBill is a shop tool. These are the features you can use:',
            ),
            _buildBulletPoint(
              context,
              'Account: Sign in with email and password or Continue with Google. Sign out and change password from Profile.',
            ),
            _buildBulletPoint(
              context,
              'Onboarding: Short welcome slides, then an optional notification allow step.',
            ),
            _buildBulletPoint(
              context,
              'Dashboard: Products, quantity, total stock value, sales, and profit for a selected month and year.',
            ),
            _buildBulletPoint(
              context,
              'Products: Add and manage product names, units, stock, and availability.',
            ),
            _buildBulletPoint(
              context,
              'Bills: Create bills, review details, view past bills, and share or save a bill as PDF.',
            ),
            _buildBulletPoint(
              context,
              'Purchases: Record purchase entries and keep a purchase list.',
            ),
            _buildBulletPoint(
              context,
              'Expenses: Track shop expenses when this option is turned on in App Settings.',
            ),
            _buildBulletPoint(
              context,
              'Customers and suppliers: Keep customer and supplier lists for billing and purchases.',
            ),
            _buildBulletPoint(
              context,
              'Pending payments and previous due: See unpaid bills and record dues when those options are enabled.',
            ),
            _buildBulletPoint(
              context,
              'Shop profile: Shop name, address, owner details, country, and currency. Country and currency can be set once.',
            ),
            _buildBulletPoint(
              context,
              'App settings: Language, theme, and optional fields such as vehicle number, delivery charges, expiry date, previous due, and expenses.',
            ),
            _buildBulletPoint(
              context,
              'Logged-in devices: See devices that have opened your account.',
            ),

            const SizedBox(height: 16),

            _buildSection(
              context,
              'Sharing',
              'We do not share, sell, or transfer any information. There is nothing for us to share because we do not collect your information.',
            ),

            _buildSection(
              context,
              'Children\'s Privacy',
              'FlashBill is for shop owners and staff. It is not directed at children under 13, and we do not collect information from children.',
            ),

            _buildSection(
              context,
              'Changes to This Privacy Policy',
              'We may update this page if the app changes. The "Last Updated" date at the top will change when we do. Continued use of the app means you accept the updated policy.',
            ),

            _buildSection(
              context,
              'Contact Us',
              'If you have questions about this Privacy Policy or FlashBill, contact us at:',
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
                  InkWell(
                    onTap: () => launchUrl(
                      Uri(
                        scheme: 'mailto',
                        path: 'krushnasangale7447@gmail.com',
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Email: krushnasangale7447@gmail.com',
                            style: context.bodyMediumText?.copyWith(
                              color: Colors.blue[700],
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                '© 2026 FlashBill. All rights reserved.',
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
