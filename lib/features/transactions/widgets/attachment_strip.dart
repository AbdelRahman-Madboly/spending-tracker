import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../data/voice_playback.dart';
import '../../../domain/models.dart';

/// Resolves an attachment's stored relative path to the file it is now.
typedef ResolveAttachmentFile = Future<File> Function(String relativePath);

/// The top of the entry detail sheet (spec §4.4): a swipeable photo
/// gallery that opens full screen with pinch zoom, a play bar and the
/// transcript for each voice note, and a card for each text note. Draws
/// nothing when there are no attachments.
class AttachmentStrip extends StatelessWidget {
  final List<AttachmentView> attachments;
  final ResolveAttachmentFile resolveFile;
  final VoicePlayback Function() playbackFactory;

  const AttachmentStrip({
    super.key,
    required this.attachments,
    required this.resolveFile,
    required this.playbackFactory,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final photos = [
      for (final a in attachments)
        if (a.kind == AttachmentKind.photo && a.path != null) a,
    ];
    return Column(
      key: const Key('attachment-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photos.isNotEmpty)
          PhotoGallery(photos: photos, resolveFile: resolveFile),
        for (final a in attachments)
          if (a.kind == AttachmentKind.voice)
            VoiceNoteBar(
              key: Key('voice-${a.id}'),
              attachment: a,
              resolveFile: resolveFile,
              playbackFactory: playbackFactory,
            )
          else if (a.kind == AttachmentKind.text && (a.text ?? '').isNotEmpty)
            _TextNoteCard(attachment: a),
      ],
    );
  }
}

/// An image from a relative path, or a broken-image glyph when the file
/// is missing or unreadable.
class AttachmentImage extends StatelessWidget {
  final String path;
  final ResolveAttachmentFile resolveFile;
  final BoxFit fit;

  const AttachmentImage({
    super.key,
    required this.path,
    required this.resolveFile,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget broken() => Center(
      child: Icon(AppIcons.brokenImage, size: 24, color: palette.outline),
    );
    return FutureBuilder<File>(
      future: resolveFile(path),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return broken();
        return Image.file(
          file,
          fit: fit,
          errorBuilder: (context, error, stack) => broken(),
        );
      },
    );
  }
}

class PhotoGallery extends StatefulWidget {
  final List<AttachmentView> photos;
  final ResolveAttachmentFile resolveFile;

  const PhotoGallery({
    super.key,
    required this.photos,
    required this.resolveFile,
  });

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _page = 0;

  void _open(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(
          photos: widget.photos,
          initialIndex: index,
          resolveFile: widget.resolveFile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.ms),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: SizedBox(
          key: const Key('photo-gallery'),
          height: 200,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: widget.photos.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final photo = widget.photos[index];
                  return Semantics(
                    button: true,
                    label: 'صورة ${index + 1}',
                    child: GestureDetector(
                      key: Key('photo-${photo.id}'),
                      onTap: () => _open(index),
                      child: ColoredBox(
                        color: palette.surfaceAlt,
                        child: AttachmentImage(
                          path: photo.path!,
                          resolveFile: widget.resolveFile,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.photos.length > 1)
                PositionedDirectional(
                  bottom: AppSpacing.sm,
                  end: AppSpacing.sm,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      child: Text(
                        '${_page + 1} / ${widget.photos.length}',
                        textDirection: TextDirection.ltr,
                        style: AppText.caption.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  final List<AttachmentView> photos;
  final int initialIndex;
  final ResolveAttachmentFile resolveFile;

  const _PhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.resolveFile,
  });

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Scaffold(
      key: const Key('photo-viewer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          key: const Key('photo-viewer-close'),
          tooltip: 'إغلاق',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(AppIcons.close),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: photos.length,
        itemBuilder: (context, index) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: AttachmentImage(
              path: photos[index].path!,
              resolveFile: widget.resolveFile,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// `m:ss`, Latin digits.
String formatPlayTime(Duration d) {
  final seconds = d.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// A voice note's play bar (play/pause, position over duration) and its
/// transcript below. The player is created on the first tap, never before.
class VoiceNoteBar extends StatefulWidget {
  final AttachmentView attachment;
  final ResolveAttachmentFile resolveFile;
  final VoicePlayback Function() playbackFactory;

  const VoiceNoteBar({
    super.key,
    required this.attachment,
    required this.resolveFile,
    required this.playbackFactory,
  });

  @override
  State<VoiceNoteBar> createState() => _VoiceNoteBarState();
}

class _VoiceNoteBarState extends State<VoiceNoteBar> {
  VoicePlayback? _playback;
  final _subscriptions = <StreamSubscription<Object>>[];
  bool _playing = false;
  Duration _position = Duration.zero;
  late Duration _duration = Duration(
    milliseconds: widget.attachment.durationMs ?? 0,
  );

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _playback?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final path = widget.attachment.path;
    if (path == null) return;
    var playback = _playback;
    if (playback == null) {
      playback = _playback = widget.playbackFactory();
      _subscriptions
        ..add(
          playback.positions.listen((p) {
            if (mounted) setState(() => _position = p);
          }),
        )
        ..add(
          playback.playingChanges.listen((playing) {
            if (mounted) setState(() => _playing = playing);
          }),
        );
      try {
        final duration = await playback.open(await widget.resolveFile(path));
        if (duration != null && mounted) {
          setState(() => _duration = duration);
        }
      } catch (_) {
        // Drop the player that failed so the next tap opens the file
        // again, rather than playing on a player with nothing loaded.
        for (final s in _subscriptions) {
          s.cancel();
        }
        _subscriptions.clear();
        _playback = null;
        playback.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مش قادر أشغل التسجيل ده')),
          );
        }
        return;
      }
    }
    if (_playing) {
      await playback.pause();
    } else {
      await playback.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final transcript = widget.attachment.transcript;
    final total = _duration.inMilliseconds;
    final progress = total <= 0
        ? 0.0
        : (_position.inMilliseconds / total).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.ms),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filled(
                key: Key('voice-play-${widget.attachment.id}'),
                tooltip: _playing ? 'إيقاف مؤقت' : 'تشغيل',
                onPressed: _toggle,
                icon: Icon(_playing ? AppIcons.pause : AppIcons.play),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: palette.divider,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${formatPlayTime(_position)} / ${formatPlayTime(_duration)}',
                textDirection: TextDirection.ltr,
                style: AppText.caption.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
          if (transcript != null && transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: Text(transcript, style: AppText.body),
            ),
        ],
      ),
    );
  }
}

class _TextNoteCard extends StatelessWidget {
  final AttachmentView attachment;

  const _TextNoteCard({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: Key('attachment-text-${attachment.id}'),
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.ms),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.textNote, size: 20, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(attachment.text!, style: AppText.body)),
        ],
      ),
    );
  }
}
