import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/l10n/app_localizations.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.selectLanguage ?? 'Select Language'),
      ),
      body: ListView.builder(
        itemCount: languageProvider.supportedLanguages.length,
        itemBuilder: (context, index) {
          final language = languageProvider.supportedLanguages[index];
          final languageCode = language['code']!;
          final languageName = language['name']!;
          final nativeName = language['nativeName']!;
          final isSelected =
              languageProvider.currentLocale.languageCode == languageCode;

          return ListTile(
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Theme.of(context).primaryColor : null,
            ),
            title: Text(
              nativeName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 18,
              ),
            ),
            subtitle: Text(languageName),
            trailing: isSelected
                ? Icon(Icons.done, color: Theme.of(context).primaryColor)
                : null,
            onTap: () async {
              await languageProvider.changeLanguage(languageCode);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          );
        },
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
