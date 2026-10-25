import 'package:flutter/services.dart';

/// Talks to the Android "Reading" home screen widget. The widget reads and
/// writes the same saved shelf as the app; this channel only says when to
/// look again.
const _channel = MethodChannel('dev.ionel.manga_companion/widget');

/// Asks the widget to redraw from the saved shelf. Silent where there is no
/// widget support (tests, other platforms).
Future<void> refreshHomeWidget() async {
  try {
    await _channel.invokeMethod<void>('refresh');
  } on MissingPluginException {
    // No native side: nothing to refresh.
  } on PlatformException {
    // The widget is a convenience; never fail a save over it.
  }
}

/// Calls [onChanged] when the widget changes the shelf while the app runs.
void listenForWidgetChanges(void Function() onChanged) {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'shelfChanged') onChanged();
  });
}
