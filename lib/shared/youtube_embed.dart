import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final _registered = <String>{};

/// مشغّل YouTube مضمّن (ويب فقط). يستخدم youtube-nocookie.
class YoutubeEmbed extends StatelessWidget {
  const YoutubeEmbed({super.key, required this.videoId});
  final String videoId;

  @override
  Widget build(BuildContext context) {
    final viewType = 'yt-$videoId';
    if (_registered.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final iframe = web.HTMLIFrameElement()
          ..src = 'https://www.youtube-nocookie.com/embed/$videoId?rel=0&modestbranding=1'
          ..allow = 'accelerometer; encrypted-media; picture-in-picture; fullscreen';
        iframe.style
          ..border = 'none'
          ..width = '100%'
          ..height = '100%';
        return iframe;
      });
    }
    return AspectRatio(aspectRatio: 16 / 9, child: HtmlElementView(viewType: viewType));
  }
}
