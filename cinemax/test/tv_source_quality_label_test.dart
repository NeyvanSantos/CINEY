import 'package:cinemax/features/details/presentation/widgets/server_selection_sheet.dart';
import 'package:cinemax/plugin_engine/models/content_item.dart';
import 'package:cinemax/plugin_engine/runtime/stream_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unresolved providers do not promise a resolution', () {
    final sources = StreamResolverService.resolveFromContentId(
      'tmdb_809_movie',
    );
    for (final source in sources) {
      expect(source.quality, isNot(matches(RegExp(r'\d{3,4}p'))));
    }
  });

  testWidgets(
    'TV source selector stays honest and preserves remote selection',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSelectionSheet(
              item: const ContentDetail(
                id: 'tmdb_809_movie',
                title: 'Shrek 2',
                posterUrl: '',
                type: ContentType.movie,
                pluginId: 'test',
              ),
              sources: StreamResolverService.resolveFromContentId(
                'tmdb_809_movie',
              ),
              isTv: true,
              onSelect: (index) => selected = index,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('1080p'), findsNothing);
      expect(find.textContaining('Conforme a fonte'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(selected, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
