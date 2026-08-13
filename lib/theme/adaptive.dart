import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Platform-adaptive helpers: Cupertino on Apple, Material 3 elsewhere.
abstract final class Adaptive {
  static const compactFieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
  static const compactIconSize = 20.0;
  static const compactPrefixConstraints = BoxConstraints(
    minWidth: 44,
    minHeight: 44,
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
    minimumSize: const Size.fromHeight(48),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static ButtonStyle get compactOutlined => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  static ButtonStyle get compactIconButton => IconButton.styleFrom(
    minimumSize: const Size(44, 44),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    iconSize: compactIconSize,
  );

  static Widget searchField({
    required TextEditingController controller,
    required String hint,
    required String query,
  }) {
    if (isCupertino) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: CupertinoSearchTextField(
          controller: controller,
          placeholder: hint,
          padding: compactFieldPadding,
          itemSize: compactIconSize,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          contentPadding: compactFieldPadding,
          prefixIcon: const Icon(Icons.search, size: compactIconSize),
          prefixIconConstraints: compactPrefixConstraints,
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: controller.clear,
                )
              : null,
        ),
      ),
    );
  }
}
