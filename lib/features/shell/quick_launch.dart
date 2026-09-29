import 'package:quick_actions/quick_actions.dart';

import '../home/widgets/capture_bar.dart';

/// One launcher quick action (spec §8): what the launcher shows and the
/// type it reports back when picked. [icon] names an Android drawable.
class QuickLaunchItem {
  const QuickLaunchItem(this.type, this.title, this.icon);

  final String type;
  final String title;
  final String icon;
}

/// إضافة، صوت، كاميرا، باركود, in the order the launcher lists them.
const quickLaunchItems = [
  QuickLaunchItem('add', 'إضافة', 'ic_quick_add'),
  QuickLaunchItem('voice', 'صوت', 'ic_quick_mic'),
  QuickLaunchItem('camera', 'كاميرا', 'ic_quick_camera'),
  QuickLaunchItem('barcode', 'باركود', 'ic_quick_barcode'),
];

/// The capture a quick action type starts; null for إضافة (the add
/// sheet, not a capture) and for any type this app does not know.
CaptureAction? quickLaunchCapture(String type) => switch (type) {
      'voice' => CaptureAction.voice,
      'camera' => CaptureAction.camera,
      'barcode' => CaptureAction.barcode,
      _ => null,
    };

/// The launcher seam: the quick_actions plugin talks to a platform
/// channel that does not run under `flutter test`.
abstract class QuickActionsSource {
  /// Registers [items] with the launcher and calls [onLaunch] with the type
  /// of the action the app was started from (cold start) and of every
  /// action picked while it runs (warm start).
  Future<void> start(
    List<QuickLaunchItem> items,
    void Function(String type) onLaunch,
  );
}

class PluginQuickActionsSource implements QuickActionsSource {
  const PluginQuickActionsSource();

  @override
  Future<void> start(
    List<QuickLaunchItem> items,
    void Function(String type) onLaunch,
  ) async {
    const plugin = QuickActions();
    try {
      await plugin.initialize(onLaunch);
      await plugin.setShortcutItems([
        for (final item in items)
          ShortcutItem(
            type: item.type,
            localizedTitle: item.title,
            icon: item.icon,
          ),
      ]);
    } catch (_) {
      // No launcher shortcuts on this platform: the app works the same
      // without them.
    }
  }
}
