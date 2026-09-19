import 'package:flashbill/widgets/app_loader.dart';
import 'package:material_ui/material_ui.dart';

/// Use [AppLoader.show] instead of opening another dialog loader.
Widget commonLoadingIndicator(BuildContext context, {String? message}) {
  return AppLoader.page();
}
