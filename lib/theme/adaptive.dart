import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Platform-adaptive helpers: Cupertino on Apple, Material 3 elsewhere.
abstract final class Adaptive {
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
      return showCupertinoModalPopup<T>(
        context: context,
        builder: builder,
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: builder,
    );
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          itemSize: 18,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
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
