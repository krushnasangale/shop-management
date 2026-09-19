import 'package:flashbill/theme/adaptive.dart';
import 'package:material_ui/material_ui.dart';

/// Single app-wide loader. Call [show] / [hide] from anywhere.
/// Nested [show] calls reuse the same overlay instead of stacking another.
class AppLoader {
  AppLoader._();

  static final AppLoaderController instance = AppLoaderController();

  static bool get isShowing => instance.isShowing;

  static void show({
    String? message,
    String? detail,
    double? progress,
    String? cancelLabel,
    VoidCallback? onCancel,
  }) {
    instance.show(
      message: message,
      detail: detail,
      progress: progress,
      cancelLabel: cancelLabel,
      onCancel: onCancel,
    );
  }

  static void update({
    String? message,
    String? detail,
    double? progress,
    String? cancelLabel,
    VoidCallback? onCancel,
  }) {
    instance.update(
      message: message,
      detail: detail,
      progress: progress,
      cancelLabel: cancelLabel,
      onCancel: onCancel,
    );
  }

  static void hide() => instance.hide();

  static void hideAll() => instance.hideAll();

  static Future<T> run<T>(
    Future<T> Function() action, {
    String? message,
  }) async {
    show(message: message);
    try {
      return await action();
    } finally {
      hide();
    }
  }

  static Widget indicator({Color? color, double size = 28}) {
    return SizedBox(
      width: size,
      height: size,
      child: Adaptive.progress(color: color),
    );
  }

  static Widget page({Color? color}) {
    return Center(child: indicator(color: color));
  }
}

class AppLoaderController extends ChangeNotifier {
  int _count = 0;
  String? message;
  String? detail;
  double? progress;
  String cancelLabel = 'Cancel';
  VoidCallback? onCancel;

  bool get isShowing => _count > 0;

  void show({
    String? message,
    String? detail,
    double? progress,
    String? cancelLabel,
    VoidCallback? onCancel,
  }) {
    _count++;
    this.message = message ?? this.message;
    this.detail = detail ?? this.detail;
    this.progress = progress ?? this.progress;
    if (cancelLabel != null) this.cancelLabel = cancelLabel;
    this.onCancel = onCancel ?? this.onCancel;
    notifyListeners();
  }

  void update({
    String? message,
    String? detail,
    double? progress,
    String? cancelLabel,
    VoidCallback? onCancel,
  }) {
    if (_count <= 0) return;
    if (message != null) this.message = message;
    if (detail != null) this.detail = detail;
    if (progress != null) this.progress = progress;
    if (cancelLabel != null) this.cancelLabel = cancelLabel;
    if (onCancel != null) this.onCancel = onCancel;
    notifyListeners();
  }

  void hide() {
    if (_count <= 0) return;
    _count--;
    if (_count == 0) {
      message = null;
      detail = null;
      progress = null;
      onCancel = null;
      cancelLabel = 'Cancel';
    }
    notifyListeners();
  }

  void hideAll() {
    if (_count == 0) return;
    _count = 0;
    message = null;
    detail = null;
    progress = null;
    onCancel = null;
    cancelLabel = 'Cancel';
    notifyListeners();
  }
}

/// Mount this once in [MaterialApp.builder]. It is the only loader overlay.
class AppLoaderHost extends StatelessWidget {
  const AppLoaderHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLoader.instance,
      builder: (context, _) {
        return Stack(
          children: [
            child,
            if (AppLoader.instance.isShowing) const _AppLoaderBarrier(),
          ],
        );
      },
    );
  }
}

class _AppLoaderBarrier extends StatelessWidget {
  const _AppLoaderBarrier();

  @override
  Widget build(BuildContext context) {
    final loader = AppLoader.instance;
    final scheme = Theme.of(context).colorScheme;
    final progress = loader.progress;

    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x73000000),
          ),
          Center(
            child: Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLoader.indicator(color: scheme.primary, size: 32),
                      if (loader.message != null &&
                          loader.message!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          loader.message!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (loader.detail != null &&
                          loader.detail!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          loader.detail!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (progress != null) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: scheme.primary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (loader.onCancel != null) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: loader.onCancel,
                          child: Text(loader.cancelLabel),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
