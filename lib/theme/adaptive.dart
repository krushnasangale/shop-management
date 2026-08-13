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
}
