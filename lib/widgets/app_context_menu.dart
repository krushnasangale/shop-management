import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

class AppContextMenuItem {
  const AppContextMenuItem({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;
  final bool selected;
}

abstract final class AppContextMenu {
  static const double width = 180;

  static Future<void> show({
    required BuildContext buttonContext,
    required List<AppContextMenuItem> items,
    double width = AppContextMenu.width,
  }) async {
    if (items.isEmpty) return;

    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final button = buttonContext.findRenderObject() as RenderBox;
    final offset = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;
    final screen = overlay.size;
    final menuHeight = items.length * 43.0 + (items.length - 1) * 0.5;

    var left = offset.dx + buttonSize.width - width;
    left = left.clamp(16.0, screen.width - width - 16.0);

    var top = offset.dy + buttonSize.height + 4;
    if (top + menuHeight > screen.height - 24) {
      top = offset.dy - menuHeight - 4;
    }

    await showGeneralDialog<void>(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      pageBuilder: (dialogContext, animation, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(dialogContext),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: FadeTransition(
                opacity: animation,
                child: Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 10,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: width,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0)
                                Container(
                                  height: 0.5,
                                  color: CupertinoColors.separator.resolveFrom(
                                    dialogContext,
                                  ),
                                ),
                              CupertinoContextMenuAction(
                                isDefaultAction: items[i].selected,
                                isDestructiveAction: items[i].destructive,
                                trailingIcon: items[i].icon,
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  items[i].onPressed();
                                },
                                child: Text(
                                  items[i].label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget iconButton({
    required List<AppContextMenuItem> Function() items,
    IconData icon = Icons.more_vert,
    String? tooltip,
    EdgeInsetsGeometry padding = const EdgeInsets.all(8),
    ButtonStyle? style,
    double width = AppContextMenu.width,
  }) {
    return Builder(
      builder: (buttonContext) {
        return IconButton(
          padding: padding,
          style: style,
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: () =>
              show(buttonContext: buttonContext, items: items(), width: width),
        );
      },
    );
  }
}
