import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  String? _tempSelectedLanguage;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    _tempSelectedLanguage = languageProvider.currentLocale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final loc = AppLocalizations.of(context);
    final title = loc?.selectLanguage ?? 'Select Language';

    if (Adaptive.isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(title)),
        child: SafeArea(child: _buildBody(languageProvider, loc)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildBody(languageProvider, loc),
    );
  }

  Widget _buildBody(LanguageProvider languageProvider, AppLocalizations? loc) {
    final languages = languageProvider.supportedLanguages;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _sectionLabel(loc?.language ?? 'Language'),
              _LanguageGroup(
                children: [
                  for (final language in languages)
                    _LanguageTile(
                      nativeName: language['nativeName']!,
                      name: language['name']!,
                      selected: _tempSelectedLanguage == language['code'],
                      onTap: () {
                        setState(() {
                          _tempSelectedLanguage = language['code'];
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: _isApplying
                  ? Center(child: Adaptive.progress())
                  : Adaptive.isCupertino
                  ? CupertinoButton.filled(
                      onPressed: _apply,
                      child: Text(loc?.apply ?? 'Apply'),
                    )
                  : FilledButton(
                      onPressed: _apply,
                      style: Adaptive.compactFilled,
                      child: Text(loc?.apply ?? 'Apply'),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    if (_tempSelectedLanguage == null || _isApplying) return;
    setState(() => _isApplying = true);
    await context.read<LanguageProvider>().changeLanguage(
      _tempSelectedLanguage!,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _sectionLabel(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LanguageGroup extends StatelessWidget {
  const _LanguageGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (Adaptive.isCupertino) {
      return CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        children: children,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 16),
          ],
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.nativeName,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String nativeName;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final check = selected
        ? Icon(Icons.check, color: scheme.primary, size: 22)
        : const SizedBox(width: 22);

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        title: Text(nativeName),
        subtitle: Text(name),
        trailing: selected
            ? Icon(CupertinoIcons.check_mark, color: scheme.primary)
            : null,
        onTap: onTap,
      );
    }

    return ListTile(
      title: Text(
        nativeName,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(name),
      trailing: check,
      onTap: onTap,
    );
  }
}

class LanguageSelectorTile extends StatelessWidget {
  const LanguageSelectorTile({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final loc = AppLocalizations.of(context);
    final currentLanguageCode = languageProvider.currentLocale.languageCode;

    return ListTile(
      leading: const Icon(Icons.language_outlined),
      title: Text(loc?.language ?? 'Language'),
      subtitle: Text(
        languageProvider.getNativeLanguageName(currentLanguageCode),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        AppNavigator.push(context, const LanguageSelector());
      },
    );
  }
}

class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return DropdownButton<String>(
      value: languageProvider.currentLocale.languageCode,
      icon: const Icon(Icons.language_outlined),
      underline: const SizedBox.shrink(),
      items: languageProvider.supportedLanguages.map((language) {
        return DropdownMenuItem<String>(
          value: language['code'],
          child: Text(language['nativeName']!),
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
