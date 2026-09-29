import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/tokens.dart';
import '../../data/barcode_scan_service.dart';
import '../../data/net/network_gate.dart';
import '../../data/net/product_lookup.dart';
import '../../data/photo_capture_service.dart';
import '../../data/document_picker_service.dart';
import '../../data/speech_recognition_service.dart';
import '../../data/text_recognition_service.dart';
import '../../data/voice_playback.dart';
import '../../data/voice_recorder.dart';
import '../../domain/barcode_scan.dart';
import '../../domain/models.dart';
import '../../domain/online_features.dart';
import '../../domain/parsing/line_parser.dart';
import '../../domain/spending_repository.dart';
import '../add/add_sheet.dart';
import '../home/widgets/capture_bar.dart';
import '../review/review_sheet.dart';
import 'text_note_sheet.dart';
import 'voice_capture_controller.dart';
import 'voice_capture_sheet.dart';

/// Opens the add sheet (spec §6.1) as a modal bottom sheet. Saving writes
/// the entry, gives a light haptic and closes the sheet; the dashboard's
/// streams then slide the new row in.
///
/// [initialAction] starts the camera, gallery or scanner as soon as the
/// sheet is up. The services are injectable for widget tests.
Future<void> openAddSheet(
  BuildContext context,
  SpendingRepository repository, {
  AddSheetAction? initialAction,
  PhotoCaptureService? photoCaptureService,
  BarcodeScanService? barcodeScanService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (sheetContext) => AddSheet(
      repository: repository,
      initialAction: initialAction,
      photoCaptureService: photoCaptureService,
      barcodeScanService: barcodeScanService,
      onSubmit: (draft) async {
        await repository.saveEntry(draft);
        HapticFeedback.lightImpact();
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      },
    ),
  );
}

/// Runs one capture bar action. Camera takes a photo and reads it (spec
/// §6.2), voice records and transcribes (spec §6.4) and text takes a typed
/// note (spec §6.5) and barcode scans products (spec §6.3); all four end
/// in the review sheet. The platform services and the [networkGate] are
/// injectable for widget tests.
Future<void> launchCapture(
  BuildContext context,
  SpendingRepository repository,
  CaptureAction action, {
  PhotoCaptureService? photoCaptureService,
  TextRecognitionService? textRecognition,
  DocumentPickerService? documentPicker,
  BarcodeScanService? barcodeScanService,
  NetworkGate? networkGate,
  VoiceRecorder Function()? voiceRecorderFactory,
  SpeechRecognitionService? speechRecognition,
  VoicePlayback Function()? playbackFactory,
  DateTime Function() clock = DateTime.now,
}) async {
  switch (action) {
    case CaptureAction.camera:
      await capturePhoto(
        context,
        repository,
        photoCaptureService: photoCaptureService,
        textRecognition: textRecognition,
        documentPicker: documentPicker,
        playbackFactory: playbackFactory,
        clock: clock,
      );
    case CaptureAction.barcode:
      await captureBarcode(
        context,
        repository,
        scanner: barcodeScanService,
        networkGate: networkGate,
        photoCaptureService: photoCaptureService,
        playbackFactory: playbackFactory,
        clock: clock,
      );
    case CaptureAction.voice:
      await captureVoice(
        context,
        repository,
        recorderFactory: voiceRecorderFactory,
        speechRecognition: speechRecognition,
        photoCaptureService: photoCaptureService,
        playbackFactory: playbackFactory,
        clock: clock,
      );
    case CaptureAction.text:
      await captureText(
        context,
        repository,
        photoCaptureService: photoCaptureService,
        playbackFactory: playbackFactory,
        clock: clock,
      );
  }
}

void _say(BuildContext context, String message, Key key) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(key: key, content: Text(message)));
}

/// Takes a photo (spec §6.2) and reviews what it reads: an InstaPay
/// screenshot's amount, date and reference, a receipt's total or the
/// products on a package. More photos, from the camera or the gallery, and
/// PDFs are added in review. The photo is kept whatever it reads as.
Future<void> capturePhoto(
  BuildContext context,
  SpendingRepository repository, {
  PhotoCaptureService? photoCaptureService,
  TextRecognitionService? textRecognition,
  DocumentPickerService? documentPicker,
  VoicePlayback Function()? playbackFactory,
  DateTime Function() clock = DateTime.now,
}) async {
  final photos = photoCaptureService ?? ImagePickerPhotoCaptureService();
  final capturedAt = clock();
  final PhotoCaptureResult result;
  try {
    result = await photos.captureFromCamera();
  } catch (_) {
    // A camera already in use, or no camera app to take the picture.
    if (context.mounted) {
      _say(context, 'ما قدرتش أفتح الكاميرا، جرب تاني',
          const Key('photo-failed'));
    }
    return;
  }
  if (!context.mounted) return;
  if (result.outcome == PhotoCaptureOutcome.permissionDenied) {
    _say(context, 'محتاج إذن الكاميرا عشان أصور. اسمح بيه من إعدادات التطبيق.',
        const Key('photo-permission-denied'));
    return;
  }
  final path = result.relativePath;
  if (path == null) return;
  await showReviewSheet(
    context,
    repository: repository,
    request: ReviewRequest(
      kind: CaptureKind.photo,
      capturedAt: capturedAt,
      attachments: [DraftAttachment(kind: AttachmentKind.photo, path: path)],
    ),
    clock: clock,
    photoCaptureService: photos,
    textRecognition: textRecognition,
    documentPicker: documentPicker,
    playbackFactory: playbackFactory,
  );
}

