import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/app_currencies.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:material_ui/material_ui.dart';

class CountryCurrencyFields extends StatelessWidget {
  const CountryCurrencyFields({
    super.key,
    required this.countryCode,
    required this.currencyCode,
    required this.onCountrySelected,
    required this.onCurrencySelected,
    this.enabled = true,
    this.submitted = false,
  });

  final String? countryCode;
  final String? currencyCode;
  final ValueChanged<AppCountry> onCountrySelected;
  final ValueChanged<AppCurrency> onCurrencySelected;
  final bool enabled;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final country = countryCode == null || countryCode!.isEmpty
        ? null
        : AppCurrencies.countryByCode(countryCode!);
    final currency = currencyCode == null || currencyCode!.isEmpty
        ? null
        : AppCurrencies.byCode(currencyCode!);
    final countryError = submitted && country == null
        ? (loc?.pleaseSelectCountry ?? 'Please select country')
        : null;
    final currencyError = submitted && currency == null
        ? (loc?.pleaseSelectCurrency ?? 'Please select currency')
        : null;

    return Column(
      children: [
        _PickerField(
          icon: Icons.public_outlined,
          label: loc?.country ?? 'Country',
          value: country?.name,
          hint: loc?.selectCountry ?? 'Select country',
          errorText: countryError,
          enabled: enabled,
          onTap: () => _openCountryPicker(context, loc),
        ),
        const SizedBox(height: 16),
        _PickerField(
          icon: Icons.payments_outlined,
          label: loc?.currency ?? 'Currency',
          value: currency == null
              ? null
              : '${currency.name} (${currency.symbol} ${currency.code})',
          hint: loc?.selectCurrency ?? 'Select currency',
          errorText: currencyError,
          enabled: enabled,
          onTap: () => _openCurrencyPicker(context, loc),
        ),
      ],
    );
  }

  Future<void> _openCountryPicker(
    BuildContext context,
    AppLocalizations? loc,
  ) async {
    final selected = await showSearchPicker<AppCountry>(
      context: context,
      title: loc?.selectCountry ?? 'Select country',
      items: AppCurrencies.countries,
      queryMatcher: AppCurrencies.searchCountries,
      labelOf: (country) => country.name,
    );
    if (selected != null) onCountrySelected(selected);
  }

  Future<void> _openCurrencyPicker(
    BuildContext context,
    AppLocalizations? loc,
  ) async {
    final selected = await showSearchPicker<AppCurrency>(
      context: context,
      title: loc?.selectCurrency ?? 'Select currency',
      items: AppCurrencies.currencies,
      queryMatcher: AppCurrencies.searchCurrencies,
      labelOf: (currency) =>
          '${currency.name} (${currency.symbol} ${currency.code})',
    );
    if (selected != null) onCurrencySelected(selected);
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.value,
    this.errorText,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String? value;
  final String? errorText;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-${value ?? ''}'),
      readOnly: true,
      enabled: enabled,
      canRequestFocus: false,
      enableInteractiveSelection: false,
      onTap: enabled ? onTap : null,
      initialValue: value ?? '',
      decoration: Adaptive.compactField(
        label: '$label *',
        hint: hint,
        icon: icon,
        errorText: errorText,
      ).copyWith(
        suffixIcon: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: enabled ? onTap : null,
        ),
      ),
    );
  }
}

Future<T?> showSearchPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required List<T> Function(String query) queryMatcher,
  required String Function(T item) labelOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _SearchPickerSheet<T>(
        title: title,
        items: items,
        queryMatcher: queryMatcher,
        labelOf: labelOf,
      );
    },
  );
}

class _SearchPickerSheet<T> extends StatefulWidget {
  const _SearchPickerSheet({
    required this.title,
    required this.items,
    required this.queryMatcher,
    required this.labelOf,
  });

  final String title;
  final List<T> items;
  final List<T> Function(String query) queryMatcher;
  final String Function(T item) labelOf;

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.queryMatcher(_query);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: Adaptive.compactField(
                  label: widget.title,
                  hint: widget.title,
                  icon: Icons.search,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final item = results[index];
                  return ListTile(
                    title: Text(widget.labelOf(item)),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
