import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Platform-adaptive helpers: Cupertino on Apple, Material 3 elsewhere.
abstract final class Adaptive {
  static const compactFieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 11,
  );
  static const compactIconSize = 20.0;
  static const compactPrefixConstraints = BoxConstraints(
    minWidth: 42,
    minHeight: 42,
  );

  static bool get isCupertino {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static Widget progress({Color? color}) {
    if (isCupertino) {
      return CupertinoActivityIndicator(color: color);
    }
    return CircularProgressIndicator(color: color, strokeWidth: 2.6);
  }

  static Future<T?> showSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    if (isCupertino) {
      return showCupertinoModalPopup<T>(context: context, builder: builder);
    }
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: builder,
    );
  }

  static InputDecoration compactField({
    required String label,
    String? hint,
    IconData? icon,
    String? errorText,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: icon == null ? null : Icon(icon, size: compactIconSize),
      prefixIconConstraints: icon == null ? null : compactPrefixConstraints,
      contentPadding: compactFieldPadding,
    );
  }

  static ButtonStyle get compactFilled => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(46),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static ButtonStyle get compactOutlined => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 42),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static ButtonStyle get compactIconButton => IconButton.styleFrom(
    minimumSize: const Size(48, 48),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    iconSize: 32,
  );

  static Widget searchField({
    required TextEditingController controller,
    required String hint,
    required String query,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: CupertinoSearchTextField(
        controller: controller,
        placeholder: hint,
        padding: compactFieldPadding,
        itemSize: compactIconSize,
        autofocus: true,
        prefixIcon: const Icon(CupertinoIcons.search),
        suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill),
      ),
    );
  }

  static Widget fullWidthGroup({
    required BuildContext context,
    required List<Widget> children,
  }) {
    if (isCupertino) {
      return CupertinoListSection(margin: EdgeInsets.zero, children: children);
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: isLight ? Colors.white : const Color(0xFF171C22),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 8 : 0,
                bottom: i == children.length - 1 ? 8 : 0,
              ),
              child: children[i],
            ),
            if (i != children.length - 1) const Divider(height: 1, indent: 64),
          ],
        ],
      ),
    );
  }

  /// Sits at the bottom of the screen when content is short, and after the
  /// preceding slivers when the page is taller than the viewport.
  static Widget sliverBottomAction({required Widget child}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [SizedBox(width: double.infinity, child: child)],
          ),
        ),
      ),
    );
  }
}
