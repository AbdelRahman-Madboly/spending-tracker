import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../data/barcode_scan_service.dart';
import '../../data/gemini_key_store.dart';
import '../../data/net/gemini_client.dart';
import '../../data/net/network_gate.dart';
import '../../data/net/product_lookup.dart';
import '../../data/photo_capture_service.dart';
import '../../data/photo_storage.dart';
import '../../data/document_picker_service.dart';
import '../../data/speech_recognition_service.dart';
import '../../data/text_recognition_service.dart';
import '../../data/voice_playback.dart';
import '../../data/voice_recorder.dart';
import '../../domain/barcode_scan.dart';
import '../../domain/models.dart';
import '../../domain/online_features.dart';
import '../../domain/parsing/line_parser.dart';
import '../../domain/smart_parse.dart';
import '../../domain/spending_repository.dart';
import '../add/add_sheet.dart';
import '../home/widgets/capture_bar.dart';
import '../review/review_sheet.dart';
import 'permission_prompt.dart';
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
  PermissionService? permissionService,
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
      permissionService: permissionService,
      onSubmit: (draft) async {
        await repository.saveEntry(draft);
        HapticFeedback.lightImpact();
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      },
    ),
  );
}

/// Where a photo capture's photos come from.
enum PhotoSource { camera, gallery }

/// Asks where the photo comes from: a new picture or the gallery (spec
/// §6.2: camera or gallery). Null when the user backed out.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) =>
    showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          key: const Key('photo-source-sheet'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('photo-source-camera'),
              minTileHeight: 56,
              leading: const Icon(AppIcons.camera),
              title: const Text('صوّر دلوقتي'),
              onTap: () => Navigator.of(sheetContext).pop(PhotoSource.camera),
            ),
            ListTile(
              key: const Key('photo-source-gallery'),
              minTileHeight: 56,
              leading: const Icon(AppIcons.gallery),
              title: const Text('من المعرض'),
              subtitle: const Text('صورة أو أكتر، زي سكرين شوت إنستاباي'),
              onTap: () => Navigator.of(sheetContext).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );

/// Runs one capture bar action. Camera asks camera or gallery (unless
/// [photoSource] already says), then reads the photos (spec §6.2), voice records and transcribes (spec §6.4) and text takes a typed
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
  GeminiKeyStore? geminiKeyStore,
  VoiceRecorder Function()? voiceRecorderFactory,
  SpeechRecognitionService? speechRecognition,
  VoicePlayback Function()? playbackFactory,
  PermissionService? permissionService,
  PhotoSource? photoSource,
  DateTime Function() clock = DateTime.now,
}) async {
  var source = photoSource;
  if (action == CaptureAction.camera && source == null) {
    source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
  }
  // Camera and microphone are asked for on first use, behind a card that
  // says why (spec §8); a refusal opens nothing. The gallery's system
  // picker needs no permission.
  final permission = switch (action) {
    CaptureAction.camera when source == PhotoSource.gallery => null,
    CaptureAction.camera || CaptureAction.barcode => AppPermission.camera,
    CaptureAction.voice => AppPermission.microphone,
    CaptureAction.text => null,
  };
  if (permission != null &&
      !await ensurePermission(
        context,
        permission,
        service: permissionService,
      )) {
    return;
  }
  if (!context.mounted) return;
  // The review's smart path goes through the same gate as everything else
  // here, so one gate answers for every request a capture can make.
  final gate = networkGate ?? NetworkGate(repository);
  final smart = GeminiClient(
    gate,
    repository,
    geminiKeyStore ?? SecureGeminiKeyStore(),
  );
  switch (action) {
    case CaptureAction.camera when source == PhotoSource.gallery:
      await captureGalleryPhotos(
        context,
        repository,
        photoCaptureService: photoCaptureService,
        textRecognition: textRecognition,
        documentPicker: documentPicker,
        playbackFactory: playbackFactory,
        smartImprover: smart,
        clock: clock,
      );
    case CaptureAction.camera:
      await capturePhoto(
        context,
        repository,
        photoCaptureService: photoCaptureService,
        textRecognition: textRecognition,
        documentPicker: documentPicker,
        playbackFactory: playbackFactory,
        smartImprover: smart,
        clock: clock,
      );
    case CaptureAction.barcode:
      await captureBarcode(
        context,
        repository,
        scanner: barcodeScanService,
        networkGate: gate,
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
        smartImprover: smart,
        clock: clock,
      );
    case CaptureAction.text:
      await captureText(
        context,
        repository,
        photoCaptureService: photoCaptureService,
        playbackFactory: playbackFactory,
        smartImprover: smart,
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
  SmartImprover? smartImprover,
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
      _say(
        context,
        'ما قدرتش أفتح الكاميرا، جرب تاني',
        const Key('photo-failed'),
      );
    }
    return;
  }
  if (!context.mounted) return;
  if (result.outcome == PhotoCaptureOutcome.permissionDenied) {
    _say(
      context,
      'محتاج إذن الكاميرا عشان أصور. اسمح بيه من إعدادات التطبيق.',
      const Key('photo-permission-denied'),
    );
    return;
  }
  final path = result.relativePath;
  if (path == null) return;
  await _reviewPhotos(
    context,
    repository,
    [path],
    capturedAt: capturedAt,
    photos: photos,
    textRecognition: textRecognition,
    documentPicker: documentPicker,
    playbackFactory: playbackFactory,
    smartImprover: smartImprover,
    clock: clock,
  );
}

