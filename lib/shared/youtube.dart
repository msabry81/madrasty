final _idRe = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// يستخرج معرّف الفيديو من رابط YouTube (watch / youtu.be / embed / shorts / live) أو من المعرّف نفسه.
String? parseYoutubeId(String input) {
  final s = input.trim();
  if (_idRe.hasMatch(s)) return s;
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) return null;

  String? id;
  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  } else if (host.contains('youtube.com') || host.contains('youtube-nocookie.com')) {
    id = uri.queryParameters['v'];
    if (id == null) {
      final seg = uri.pathSegments;
      final i = seg.indexWhere((p) => const {'embed', 'shorts', 'live'}.contains(p));
      if (i >= 0 && i + 1 < seg.length) id = seg[i + 1];
    }
  }
  return (id != null && _idRe.hasMatch(id)) ? id : null;
}
