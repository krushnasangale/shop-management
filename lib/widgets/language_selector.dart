import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/l10n/app_localizations.dart';

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String? _tempSelectedLanguage;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
    // Initialize with current language
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    _tempSelectedLanguage = languageProvider.currentLocale.languageCode;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Language emoji icons
  String _getLanguageEmoji(String code) {
    // switch (code) {
    //   case 'en':
    //     return '🇮🇳';
    //   case 'hi':
    //     return '🇮🇳';
    //   case 'mr':
    //     return '🇮🇳';
    //   default:
    //     return '🌍';
    // }
    return '🇮🇳';
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(localizations?.selectLanguage ?? 'Select Language'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                  ]
                : [
                    theme.primaryColor.withValues(alpha: 0.02),
                    Colors.white.withValues(alpha: 0.5),
                  ],
          ),
        ),
        child: Column(
          children: [
            // Language Cards
            const SizedBox(height: 16),
            Expanded(
              child: FadeTransition(
                opacity: _animationController,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: languageProvider.supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final language = languageProvider.supportedLanguages[index];
                    final languageCode = language['code']!;
                    final languageName = language['name']!;
                    final nativeName = language['nativeName']!;
                    final isSelected = _tempSelectedLanguage == languageCode;
                    final emoji = _getLanguageEmoji(languageCode);

                    return AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final delay = index * 0.1;
                        final animValue = Curves.easeOut.transform(
                          (_animationController.value - delay).clamp(0.0, 1.0),
                        );

                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - animValue)),
                          child: Opacity(opacity: animValue, child: child),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _tempSelectedLanguage = languageCode;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [
                                          theme.primaryColor,
                                          theme.primaryColor.withValues(
                                            alpha: 0.8,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isSelected
                                    ? null
                                    : isDark
                                    ? theme.cardColor
                                    : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? theme.primaryColor.withValues(
                                            alpha: 0.3,
                                          )
                                        : Colors.black.withValues(alpha: 0.05),
                                    blurRadius: isSelected ? 12 : 8,
                                    offset: const Offset(0, 4),
                                    spreadRadius: isSelected ? 2 : 0,
                                  ),
                                ],
                                border: Border.all(
                                  color: isSelected
                                      ? theme.primaryColor.withValues(
                                          alpha: 0.5,
                                        )
                                      : theme.dividerColor.withValues(
                                          alpha: 0.1,
                                        ),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  // Language Emoji/Icon
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : theme.primaryColor.withValues(
                                              alpha: 0.1,
                                            ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Language Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nativeName,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : theme
                                                          .textTheme
                                                          .titleLarge
                                                          ?.color,
                                                fontSize: 20,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          languageName,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: isSelected
                                                    ? Colors.white.withValues(
                                                        alpha: 0.9,
                                                      )
                                                    : theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.color
                                                          ?.withValues(
                                                            alpha: 0.6,
                                                          ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selection Indicator
                                  AnimatedScale(
                                    scale: isSelected ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.elasticOut,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: theme.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                  ),

                                  // Radio button for unselected
                                  if (!isSelected)
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.dividerColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Apply Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isApplying
                        ? null
                        : () async {
                            if (_tempSelectedLanguage == null) return;

                            setState(() => _isApplying = true);

                            await languageProvider.changeLanguage(
                              _tempSelectedLanguage!,
                            );

                            if (context.mounted) {
                              await Future.delayed(
                                const Duration(milliseconds: 300),
                              );
                              Navigator.of(context).pop();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isApplying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            localizations?.apply ?? 'Apply',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget to use in settings or profile page
class LanguageSelectorTile extends StatelessWidget {
  const LanguageSelectorTile({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);
    final currentLanguageCode = languageProvider.currentLocale.languageCode;

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(localizations?.language ?? 'Language'),
      subtitle: Text(
        languageProvider.getNativeLanguageName(currentLanguageCode),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const LanguageSelector()),
        );
      },
    );
  }
}

// Simple dropdown widget for language selection
class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return DropdownButton<String>(
      value: languageProvider.currentLocale.languageCode,
      icon: const Icon(Icons.language),
      underline: Container(),
      items: languageProvider.supportedLanguages.map((language) {
        return DropdownMenuItem<String>(
          value: language['code'],
          child: Row(
            children: [
              Text(language['nativeName']!),
              const SizedBox(width: 8),
              Text(
                '(${language['name']})',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          languageProvider.changeLanguage(newValue);
        }
      },
    );
  }
}