/// As [capturePhoto], with photos picked from the gallery (one or
/// several) instead of taken. The system picker needs no permission.
Future<void> captureGalleryPhotos(
  BuildContext context,
  SpendingRepository repository, {
  PhotoCaptureService? photoCaptureService,
  TextRecognitionService? textRecognition,
  DocumentPickerService? documentPicker,
  VoicePlayback Function()? playbackFactory,
  SmartImprover? smartImprover,
  DateTime Function() clock = DateTime.now,
}) async {
  final photos = photoCaptureService ?? ImagePickerPhotoCaptureService();
  final capturedAt = clock();
  final List<String> paths;
  try {
    paths = await photos.pickManyFromGallery();
  } catch (_) {
    if (context.mounted) {
      _say(
        context,
        'ما قدرتش أفتح الصور، جرب تاني',
        const Key('gallery-failed'),
      );
    }
    return;
  }
  if (paths.isEmpty) return;
  if (!context.mounted) {
    for (final path in paths) {
      photos.delete(path);
    }
    return;
  }
  await _reviewPhotos(
    context,
    repository,
    paths,
    capturedAt: capturedAt,
    photos: photos,
    textRecognition: textRecognition,
    documentPicker: documentPicker,
    playbackFactory: playbackFactory,
    smartImprover: smartImprover,
    clock: clock,
  );
}

/// Copies an image another app shared (an absolute path in the share
/// cache) into app storage, downscaled as a photo is, and returns the
/// stored path relative to app documents.
typedef SharedImageImporter = Future<String> Function(String absolutePath);

Future<String> _importSharedImage(String absolutePath) async => PhotoStorage(
  await getApplicationDocumentsDirectory(),
).importImage(File(absolutePath));

/// Images shared in from another app (InstaPay's share button, the
/// gallery, WhatsApp) as a photo capture: the same review as [capturePhoto]
/// with every image read and attached. Nothing is saved before the review.
Future<void> captureSharedPhotos(
  BuildContext context,
  SpendingRepository repository,
  List<String> sharedPaths, {
  SharedImageImporter? importImage,
  PhotoCaptureService? photoCaptureService,
  TextRecognitionService? textRecognition,
  DocumentPickerService? documentPicker,
  VoicePlayback Function()? playbackFactory,
  SmartImprover? smartImprover,
  DateTime Function() clock = DateTime.now,
}) async {
  if (sharedPaths.isEmpty) return;
  final photos = photoCaptureService ?? ImagePickerPhotoCaptureService();
  final capturedAt = clock();
  final copy = importImage ?? _importSharedImage;
  final paths = <String>[];
  try {
    for (final shared in sharedPaths) {
      paths.add(await copy(shared));
    }
  } catch (_) {
    for (final path in paths) {
      photos.delete(path);
    }
    if (context.mounted) {
      _say(
        context,
        'ما قدرتش أفتح الصورة اللي اتبعتت، جرب تاني',
        const Key('shared-image-failed'),
      );
    }
    return;
  }
  if (!context.mounted) {
    for (final path in paths) {
      photos.delete(path);
    }
    return;
  }
  await _reviewPhotos(
    context,
    repository,
    paths,
    capturedAt: capturedAt,
    photos: photos,
    textRecognition: textRecognition,
    documentPicker: documentPicker,
    playbackFactory: playbackFactory,
    smartImprover: smartImprover,
    clock: clock,
  );
}