/// Scans products one after another (spec §6.3) and reviews them: a code
/// the app knows is its item at its last price, and any other is a product
/// to name, which learns the code when saved. With the barcode lookup
/// switched on, an unknown code is first looked up on Open Food Facts
/// through [networkGate] for its name.
Future<void> captureBarcode(
  BuildContext context,
  SpendingRepository repository, {
  BarcodeScanService? scanner,
  NetworkGate? networkGate,
  PhotoCaptureService? photoCaptureService,
  VoicePlayback Function()? playbackFactory,
  DateTime Function() clock = DateTime.now,
}) async {
  final capturedAt = clock();
  final codes =
      await (scanner ?? MobileScannerBarcodeScanService()).scanMany(context);
  if (codes.isEmpty || !context.mounted) return;
  final ProductLookup? lookup =
      await isOnlineFeatureOn(repository, OnlineFeature.productLookup)
          ? OpenFoodFactsLookup(
              networkGate ?? NetworkGate(repository), repository,
              clock: clock)
          : null;
  if (lookup != null && context.mounted) {
    _say(context, 'بدوّر على أسماء المنتجات…',
        const Key('barcode-looking-up'));
  }
  final lines = await barcodeLines(
    codes,
    repository: repository,
    day: ArabicLineParser.captureDay(capturedAt),
    nameFor: lookup?.nameFor,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  await showReviewSheet(
    context,
    repository: repository,
    request: ReviewRequest(
      kind: CaptureKind.barcode,
      capturedAt: capturedAt,
      lines: lines,
    ),
    clock: clock,
    photoCaptureService: photoCaptureService,
    playbackFactory: playbackFactory,
  );
}

/// Records a voice note (spec §6.4), then reviews what was heard with the
/// audio attached. When nothing was heard (no recogniser the capture may
/// use) the review asks for the words to be typed, and closing it keeps
/// the audio as a draft in Needs review.
Future<void> captureVoice(
  BuildContext context,
  SpendingRepository repository, {
  VoiceRecorder Function()? recorderFactory,
  SpeechRecognitionService? speechRecognition,
  PhotoCaptureService? photoCaptureService,
  VoicePlayback Function()? playbackFactory,
  DateTime Function() clock = DateTime.now,
}) async {
  final capturedAt = clock();
  final end = await showVoiceCaptureSheet(
    context,
    controller: VoiceCaptureController(
      recorder: (recorderFactory ?? RecordVoiceRecorder.new)(),
      speech: speechRecognition ?? SpeechToTextRecognitionService(),
      repository: repository,
      clock: clock,
    ),
  );
  if (!context.mounted) return;
  switch (end.phase) {
    case VoicePhase.permissionDenied:
      _say(context, 'محتاج إذن الميكروفون علشان أسجل. اسمح بيه من إعدادات التطبيق.',
          const Key('voice-permission-denied'));
      return;
    case VoicePhase.failed:
      _say(context, 'الميكروفون مش متاح دلوقتي، جرب تاني',
          const Key('voice-failed'));
      return;
    case VoicePhase.stopped:
      break;
    case VoicePhase.idle:
    case VoicePhase.recording:
    case VoicePhase.discarded:
      return;
  }
  final result = end.result!;
  final transcript = result.transcript.trim();
  final audioPath = result.audioPath;
  if (audioPath == null && transcript.isEmpty) {
    _say(context, 'ما اتسجلش حاجة', const Key('voice-empty'));
    return;
  }
  await showReviewSheet(
    context,
    repository: repository,
    request: ReviewRequest(
      kind: CaptureKind.voice,
      capturedAt: capturedAt,
      rawText: transcript.isEmpty ? null : transcript,
      attachments: [
        if (audioPath != null)
          DraftAttachment(
            kind: AttachmentKind.voice,
            path: audioPath,
            transcript: transcript.isEmpty ? null : transcript,
            durationMs: result.durationMs,
          ),
      ],
    ),
    clock: clock,
    photoCaptureService: photoCaptureService,
    playbackFactory: playbackFactory,
  );
}

/// Takes a typed note (spec §6.5) and reviews it through the parser. A
/// note closed before review is kept as a draft rather than lost.
Future<void> captureText(
  BuildContext context,
  SpendingRepository repository, {
  PhotoCaptureService? photoCaptureService,
  VoicePlayback Function()? playbackFactory,
  DateTime Function() clock = DateTime.now,
}) async {
  final capturedAt = clock();
  var typed = '';
  final text = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (_) => TextNoteSheet(onChanged: (t) => typed = t),
  );
  if (!context.mounted) return;
  if (text != null) {
    await showReviewSheet(
      context,
      repository: repository,
      request: ReviewRequest(
          kind: CaptureKind.text, capturedAt: capturedAt, rawText: text),
      clock: clock,
      photoCaptureService: photoCaptureService,
      playbackFactory: playbackFactory,
    );
    return;
  }
  final kept = typed.trim();
  if (kept.isEmpty) return;
  try {
    await repository.saveCapture(CaptureDraft(
      kind: CaptureKind.text,
      date: ArabicLineParser.captureDay(capturedAt),
      rawText: kept,
      lines: const [],
      isDraft: true,
    ));
    if (context.mounted) {
      _say(context, 'الملاحظة مستنياك في «محتاج مراجعة»',
          const Key('text-note-kept'));
    }
  } catch (_) {
    if (context.mounted) {
      _say(context, 'ما قدرتش أحتفظ بالملاحظة، جرب تاني',
          const Key('text-note-keep-failed'));
    }
  }
}
