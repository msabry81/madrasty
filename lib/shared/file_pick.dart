import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PickedFile {
  const PickedFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;

  String get extension {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }
}

/// يفتح نافذة اختيار ملف في المتصفح ويُرجع اسمه ومحتواه.
/// يُرجع null عند إلغاء الاختيار. بديل لحزمة file_picker (لا يعتمد على واجهة حزمة خارجية).
Future<PickedFile?> pickFile({String accept = ''}) {
  final completer = Completer<PickedFile?>();
  final input = (web.document.createElement('input') as web.HTMLInputElement)
    ..type = 'file'
    ..accept = accept;
  input.style.display = 'none';
  web.document.body?.append(input);

  void finish(PickedFile? f) {
    if (!completer.isCompleted) completer.complete(f);
    input.remove();
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        finish(null);
        return;
      }
      final file = files.item(0)!;
      file
          .arrayBuffer()
          .toDart
          .then((buf) {
            finish(PickedFile(file.name, buf.toDart.asUint8List()));
          })
          .catchError((Object e) {
            if (!completer.isCompleted) completer.completeError(e);
            input.remove();
          });
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return completer.future;
}
