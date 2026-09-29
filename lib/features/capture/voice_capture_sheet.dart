import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../domain/voice.dart';
import 'voice_capture_controller.dart';

/// How the recording sheet ended: [phase] is `stopped` with a [result],
/// or `discarded`, `permissionDenied` or `failed` without one.
typedef VoiceSheetEnd = ({VoicePhase phase, VoiceCaptureResult? result});

/// Opens the recording sheet (spec §6.4) and starts [controller] at once:
/// tapping صوت is the start. The sheet owns the controller from here and
/// disposes it.
///
/// Dragging it away is off, and back stops the recording and keeps it: a
/// recording is only thrown away by إلغاء.
Future<VoiceSheetEnd> showVoiceCaptureSheet(
  BuildContext context, {
  required VoiceCaptureController controller,
}) async {
  final end = await showModalBottomSheet<VoiceSheetEnd>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (_) => VoiceCaptureSheet(controller: controller),
  );
  return end ?? (phase: VoicePhase.discarded, result: null);
}

class VoiceCaptureSheet extends StatefulWidget {
  final VoiceCaptureController controller;

  const VoiceCaptureSheet({super.key, required this.controller});

  @override
  State<VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends State<VoiceCaptureSheet> {
  VoiceCaptureController get _c => widget.controller;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _c.onFinished = (result) {
      HapticFeedback.lightImpact();
      _close((phase: VoicePhase.stopped, result: result));
    };
    _c.addListener(_onChange);
    _start();
  }

  Future<void> _start() async {
    await _c.start();
    if (_c.phase == VoicePhase.recording) HapticFeedback.lightImpact();
  }

  void _onChange() {
    final phase = _c.phase;
    if (phase == VoicePhase.permissionDenied || phase == VoicePhase.failed) {
      _close((phase: phase, result: null));
    }
  }

  void _close(VoiceSheetEnd end) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(end);
  }

  Future<void> _discard() async {
    await _c.discard();
    _close((phase: VoicePhase.discarded, result: null));
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.onFinished = null;
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _c.stop();
      },
      child: SafeArea(
        child: Padding(
          key: const Key('voice-sheet'),
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.md),
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _RecordingDot(color: palette.negative),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                        child: Text('بسجّل... قول مصاريفك', style: AppText.title)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  key: const Key('voice-timer'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  textDirection: TextDirection.ltr,
                  children: [
                    Text(formatRecordingTime(_c.elapsed),
                        style: AppText.display
                            .copyWith(color: palette.textPrimary)),
                    Text(' / ${formatRecordingTime(voiceMaxDuration)}',
                        style: AppText.caption
                            .copyWith(color: palette.textSecondary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ExcludeSemantics(
                  child: SizedBox(
                    key: const Key('voice-waveform'),
                    height: 56,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                          levels: _c.levels, color: palette.primary),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ModeLine(mode: _c.mode),
                if (_c.showOfflineHint) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _OfflineHint(online: _c.mode == RecognitionMode.online),
                ],
                const SizedBox(height: AppSpacing.md),
                _Transcript(text: _c.transcript, mode: _c.mode),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    TextButton(
                      key: const Key('voice-cancel'),
                      style: TextButton.styleFrom(
                          minimumSize: const Size(64, 48),
                          foregroundColor: palette.negative),
                      onPressed: _discard,
                      child: const Text('إلغاء'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      key: const Key('voice-stop'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.lg),
                      ),
                      onPressed: _c.phase == VoicePhase.recording
                          ? () => _c.stop()
                          : null,
                      icon: const Icon(AppIcons.stop, size: 24),
                      label: const Text('خلّصت'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  final Color color;
  const _RecordingDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Where the words come from, in one line.
class _ModeLine extends StatelessWidget {
  final RecognitionMode? mode;
  const _ModeLine({required this.mode});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (IconData icon, String text, Key key) = switch (mode) {
      RecognitionMode.online => (
          AppIcons.online,
          'بيتفهم أونلاين',
          const Key('voice-online')
        ),
      RecognitionMode.unavailable => (
          AppIcons.voiceNote,
          'بسجّل الصوت بس، والكلام تكتبه في المراجعة',
          const Key('voice-audio-only')
        ),
      _ => (AppIcons.mic, 'بيتفهم على الموبايل', const Key('voice-on-device')),
    };
    return Row(
      key: key,
      children: [
        Icon(icon, size: 16, color: palette.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(text,
              style: AppText.caption.copyWith(color: palette.textSecondary)),
        ),
      ],
    );
  }
}

/// The one-time hint to install the offline Arabic pack (spec §6.4).
class _OfflineHint extends StatelessWidget {
  final bool online;
  const _OfflineHint({required this.online});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('voice-offline-hint'),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: palette.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.warning, size: 20, color: palette.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              online
                  ? 'الموبايل مفيهوش العربي أوفلاين، فبيتفهم أونلاين. نزّل '
                      'العربي في «التعرف على الكلام من Google» علشان يشتغل من غير نت.'
                  : 'الموبايل مفيهوش العربي أوفلاين. نزّل العربي في «التعرف '
                      'على الكلام من Google» علشان أفهم كلامك من غير نت.',
              style: AppText.caption.copyWith(color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  final String text;
  final RecognitionMode? mode;
  const _Transcript({required this.text, required this.mode});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (mode == RecognitionMode.unavailable) return const SizedBox.shrink();
    final empty = text.isEmpty;
    return Container(
      key: empty ? null : const Key('voice-transcript'),
      constraints: const BoxConstraints(minHeight: 72, maxHeight: 180),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          empty ? 'قول مثلاً: طماطم ب 30 وعيش ب 10' : text,
          style: AppText.body.copyWith(
              color: empty ? palette.textSecondary : palette.textPrimary),
        ),
      ),
    );
  }
}

/// The live level as bars, newest at the right (start) edge, older ones
/// moving left in the reading direction. Live data only, no
/// looping decoration (research notes: "live amplitude only").
class _WaveformPainter extends CustomPainter {
  final List<double> levels;
  final Color color;
  _WaveformPainter({required this.levels, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final slot = size.width / levels.length;
    final bar = slot * 0.6;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bar;
    final mid = size.height / 2;
    for (var i = 0; i < levels.length; i++) {
      final x = size.width - (i + 0.5) * slot;
      final h = (size.height - bar) * levels[levels.length - 1 - i];
      final half = h / 2 < 1 ? 1.0 : h / 2;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.levels != levels || old.color != color;
}