/// The review every photo capture ends in: the photos at [paths] (stored
/// already, relative to app documents) are read and attached.
Future<void> _reviewPhotos(
  BuildContext context,
  SpendingRepository repository,
  List<String> paths, {
  required DateTime capturedAt,
  required PhotoCaptureService photos,
  TextRecognitionService? textRecognition,
  DocumentPickerService? documentPicker,
  VoicePlayback Function()? playbackFactory,
  SmartImprover? smartImprover,
  required DateTime Function() clock,
}) async {
  await showReviewSheet(
    context,
    repository: repository,
    request: ReviewRequest(
      kind: CaptureKind.photo,
      capturedAt: capturedAt,
      attachments: [
        for (final path in paths)
          DraftAttachment(kind: AttachmentKind.photo, path: path),
      ],
    ),
    clock: clock,
    photoCaptureService: photos,
    textRecognition: textRecognition,
    documentPicker: documentPicker,
    playbackFactory: playbackFactory,
    smartImprover: smartImprover,
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
  final codes = await (scanner ?? MobileScannerBarcodeScanService()).scanMany(
    context,
  );
  if (codes.isEmpty || !context.mounted) return;
  final ProductLookup? lookup =
      await isOnlineFeatureOn(repository, OnlineFeature.productLookup)
      ? OpenFoodFactsLookup(
          networkGate ?? NetworkGate(repository),
          repository,
          clock: clock,
        )
      : null;
  if (lookup != null && context.mounted) {
    _say(context, 'بدوّر على أسماء المنتجات…', const Key('barcode-looking-up'));
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
  SmartImprover? smartImprover,
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
      _say(
        context,
        'محتاج إذن الميكروفون علشان أسجل. اسمح بيه من إعدادات التطبيق.',
        const Key('voice-permission-denied'),
      );
      return;
    case VoicePhase.failed:
      _say(
        context,
        'الميكروفون مش متاح دلوقتي، جرب تاني',
        const Key('voice-failed'),
      );
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
    smartImprover: smartImprover,
  );
}

/// Takes a typed note (spec §6.5) and reviews it through the parser. A
/// note closed before review is kept as a draft rather than lost.
Future<void> captureText(
  BuildContext context,
  SpendingRepository repository, {
  PhotoCaptureService? photoCaptureService,
  VoicePlayback Function()? playbackFactory,
  SmartImprover? smartImprover,
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
        kind: CaptureKind.text,
        capturedAt: capturedAt,
        rawText: text,
      ),
      clock: clock,
      photoCaptureService: photoCaptureService,
      playbackFactory: playbackFactory,
      smartImprover: smartImprover,
    );
    return;
  }
  final kept = typed.trim();
  if (kept.isEmpty) return;
  try {
    await repository.saveCapture(
      CaptureDraft(
        kind: CaptureKind.text,
        date: ArabicLineParser.captureDay(capturedAt),
        rawText: kept,
        lines: const [],
        isDraft: true,
      ),
    );
    if (context.mounted) {
      _say(
        context,
        'الملاحظة مستنياك في «محتاج مراجعة»',
        const Key('text-note-kept'),
      );
    }
  } catch (_) {
    if (context.mounted) {
      _say(
        context,
        'ما قدرتش أحتفظ بالملاحظة، جرب تاني',
        const Key('text-note-keep-failed'),
      );
    }
  }
}
