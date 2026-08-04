import 'package:flutter/services.dart';

const _channel = MethodChannel('dev.ionel.manga_companion/export');

/// Opens the system "create document" picker, starting in Downloads, and
/// writes [content] to whatever location the user picks.
///
/// Returns the saved file's display name, or null when the picker is dismissed.
Future<String?> saveTextFile({
  required String fileName,
  required String content,
  String mimeType = 'application/octet-stream',
}) {
  return _channel.invokeMethod<String>('saveFile', <String, String>{
    'fileName': fileName,
    'content': content,
    'mimeType': mimeType,
  });
}
