import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/core/design/app_icons.dart';
import 'package:spending_tracker/data/voice_playback.dart';
import 'package:spending_tracker/domain/models.dart';
import 'package:spending_tracker/features/transactions/widgets/attachment_strip.dart';

class FakeVoicePlayback implements VoicePlayback {
  final opened = <String>[];
  final calls = <String>[];
  final _positions = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  bool disposed = false;

  @override
  Future<Duration?> open(File file) async {
    opened.add(file.path);
    return const Duration(seconds: 4);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async => calls.add('seek');

  void emitPosition(Duration d) => _positions.add(d);

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<bool> get playingChanges => _playing.stream;

  @override
  Future<void> dispose() async => disposed = true;
}

/// A player whose file will not open, as with a missing recording.
class _BrokenPlayback extends FakeVoicePlayback {
  @override
  Future<Duration?> open(File file) async => throw StateError('no file');
}

final _created = DateTime(2026, 9, 20);

Future<void> _pump(
  WidgetTester tester,
  List<AttachmentView> attachments, {
  VoicePlayback Function()? playback,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ListView(
            children: [
              AttachmentStrip(
                attachments: attachments,
                resolveFile: (path) async => File('/nowhere/$path'),
                playbackFactory: playback ?? FakeVoicePlayback.new,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows nothing when there are no attachments', (tester) async {
    await _pump(tester, const []);
    expect(find.byKey(const Key('attachment-strip')), findsNothing);
  });

  testWidgets('a text note shows as a card', (tester) async {
    await _pump(tester, [
      AttachmentView(
        id: 't',
        kind: AttachmentKind.text,
        text: 'مع أحمد',
        createdAt: _created,
      ),
    ]);
    expect(find.byKey(const Key('attachment-text-t')), findsOneWidget);
    expect(find.text('مع أحمد'), findsOneWidget);
  });

  testWidgets('a PDF shows as a card with the name it was picked by',
      (tester) async {
    await _pump(tester, [
      AttachmentView(
        id: 'f',
        kind: AttachmentKind.file,
        path: 'attachments/2026-09/123.pdf',
        text: 'Invoice 12.pdf',
        createdAt: _created,
      ),
      AttachmentView(
        id: 'g',
        kind: AttachmentKind.file,
        path: 'attachments/2026-09/456.pdf',
        createdAt: _created,
      ),
    ]);
    expect(find.byKey(const Key('attachment-file-f')), findsOneWidget);
    expect(find.text('Invoice 12.pdf'), findsOneWidget);
    // With no name kept, the stored file name stands in.
    expect(find.text('456.pdf'), findsOneWidget);
  });

  testWidgets('photos form a gallery that opens full screen with zoom', (
    tester,
  ) async {
    await _pump(tester, [
      AttachmentView(
        id: 'p1',
        kind: AttachmentKind.photo,
        path: 'a.jpg',
        createdAt: _created,
      ),
      AttachmentView(
        id: 'p2',
        kind: AttachmentKind.photo,
        path: 'b.jpg',
        createdAt: _created,
      ),
    ]);
    expect(find.byKey(const Key('photo-gallery')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-viewer')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);

    await tester.tap(find.byKey(const Key('photo-viewer-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-viewer')), findsNothing);
  });

  testWidgets('a voice note plays with its position, duration and transcript', (
    tester,
  ) async {
    final playback = FakeVoicePlayback();
    await _pump(tester, [
      AttachmentView(
        id: 'v',
        kind: AttachmentKind.voice,
        path: 'attachments/2026-09/v.m4a',
        transcript: 'اتنين كيلو طماطم',
        durationMs: 4200,
        createdAt: _created,
      ),
    ], playback: () => playback);
    expect(find.text('اتنين كيلو طماطم'), findsOneWidget);
    expect(find.text('0:00 / 0:04'), findsOneWidget);
    // Nothing touches the player until play is tapped.
    expect(playback.opened, isEmpty);

    await tester.tap(find.byKey(const Key('voice-play-v')));
    await tester.pump();
    expect(playback.opened, ['/nowhere/attachments/2026-09/v.m4a']);
    expect(playback.calls, ['play']);
    expect(find.byIcon(AppIcons.pause), findsOneWidget);

    playback.emitPosition(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('0:02 / 0:04'), findsOneWidget);

    await tester.tap(find.byKey(const Key('voice-play-v')));
    await tester.pump();
    expect(playback.calls.last, 'pause');

    await tester.pumpWidget(const SizedBox());
    expect(playback.disposed, isTrue);
  });

  testWidgets('a voice note that fails to open is retried on the next tap', (
    tester,
  ) async {
    final made = <FakeVoicePlayback>[];
    await _pump(
      tester,
      [
        AttachmentView(
          id: 'v',
          kind: AttachmentKind.voice,
          path: 'attachments/2026-09/v.m4a',
          createdAt: _created,
        ),
      ],
      playback: () {
        final p = made.isEmpty ? _BrokenPlayback() : FakeVoicePlayback();
        made.add(p);
        return p;
      },
    );
    await tester.tap(find.byKey(const Key('voice-play-v')));
    await tester.pump();
    expect(find.text('مش قادر أشغل التسجيل ده'), findsOneWidget);
    expect(made.first.disposed, isTrue);
    expect(made.first.calls, isEmpty);

    await tester.tap(find.byKey(const Key('voice-play-v')));
    await tester.pump();
    expect(made, hasLength(2));
    expect(made.last.opened, ['/nowhere/attachments/2026-09/v.m4a']);
    expect(made.last.calls, ['play']);
  });
}
