import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/app_icons.dart';
import '../../core/design/tokens.dart';
import '../../core/money.dart';
import '../../core/quantity.dart';
import '../../data/product_catalog_source.dart';
import '../../data/document_picker_service.dart';
import '../../data/gemini_key_store.dart';
import '../../data/net/gemini_client.dart';
import '../../data/net/network_gate.dart';
import '../../data/photo_capture_service.dart';
import '../../data/text_recognition_service.dart';
import '../../data/voice_playback.dart';
import '../../domain/barcode_scan.dart';
import '../../domain/models.dart';
import '../../domain/parsing/catalogue_matcher.dart';
import '../../domain/parsing/line_parser.dart';
import '../../domain/parsing/parsed_line.dart';
import '../../domain/parsing/repository_catalogue.dart';
import '../../domain/photo_reading.dart';
import '../../domain/review.dart';
import '../../domain/smart_parse.dart';
import '../../domain/spending_repository.dart';
import '../../domain/transactions.dart';
import '../add/add_sheet.dart' show keypadText, paymentMethodLabels;
import '../add/widgets/category_strip.dart';
import '../add/widgets/subcategory_strip.dart';
import '../transactions/widgets/attachment_strip.dart';

/// Everything one capture hands the review sheet (spec §6.7). Every
/// automatic path (voice, text, photo, barcode, a draft from Needs review)
/// builds one of these and nothing else: no capture is saved without
/// passing through the sheet.
class ReviewRequest {
  final CaptureKind kind;

  /// When the capture was made: dates the parsed lines (a note written
  /// before 05:00 belongs to the day before).
  final DateTime capturedAt;

  /// The shared date, when the capture already has one (a draft's).
  /// Otherwise the first parsed line's date, then the capture day.
  final DateTime? date;

  /// The transcript or typed text as captured, never altered.
  final String? rawText;
  final String? cleanText;
  final String? parsedBy;

  /// Lines the capture already has (a barcode scan, an OCR result). When
  /// null the sheet parses [cleanText] or [rawText] against the catalogue.
  final List<ParsedLine>? lines;

  /// Attachments made by this capture and not saved yet.
  final List<DraftAttachment> attachments;

  /// The draft this review finishes, and the attachments it already holds.
  final String? draftId;
  final List<AttachmentView> savedAttachments;

  const ReviewRequest({
    required this.kind,
    required this.capturedAt,
    this.date,
    this.rawText,
    this.cleanText,
    this.parsedBy,
    this.lines,
    this.attachments = const [],
    this.draftId,
    this.savedAttachments = const [],
  });

  /// Review of a capture kept for later: its text is parsed again (a draft
  /// stores no lines) and its attachments show as they are.
  factory ReviewRequest.fromDraft(CaptureGroupView draft) => ReviewRequest(
        kind: draft.kind,
        // Midday, so the before-05:00 rule never moves a draft's own day.
        capturedAt:
            DateTime(draft.date.year, draft.date.month, draft.date.day, 12),
        date: draft.date,
        rawText: draft.rawText,
        cleanText: draft.cleanText,
        parsedBy: draft.parsedBy,
        draftId: draft.id,
        savedAttachments: draft.attachments,
      );
}

/// How the review ended. [kept] covers بعدين and closing the sheet: the
/// capture waits in Needs review.
enum ReviewOutcome { saved, note, kept }

/// Opens the review sheet full height and resolves to how it ended.
///
/// Closing without saving never discards the capture (spec §6.7): a new
/// capture is kept as a `draft`, and a draft opened from Needs review stays
/// the draft it was. This runs here, after the sheet is gone, so every way
/// of closing it (بعدين, back, a drag down) keeps the capture the same way.
Future<ReviewOutcome> showReviewSheet(
  BuildContext context, {
  required SpendingRepository repository,
  required ReviewRequest request,
  DateTime Function() clock = DateTime.now,
  PhotoCaptureService? photoCaptureService,
  TextRecognitionService? textRecognition,
  DocumentPickerService? documentPicker,
  VoicePlayback Function()? playbackFactory,
  SmartImprover? smartImprover,
  Future<Uint8List> Function(String path)? readAttachment,
  ProductCatalogSource? productCatalog,
}) async {
  final latest = _ReviewSnapshot(request.attachments);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final outcome = await showModalBottomSheet<ReviewOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 1,
      child: ReviewSheet(
        repository: repository,
        request: request,
        clock: clock,
        photoCaptureService: photoCaptureService,
        textRecognition: textRecognition,
        documentPicker: documentPicker,
        playbackFactory: playbackFactory,
        smartImprover: smartImprover,
        readAttachment: readAttachment,
        productCatalog: productCatalog,
        onCleanText: (text) => latest
          ..cleanText = text
          ..editedSinceRewrite = false,
        onChanged: (lines, date) {
          latest.lines = lines;
          latest.date = date;
        },
        onAttachmentsChanged: (attachments) => latest.attachments = attachments,
        onTyped: (text) => latest.typed = text,
        onEdited: () => latest
          ..edited = true
          ..editedSinceRewrite = latest.cleanText != null,
      ),
    ),
  );
  if (outcome == ReviewOutcome.saved || outcome == ReviewOutcome.note) {
    return outcome!;
  }
  try {
    await _keepAsDraft(repository, request, latest);
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(
      key: Key('review-keep-failed'),
      content: Text('ما قدرتش أحتفظ بالتسجيل، جرب تاني'),
    ));
  }
  return ReviewOutcome.kept;
}

class _ReviewSnapshot {
  _ReviewSnapshot(this.attachments);

  /// The lines as they stand, once the sheet has made them. Until then (a
  /// sheet closed while still loading) the capture's own lines stand in.
  List<ReviewLine>? lines;

  /// The capture's new attachments as they stand: photos and files added in
  /// review, less a photo refused as a transfer already recorded.
  List<DraftAttachment> attachments;
  DateTime? date;

  /// What was typed for a capture that came with no words.
  String typed = '';

  /// The smart rewrite the user accepted with اعتمد, if any.
  String? cleanText;

  /// Whether the lines were changed after [cleanText] was accepted, so the
  /// rewrite no longer says what they do.
  bool editedSinceRewrite = false;

  /// Whether the user changed the lines themselves (an edit, a removal, a
  /// line added) rather than only the date or payment method.
  bool edited = false;
}

/// Keeps a new capture as a draft. A draft stores its text and
/// attachments only, so lines that came with no text of their own are
/// written as text the parser reads back to them.
///
/// A photo capture's lines as read are not: its photos are read again when
/// the draft is reviewed, which brings back what text cannot carry (an
/// InstaPay transfer's reference and payment method). Only lines the user
/// changed are written as text, and even then the photos are read again
/// for their references (see [withReadReferences]).
///
/// A barcode capture keeps its codes (see [barcodeDraftText]): a product
/// not named yet has no text, and without its code it would be lost.
///
/// An accepted smart rewrite is kept as the draft's clean text, which the
/// draft is read from when reviewed again. When the draft's text is
/// written from lines changed after the rewrite was accepted, the rewrite
/// is dropped: it would bring back the lines as they were before the edit.
///
/// A draft opened from Needs review is left as it was, a rewrite accepted
/// in it included: only saving it keeps that rewrite.
Future<void> _keepAsDraft(SpendingRepository repository,
    ReviewRequest request, _ReviewSnapshot latest) async {
  if (request.draftId != null) return;
  final raw = request.rawText ?? '';
  final typed = raw.trim().isEmpty ? latest.typed.trim() : '';
  final linesAsRead = request.kind == CaptureKind.photo && !latest.edited;
  final lines = latest.lines ??
      [
        for (final (i, p) in (request.lines ?? const <ParsedLine>[]).indexed)
          ReviewLine.fromParsed(p, id: 'k$i'),
      ];
  final fromLines = raw.trim().isEmpty && typed.isEmpty && !linesAsRead;
  final text = raw.trim().isNotEmpty
      ? raw
      : typed.isNotEmpty
          ? typed
          : !fromLines
              ? ''
              : request.kind == CaptureKind.barcode
                  ? barcodeDraftText(lines)
                  : reviewDraftText(lines);
  final rewrite = fromLines && latest.editedSinceRewrite
      ? null
      : latest.cleanText;
  if (text.trim().isEmpty && latest.attachments.isEmpty) return;
  final day = latest.date ?? ArabicLineParser.captureDay(request.capturedAt);
  await repository.saveCapture(CaptureDraft(
    kind: request.kind,
    date: day,
    rawText: text.isEmpty ? null : text,
    cleanText: rewrite ?? request.cleanText,
    parsedBy: latest.cleanText != null ? 'gemini' : request.parsedBy,
    lines: const [],
    attachments: _withTypedTranscript(latest.attachments, typed),
    isDraft: true,
  ));
}

/// The capture's attachments, with [typed] as the transcript of a voice
/// note no recogniser heard: the audio is kept "with its transcript"
/// (spec §6.4) whether the words were heard or typed.
List<DraftAttachment> _withTypedTranscript(
    List<DraftAttachment> attachments, String typed) {
  if (typed.isEmpty) return attachments;
  return [
    for (final a in attachments)
      a.kind == AttachmentKind.voice && a.transcript == null
          ? DraftAttachment(
              kind: a.kind,
              path: a.path,
              text: a.text,
              transcript: typed,
              durationMs: a.durationMs,
            )
          : a,
  ];
}

/// The review sheet (spec §6.7): a shared date and payment method and the
/// capture's attachments on top, one editable card per line, and a footer
/// with the total, حفظ N مصروف, حفظ كملاحظة and بعدين.
class ReviewSheet extends StatefulWidget {
  final SpendingRepository repository;
  final ReviewRequest request;
  final DateTime Function() clock;
  final PhotoCaptureService? photoCaptureService;

  /// Reads a photo capture's photos (spec §6.2). Defaults to ML Kit's
  /// offline Latin model.
  final TextRecognitionService? textRecognition;
  final DocumentPickerService? documentPicker;
  final VoicePlayback Function()? playbackFactory;

  /// The smart path (spec §6.6). Defaults to Gemini through a network gate
  /// of its own, which offers nothing unless online features are on.
  final SmartImprover? smartImprover;

  /// Reads an attachment's bytes for the smart path. Defaults to the file
  /// the photo service resolves the path to.
  final Future<Uint8List> Function(String path)? readAttachment;

  /// The bundled product catalogue a kept barcode capture's codes are read
  /// against again. Defaults to the app's own.
  final ProductCatalogSource? productCatalog;

  /// Told the smart rewrite when the user accepts it, so a capture closed
  /// afterwards keeps it as its draft's clean text.
  final ValueChanged<String>? onCleanText;

  /// Told the lines and date after every change, so whoever opened the
  /// sheet can keep them as a draft when it is closed.
  final void Function(List<ReviewLine> lines, DateTime date)? onChanged;

  /// Told the text typed for a capture that came with no words, for the
  /// same reason.
  final ValueChanged<String>? onTyped;

  /// Told the capture's new attachments whenever they change.
  final ValueChanged<List<DraftAttachment>>? onAttachmentsChanged;

  /// Told when the user changes the lines themselves: until then a photo
  /// capture's lines are only what its photos read as, and a draft of it
  /// reads the photos again instead of keeping the lines as text.
  final VoidCallback? onEdited;

  const ReviewSheet({
    super.key,
    required this.repository,
    required this.request,
    this.clock = DateTime.now,
    this.photoCaptureService,
    this.textRecognition,
    this.documentPicker,
    this.playbackFactory,
    this.smartImprover,
    this.readAttachment,
    this.productCatalog,
    this.onCleanText,
    this.onChanged,
    this.onTyped,
    this.onAttachmentsChanged,
    this.onEdited,
  });

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  SpendingRepository get _repo => widget.repository;
  ReviewRequest get _request => widget.request;

  PhotoCaptureService? _photoCaptureService;
  PhotoCaptureService get _photos => _photoCaptureService ??=
      widget.photoCaptureService ?? ImagePickerPhotoCaptureService();

  TextRecognitionService? _textRecognition;
  TextRecognitionService get _recognizer => _textRecognition ??=
      widget.textRecognition ?? MlKitTextRecognitionService();

  DocumentPickerService? _documentPicker;
  DocumentPickerService get _documents => _documentPicker ??=
      widget.documentPicker ?? FilePickerDocumentService();

  SmartImprover? _smartImprover;
  SmartImprover get _smart => _smartImprover ??= widget.smartImprover ??
      GeminiClient(NetworkGate(_repo), _repo, SecureGeminiKeyStore());

  /// The smart inputs available now, as found when the sheet opened.
  Set<SmartInputKind> _smartKinds = const {};

  /// A smart request is in flight; its button waits.
  bool _improving = false;

  /// The smart rewrite accepted with اعتمد: saved as the capture's clean
  /// text beside the untouched raw text.
  String? _cleanText;

  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// The capture's new attachments: the ones it came with, plus photos and
  /// files added here.
  late List<DraftAttachment> _attachments = _request.attachments;

  /// Photos being read right now; the sheet says so while it is non-zero.
  int _reading = 0;

  /// The catalogue photos are matched against, once loaded.
  ParserCatalogue? _catalogue;

  bool _loaded = false;
  bool _saving = false;

  /// The user's answer to "salary or expense?" for the transfers the user
  /// received (spec §6.2); null until they answer.
  bool? _salaryChoice;
  bool _paymentTouched = false;
  bool _dateTouched = false;
  int _nextId = 0;

  List<ReviewLine> _lines = const [];
  late DateTime _date;

  /// The lines that are money in, or may be: InstaPay transfers to the
  /// user.
  List<ReviewLine> get _transfersIn => [
        for (final l in _lines)
          if (l.transfer != null) l,
      ];

  /// Whether the transfers in are recorded as a salary. Until the user
  /// answers, a transfer clearly received is; an uncertain one stays an
  /// expense.
  bool get _asSalary =>
      _transfersIn.isNotEmpty &&
      (_salaryChoice ??
          _lines.any((l) => l.transfer == TransferDirection.received));

  /// The lines saved as expenses: all of them, less the salary.
  List<ReviewLine> get _expenseLines => _asSalary
      ? [
          for (final l in _lines)
            if (l.transfer == null) l,
        ]
      : _lines;

  bool get _canSave => _asSalary
      ? _transfersIn.every((l) => l.canBeSalary) &&
          (_expenseLines.isEmpty || canSaveReview(_expenseLines))
      : canSaveReview(_lines);
  String _paymentMethod = 'Cash';

  /// Set when the sheet parsed the text itself rather than being handed
  /// lines.
  String? _parsedBy;

  /// A capture that came with no words and no lines (a voice note no
  /// recogniser heard, spec §6.4) asks for its text to be typed here; the
  /// typed text is then the capture's raw text.
  late final bool _asksForText;
  final _typed = TextEditingController();
  ArabicLineParser? _parser;

  /// The ids of the lines the last حلّل made: parsing again replaces them
  /// rather than adding a second copy.
  Set<String> _typedLineIds = const {};

  List<CategoryView> _categories = const [];
  Map<String, List<SubcategoryView>> _subcategories = const {};
  List<QuickPickItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _date = _request.date ?? ArabicLineParser.captureDay(_request.capturedAt);
    // A photo capture has its photos to read instead of words to type.
    _asksForText = _request.kind != CaptureKind.photo &&
        _request.lines == null &&
        (_request.cleanText ?? _request.rawText ?? '').trim().isEmpty;
    _typed.addListener(() => widget.onTyped?.call(_typed.text));
    _load();
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// The captured text, or the typed one for a capture that had none.
  String? get _rawText {
    final raw = _request.rawText;
    if (raw != null && raw.trim().isNotEmpty) return raw;
    final typed = _typed.text.trim();
    return typed.isEmpty ? raw : typed;
  }

  /// Reads the typed text into lines. They replace the lines the last
  /// parse made (edited or not: the typed text is the source now) and
  /// follow any line added by hand.
  void _parseTyped() {
    final parser = _parser;
    final text = _typed.text.trim();
    if (parser == null || text.isEmpty) return;
    final parsed = parser.parse(text, capturedAt: _request.capturedAt);
    final fresh = [
      for (final p in parsed) ReviewLine.fromParsed(p, id: _newId()),
    ];
    setState(() {
      _lines = [
        for (final l in _lines)
          if (!_typedLineIds.contains(l.id)) l,
        ...fresh,
      ];
      _typedLineIds = {for (final l in fresh) l.id};
      _parsedBy = 'local';
    });
    FocusScope.of(context).unfocus();
    _report();
  }

  String _newId() => 'l${_nextId++}';

  Future<void> _load() async {
    final categories = await _repo.categories();
    final subcategories = {
      for (final c in categories) c.key: await _repo.subcategories(c.key),
    };
    final items = await _repo.allItems();
    final payment = await _repo.setting(lastPaymentMethodSettingKey);
    Set<SmartInputKind> smartKinds;
    try {
      smartKinds = await _smart.available();
    } catch (_) {
      smartKinds = const {};
    }
    var parsed = _request.lines;
    String? parsedBy = _request.parsedBy;
    String? photoPayment;
    List<ParsedLine> readReferences = const [];
    Map<ParsedLine, String> photoSources = const {};
    if (parsed == null) {
      final text = _request.cleanText ?? _request.rawText ?? '';
      final catalogue = await loadParserCatalogue(_repo);
      _catalogue = catalogue;
      final parser = ArabicLineParser(catalogue);
      _parser = parser;
      if (_request.kind == CaptureKind.photo) {
        // A photo capture, new or kept for later: read its photos, the ones
        // the draft holds and the ones just taken.
        _items = items;
        final read = await _readPhotos([
          for (final a in _request.savedAttachments)
            if (a.kind == AttachmentKind.photo && a.path != null) a.path!,
          for (final a in _request.attachments)
            if (a.kind == AttachmentKind.photo && a.path != null) a.path!,
        ]);
        if (text.trim().isEmpty) {
          parsed = read.lines;
        } else {
          // Lines edited before the draft was kept come back from its
          // text; the photos give back only what the text cannot hold.
          parsed = parser.parse(text, capturedAt: _request.capturedAt);
          parsedBy ??= 'local';
          readReferences = read.lines;
        }
        if (read.instaPay) photoPayment = 'InstaPay';
        photoSources = read.sources;
      } else if (_request.kind == CaptureKind.barcode) {
        // A barcode capture kept for later: its codes are scanned again,
        // and anything added by hand is parsed from the rest of its text.
        final catalog =
            await (widget.productCatalog ?? ProductCatalogSource.shared)
                .load();
        final kept = await readBarcodeDraft(_request.rawText,
            repository: _repo, day: _date, catalog: catalog);
        parsed = [
          ...kept.lines,
          if (kept.text.trim().isNotEmpty)
            ...parser.parse(kept.text, capturedAt: _request.capturedAt),
        ];
        parsedBy ??= 'local';
      } else {
        parsed = parser.parse(text, capturedAt: _request.capturedAt);
        parsedBy ??= 'local';
      }
    }
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _subcategories = subcategories;
      _items = items;
      if (!_paymentTouched && (photoPayment ?? payment) != null) {
        _paymentMethod = (photoPayment ?? payment)!;
      }
      _parsedBy = parsedBy;
      _smartKinds = smartKinds;
      _lines = withReadReferences([
        for (final p in parsed!)
          ReviewLine.fromParsed(p, id: _newId(), photoPath: photoSources[p]),
      ], readReferences);
      if (_request.date == null && parsed.isNotEmpty) _date = parsed.first.date;
      _loaded = true;
    });
    _report();
  }

  void _report() => widget.onChanged?.call(_lines, _date);

  void _setAttachments(List<DraftAttachment> attachments) {
    setState(() => _attachments = attachments);
    widget.onAttachmentsChanged?.call(attachments);
  }

  int? _priceOf(String itemId) =>
      _items.where((i) => i.id == itemId).firstOrNull?.suggestedAmountPiastres;

  /// Reads [paths] one after another into lines (spec §6.2). A photo that
  /// cannot be read gives no lines and stays as evidence. A transfer whose
  /// reference is already recorded, or already read in this capture, is
  /// refused: it says so, and a photo taken for this capture is dropped
  /// (one kept in a draft stays; it is the draft's).
  ///
  /// [sources] names the photo each line was read from, the evidence a
  /// transfer recorded as a salary keeps.
  Future<
      ({
        List<ParsedLine> lines,
        bool instaPay,
        Map<ParsedLine, String> sources,
      })> _readPhotos(List<String> paths) async {
    final catalogue = _catalogue;
    final Map<ParsedLine, String> sources = Map.identity();
    if (catalogue == null || paths.isEmpty) {
      return (lines: const <ParsedLine>[], instaPay: false, sources: sources);
    }
    setState(() => _reading++);
    final lines = <ParsedLine>[];
    var instaPay = false;
    final refused = <String>[];
    Set<String>? salaryIds;
    try {
      for (final path in paths) {
        PhotoReading reading;
        try {
          final file = await _photos.resolve(path);
          reading = readPhotoText(await _recognizer.recognize(file.path),
              now: widget.clock());
        } catch (_) {
          continue;
        }
        final reference = reading.reference;
        if (reference != null &&
            (lines.any((l) => l.reference == reference) ||
                _lines.any((l) => l.reference == reference) ||
                await _repo.referenceExists(reference) ||
                // A transfer in may be a salary already.
                (reading.direction != TransferDirection.sent &&
                    (salaryIds ??= await _repo.knownExternalIds())
                        .contains(transferSalaryId(reference))))) {
          refused.add(path);
          continue;
        }
        instaPay = instaPay || reading.isInstaPay;
        final read = photoLines(reading, catalogue,
            day: ArabicLineParser.captureDay(_request.capturedAt),
            priceOf: _priceOf);
        for (final line in read) {
          sources[line] = path;
        }
        lines.addAll(read);
      }
    } finally {
      if (mounted) setState(() => _reading--);
    }
    // Closed while reading: the photos were kept with the draft as they
    // were, refused one included, and there is no sheet left to say so.
    if (!mounted) {
      return (lines: const <ParsedLine>[], instaPay: false, sources: sources);
    }
    if (refused.isNotEmpty) {
      final dropped = {
        for (final a in _attachments)
          if (refused.contains(a.path)) a.path!,
      };
      if (dropped.isNotEmpty) {
        _setAttachments(
            [for (final a in _attachments) if (!dropped.contains(a.path)) a]);
        for (final path in dropped) {
          _photos.delete(path);
        }
      }
      _sayDuplicate();
    }
    return (lines: lines, instaPay: instaPay, sources: sources);
  }

  void _sayDuplicate() => _say('العملية دي متسجلة قبل كده',
      key: const Key('review-duplicate-reference'));

  /// Adds photos to the capture. A photo capture reads them into more
  /// lines; any other capture keeps them as evidence only, since its lines
  /// already came from its words.
  Future<void> _addPhotos(List<String> paths) async {
    if (paths.isEmpty) return;
    _setAttachments([
      ..._attachments,
      for (final path in paths)
        DraftAttachment(kind: AttachmentKind.photo, path: path),
    ]);
    if (_request.kind != CaptureKind.photo) return;
    final hadLines = _lines.isNotEmpty;
    final read = await _readPhotos(paths);
    if (!mounted) return;
    setState(() {
      // The first photo that reads as anything dates the capture, as the
      // first one would have when the sheet opened.
      if (_request.date == null &&
          !_dateTouched &&
          !hadLines &&
          read.lines.isNotEmpty) {
        _date = read.lines.first.date;
      }
      _lines = [
        ..._lines,
        for (final p in read.lines)
          ReviewLine.fromParsed(p, id: _newId(), photoPath: read.sources[p]),
      ];
      if (read.instaPay && !_paymentTouched) _paymentMethod = 'InstaPay';
    });
    _report();
  }

  Future<void> _addFromCamera() async {
    final PhotoCaptureResult result;
    try {
      result = await _photos.captureFromCamera();
    } catch (_) {
      _sayPhotoFailed();
      return;
    }
    final path = result.relativePath;
    if (!_stillOpen([?path])) return;
    if (result.outcome == PhotoCaptureOutcome.permissionDenied) {
      _say('محتاج إذن الكاميرا عشان أصور', key: const Key('review-camera-denied'));
    }
    if (path != null) await _addPhotos([path]);
  }

  Future<void> _addFromGallery() async {
    final List<String> paths;
    try {
      paths = await _photos.pickManyFromGallery();
    } catch (_) {
      _sayPhotoFailed();
      return;
    }
    if (!_stillOpen(paths)) return;
    await _addPhotos(paths);
  }

  /// Whether the sheet is still up after a picker. When it was closed while
  /// the picker was up, the capture was already kept without [paths], so
  /// the copies just made would belong to nothing: they are deleted.
  bool _stillOpen(List<String> paths) {
    if (mounted) return true;
    for (final path in paths) {
      _photos.delete(path);
    }
    return false;
  }

  void _sayPhotoFailed() {
    if (!mounted) return;
    _say('ما قدرتش أفتح الصور، جرب تاني',
        key: const Key('review-photo-failed'));
  }

  Future<void> _addPdf() async {
    final PickedDocument? picked;
    try {
      picked = await _documents.pickPdf();
    } catch (_) {
      _say('ما قدرتش أفتح الملف، جرب تاني', key: const Key('review-pdf-failed'));
      return;
    }
    if (picked == null || !mounted) return;
    // A file attachment's text is the name it was picked by: the stored
    // file is renamed to its id, and the name is what the user knows it by.
    _setAttachments([
      ..._attachments,
      DraftAttachment(
          kind: AttachmentKind.file,
          path: picked.relativePath,
          text: picked.name),
    ]);
  }

  void _update(ReviewLine line) {
    setState(() {
      _lines = [for (final l in _lines) l.id == line.id ? line : l];
    });
    _report();
    widget.onEdited?.call();
  }

  void _remove(String id) {
    setState(() => _lines = [for (final l in _lines) if (l.id != id) l]);
    _report();
    widget.onEdited?.call();
  }

  void _addLine() {
    setState(() => _lines = [..._lines, ReviewLine.blank(_newId())]);
    _report();
    widget.onEdited?.call();
  }

  void _say(String message, {Key? key}) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(key: key, content: Text(message)));
  }

  /// Paths of the capture's attachments of [kind], the saved ones first.
  List<String> _pathsOf(AttachmentKind kind) => [
        for (final a in _request.savedAttachments)
          if (a.kind == kind && a.path != null) a.path!,
        for (final a in _attachments)
          if (a.kind == kind && a.path != null) a.path!,
      ];

  /// What the smart button would send (spec §6.6), or null for no button.
  ///
  /// A photo capture sends its photos («استخرج بالتفصيل»). A voice note
  /// sends its audio when Gemini audio is on, for transcription and
  /// extraction in one request, and otherwise its transcript like any
  /// text. A barcode capture has nothing for it to read.
  SmartInputKind? get _smartKind {
    switch (_request.kind) {
      case CaptureKind.barcode:
        return null;
      case CaptureKind.photo:
        return _smartKinds.contains(SmartInputKind.photo) &&
                _pathsOf(AttachmentKind.photo).isNotEmpty
            ? SmartInputKind.photo
            : null;
      case CaptureKind.voice
          when _smartKinds.contains(SmartInputKind.audio) &&
              _pathsOf(AttachmentKind.voice).isNotEmpty:
        return SmartInputKind.audio;
      default:
        return _smartKinds.contains(SmartInputKind.text) &&
                (_rawText ?? '').trim().isNotEmpty
            ? SmartInputKind.text
            : null;
    }
  }

  Future<Uint8List> _read(String path) async {
    if (widget.readAttachment case final read?) return read(path);
    return (await _photos.resolve(path)).readAsBytes();
  }

  /// تحسين / استخرج بالتفصيل. The local lines stay on screen while the
  /// request runs; the smart ones are offered side by side with them and
  /// replace them only on اعتمد. Any failure leaves the local result and
  /// says so in one line.
  Future<void> _improve() async {
    final kind = _smartKind;
    if (kind == null || _improving) return;
    setState(() => _improving = true);
    SmartResult? result;
    try {
      final input = switch (kind) {
        SmartInputKind.text => SmartInput.text(_rawText!.trim()),
        SmartInputKind.photo => SmartInput.photos([
            for (final path in _pathsOf(AttachmentKind.photo))
              await _read(path),
          ]),
        SmartInputKind.audio =>
          SmartInput.audio(await _read(_pathsOf(AttachmentKind.voice).first)),
      };
      result = await _smart.improve(input, day: _date);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    setState(() => _improving = false);
    if (result == null || result.lines.isEmpty) {
      _say('التحسين الذكي مش متاح دلوقتي',
          key: const Key('review-smart-failed'));
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _SmartCompareDialog(before: _lines, after: result!),
    );
    if (accepted != true || !mounted) return;
    _accept(result);
  }

  void _accept(SmartResult result) {
    // A transfer's reference was read off the photo, not by the smart
    // path; it follows its amount onto the new lines, so a second copy of
    // the same transfer is still refused.
    final references = [
      for (final l in _lines)
        if (l.reference != null)
          ParsedLine(
            rawText: l.name,
            date: _date,
            name: l.name,
            amountPiastres: l.amountPiastres,
            confidence: ParseConfidence.high,
            reference: l.reference,
          ),
    ];
    setState(() {
      _lines = withReadReferences([
        for (final p in result.lines) ReviewLine.fromParsed(p, id: _newId()),
      ], references);
      _typedLineIds = const {};
      _cleanText = result.cleanText;
      _parsedBy = 'gemini';
      if (result.date != null && _request.date == null && !_dateTouched) {
        _date = result.date!;
      }
    });
    // The new lines are an edit of the capture's lines, and the rewrite
    // matches them: it is reported last, so it does not count as stale.
    _report();
    widget.onEdited?.call();
    widget.onCleanText?.call(result.cleanText);
  }

  Future<void> _pickDate() async {
    final now = widget.clock();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _dateTouched = true;
      });
      _report();
    }
  }

  /// Writes the capture. One write at a time: while it runs every footer
  /// button is off, so a double tap cannot save it twice. A failure says
  /// so and leaves the sheet open with the lines as they were.
  Future<void> _write(List<CaptureLine> lines, ReviewOutcome outcome) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveCapture(lines);
      if (outcome == ReviewOutcome.saved) HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(outcome);
    } on DuplicateReferenceException {
      if (mounted) _sayDuplicate();
    } catch (_) {
      if (mounted) {
        _say('الحفظ ما نفعش، جرب تاني', key: const Key('review-save-failed'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Writes the capture with [lines] and the capture's attachments.
  Future<void> _saveCapture(List<CaptureLine> lines) async {
    final raw = _rawText;
    await _repo.saveCapture(CaptureDraft(
      kind: _request.kind,
      date: _date,
      paymentMethod: _paymentMethod,
      // A note needs words to be worth keeping; lines that came with no
      // text of their own give it theirs.
      rawText: raw ??
          (lines.isEmpty && _lines.isNotEmpty
              ? reviewDraftText(_lines)
              : null),
      cleanText: _cleanText ?? _request.cleanText,
      parsedBy: _parsedBy,
      lines: lines,
      attachments: _withTypedTranscript(
          _attachments, _asksForText ? _typed.text.trim() : ''),
      draftId: _request.draftId,
    ));
  }

  Future<void> _save() async {
    if (!_canSave) return;
    if (_asSalary) return _saveSalary();
    await _write([for (final l in _lines) l.toCaptureLine()],
        ReviewOutcome.saved);
  }

  /// Records the transfers in as salary periods, each with the screenshot
  /// it was read from as its evidence, then the rest of the capture as
  /// usual: its expense lines, or with none, the photos left over as a
  /// note so no evidence is lost. A salary already recorded from the same
  /// transfer is refused, as a second copy of an expense is.
  Future<void> _saveSalary() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      for (final line in _transfersIn) {
        final reference = line.reference;
        await _repo.addSalaryPeriod(
          datePaid: _date,
          amountPiastres: line.amountPiastres!,
          note: reference == null ? 'InstaPay' : 'InstaPay $reference',
          evidencePhotoPath: line.photoPath,
          externalId: reference == null ? null : transferSalaryId(reference),
        );
        // Recorded: a retry after a later failure must not record it again.
        if (!mounted) return;
        setState(() {
          _lines = [for (final l in _lines) if (l.id != line.id) l];
          if (line.photoPath case final path?) {
            _attachments = [
              for (final a in _attachments) if (a.path != path) a,
            ];
          }
        });
        widget.onAttachmentsChanged?.call(_attachments);
        _report();
      }
      final expenses = _lines;
      // A draft finished here leaves Needs review even with nothing left.
      if (expenses.isNotEmpty ||
          _attachments.isNotEmpty ||
          _request.draftId != null) {
        await _saveCapture(
            [for (final l in expenses) l.toCaptureLine()]);
      }
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(ReviewOutcome.saved);
    } on StateError {
      if (mounted) _sayDuplicate();
    } on DuplicateReferenceException {
      if (mounted) _sayDuplicate();
    } catch (_) {
      if (mounted) {
        _say('الحفظ ما نفعش، جرب تاني', key: const Key('review-save-failed'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNote() => _write(const [], ReviewOutcome.note);

  List<AttachmentView> get _attachmentViews {
    final now = widget.clock();
    return [
      ..._request.savedAttachments,
      for (final (i, a) in _attachments.indexed)
        AttachmentView(
          id: 'new-$i',
          kind: a.kind,
          path: a.path,
          text: a.text,
          transcript: a.transcript,
          durationMs: a.durationMs,
          createdAt: now,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        key: const Key('review-sheet'),
        backgroundColor: Colors.transparent,
        body: _loaded
            ? _buildBody(context)
            : _reading > 0
                ? const _ReadingPhotos()
                : const SizedBox.shrink(),
        bottomNavigationBar: _loaded ? _buildFooter(context) : null,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final palette = context.palette;
    final text = (_request.cleanText ?? _request.rawText ?? '').trim();
    Widget label(String value) => Padding(
          padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Text(value,
              style: AppText.label.copyWith(color: palette.textSecondary)),
        );
    // One scroll view over a Column, not a lazy ListView: a text field
    // scrolled out of a lazy list would be disposed mid-edit.
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.review, color: palette.primary),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Text('راجع قبل الحفظ', style: AppText.title)),
            ],
          ),
          label('التاريخ'),
          InkWell(
            key: const Key('review-date'),
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: _pickDate,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(AppIcons.calendar, size: 20, color: palette.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                      child: Text(formatFullDate(_date), style: AppText.body)),
                ],
              ),
            ),
          ),
          label('طريقة الدفع'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final MapEntry(key: method, value: methodLabel) in {
                  ...paymentMethodLabels,
                  if (!paymentMethodLabels.containsKey(_paymentMethod))
                    _paymentMethod: _paymentMethod,
                }.entries)
                  SelectableChip(
                    key: Key('payment-$method'),
                    label: methodLabel,
                    icon: AppIcons.payment,
                    selected: _paymentMethod == method,
                    onTap: () => setState(() {
                      _paymentTouched = true;
                      _paymentMethod = method;
                    }),
                  ),
              ],
            ),
          ),
          if (_attachmentViews.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AttachmentStrip(
              attachments: _attachmentViews,
              resolveFile: (path) => _photos.resolve(path),
              playbackFactory:
                  widget.playbackFactory ?? JustAudioVoicePlayback.new,
            ),
          ],
          label('مرفقات'),
          _EvidenceButtons(
            enabled: !_saving && _reading == 0,
            onCamera: _addFromCamera,
            onGallery: _addFromGallery,
            onPdf: _addPdf,
          ),
          if (_reading > 0)
            Padding(
              key: const Key('review-reading'),
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: Semantics(
                liveRegion: true,
                label: 'بقرا الصورة',
                child: const LinearProgressIndicator(),
              ),
            ),
          if (_asksForText) ...[
            label('اكتب اللي اتقال'),
            TextField(
              key: const Key('review-type-text'),
              controller: _typed,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'طماطم ب 30\nعيش ب 10',
                helperText: 'مقدرتش أفهم الكلام، اكتبه وأنا أقسمه سطور',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                key: const Key('review-parse-text'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _parser == null ? null : _parseTyped,
                icon: const Icon(AppIcons.textNote, size: 20),
                label: const Text('حلّل'),
              ),
            ),
          ],
          if (text.isNotEmpty) ...[
            label('اللي اتسجل'),
            Container(
              key: const Key('review-raw-text'),
              padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: palette.textSecondary)),
            ),
          ],
          if (_smartKind case final kind?)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  key: const Key('review-smart'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _improving || _saving || _reading > 0
                      ? null
                      : _improve,
                  icon: _improving
                      ? const SizedBox.square(
                          key: Key('review-smart-busy'),
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.enhance, size: 20),
                  label: Text(kind == SmartInputKind.photo
                      ? 'استخرج بالتفصيل'
                      : 'تحسين'),
                ),
              ),
            ),
          if (_transfersIn.isNotEmpty) _buildIncomingChoice(context),
          label(_expenseLines.isEmpty
              ? 'مفيش سطور'
              : 'السطور (${_expenseLines.length})'),
          // A salary has no category to file: its lines show in the choice.
          for (final line in _expenseLines)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.ms),
              child: Dismissible(
                key: Key('review-line-${line.id}'),
                onDismissed: (_) => _remove(line.id),
                background: const _DismissBackground(
                    alignment: AlignmentDirectional.centerStart),
                secondaryBackground: const _DismissBackground(
                    alignment: AlignmentDirectional.centerEnd),
                child: _LineCard(
                  line: line,
                  categories: _categories,
                  subcategories: _subcategories[line.categoryKey] ?? const [],
                  items: _itemsFor(line),
                  onChanged: _update,
                  onRemove: () => _remove(line.id),
                ),
              ),
            ),
          OutlinedButton.icon(
            key: const Key('review-add-line'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _addLine,
            icon: const Icon(AppIcons.add, size: 20),
            label: const Text('+ سطر'),
          ),
        ],
      ),
    );
  }

  /// Money the user received (spec §6.2): saved as a salary period or as
  /// an expense, the user's call. An uncertain transfer says it is unsure.
  Widget _buildIncomingChoice(BuildContext context) {
    final palette = context.palette;
    final uncertain =
        !_transfersIn.any((l) => l.transfer == TransferDirection.received);
    return Container(
      key: const Key('review-incoming-choice'),
      margin: const EdgeInsetsDirectional.only(top: AppSpacing.md),
      padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(uncertain ? AppIcons.warning : AppIcons.payment,
                  size: 20,
                  color: uncertain ? palette.warning : palette.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  uncertain
                      ? 'مش واضح التحويل ده جالك ولا طلع منك. تسجله إزاي؟'
                      : 'التحويل ده جالك. تسجله مرتب ولا مصروف؟',
                  key: uncertain
                      ? const Key('review-incoming-uncertain')
                      : null,
                  style: AppText.body,
                ),
              ),
            ],
          ),
          if (_asSalary)
            for (final line in _transfersIn)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    const Text('مرتب', style: AppText.body),
                    const Spacer(),
                    Text(
                      formatPiastres(line.amountPiastres ?? 0),
                      key: Key('incoming-amount-${line.id}'),
                      textDirection: TextDirection.ltr,
                      style: AppText.title,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('ج.م',
                        style: AppText.caption
                            .copyWith(color: palette.textSecondary)),
                  ],
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            key: const Key('incoming-segments'),
            style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('مرتب', key: Key('incoming-salary')),
              ),
              ButtonSegment(
                value: false,
                label: Text('مصروف', key: Key('incoming-expense')),
              ),
            ],
            selected: {_asSalary},
            onSelectionChanged: _saving
                ? null
                : (choice) {
                    setState(() => _salaryChoice = choice.single);
                    widget.onEdited?.call();
                  },
          ),
        ],
      ),
    );
  }

  /// The item chips under a line's category (and subcategory, once one
  /// is picked). The linked item always shows, even past the first twelve.
  List<QuickPickItem> _itemsFor(ReviewLine line) {
    final category = line.categoryKey;
    if (category == null) return const [];
    final sub = line.subcategoryKey;
    final matching = [
      for (final i in _items)
        if (i.categoryKey == category &&
            (sub == null || i.subcategoryKey == sub))
          i,
    ];
    final shown = matching.take(12).toList();
    final linked = matching.where((i) => i.id == line.itemId).firstOrNull;
    if (linked != null && !shown.contains(linked)) shown.insert(0, linked);
    return shown;
  }

  Widget _buildFooter(BuildContext context) {
    final palette = context.palette;
    final ready = _canSave;
    final expenses = _expenseLines;
    final blocked = expenses.any((l) => !l.isReady);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(top: BorderSide(color: palette.divider)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('الإجمالي',
                    style:
                        AppText.label.copyWith(color: palette.textSecondary)),
                const Spacer(),
                Text(
                  formatPiastres(reviewTotal(expenses)),
                  key: const Key('review-total'),
                  textDirection: TextDirection.ltr,
                  style: AppText.title,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('ج.م',
                    style:
                        AppText.caption.copyWith(color: palette.textSecondary)),
              ],
            ),
            if (blocked)
              Padding(
                key: const Key('review-blocked'),
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(AppIcons.warning, size: 16, color: palette.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                          expenses.any((l) => l.problems
                                  .contains(ReviewProblem.missingName))
                              ? 'كمّل الاسم والمبلغ والفئة في السطور المعلّمة أو امسحها'
                              : 'كمّل المبلغ والفئة في السطور المعلّمة أو امسحها',
                          style: AppText.caption
                              .copyWith(color: palette.warning)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('review-save'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: ready && !_saving && _reading == 0 ? _save : null,
              child: Text(!_asSalary
                  ? 'حفظ ${_lines.length} مصروف'
                  : expenses.isEmpty
                      ? 'حفظ كمرتب'
                      : 'حفظ مرتب و${expenses.length} مصروف'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('review-note'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _saving ? null : _saveNote,
                    child: const Text('حفظ كملاحظة'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    key: const Key('review-later'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(ReviewOutcome.kept),
                    child: const Text('بعدين'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the sheet shows while a photo capture's photos are read, before
/// there are lines to show.
class _ReadingPhotos extends StatelessWidget {
  const _ReadingPhotos();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      key: const Key('review-reading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.ms),
          Text('بقرا الصورة…',
              style: AppText.body.copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }
}

/// Camera, gallery and PDF: more evidence for the capture (spec §6.2:
/// several photos per capture, invoices as files). Labelled buttons, not
/// bare icons, each at least 48dp.
class _EvidenceButtons extends StatelessWidget {
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onPdf;

  const _EvidenceButtons({
    required this.enabled,
    required this.onCamera,
    required this.onGallery,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(Key key, IconData icon, String text, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
          child: OutlinedButton.icon(
            key: key,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, size: 20),
            label: Text(text),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          button(const Key('review-add-camera'), AppIcons.camera, 'صورة',
              onCamera),
          button(const Key('review-add-gallery'), AppIcons.gallery,
              'من المعرض', onGallery),
          button(const Key('review-add-pdf'), AppIcons.pdf, 'ملف PDF', onPdf),
        ],
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  final AlignmentGeometry alignment;

  const _DismissBackground({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      alignment: alignment,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.negative,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: const Icon(AppIcons.delete, color: Colors.white),
    );
  }
}

/// One line's card: name and amount, quantity and unit, then the category
/// → subcategory → item strips. A field the parser was unsure of gets a
/// warning outline and icon until it is touched; a missing amount or
/// category says so under its field.
class _LineCard extends StatefulWidget {
  final ReviewLine line;
  final List<CategoryView> categories;
  final List<SubcategoryView> subcategories;
  final List<QuickPickItem> items;
  final ValueChanged<ReviewLine> onChanged;
  final VoidCallback onRemove;

  const _LineCard({
    required this.line,
    required this.categories,
    required this.subcategories,
    required this.items,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  late final _name = TextEditingController(text: widget.line.name);
  late final _amount = TextEditingController(text: _amountText(widget.line));
  late final _quantity =
      TextEditingController(text: _quantityText(widget.line));

  static String _amountText(ReviewLine line) =>
      line.amountPiastres == null ? '' : keypadText(line.amountPiastres!);

  static String _quantityText(ReviewLine line) =>
      line.quantityMilli == 1000 && line.unit == null
          ? ''
          : formatQuantityMilli(line.quantityMilli);

  @override
  void didUpdateWidget(_LineCard old) {
    super.didUpdateWidget(old);
    final line = widget.line;
    // Only a change made elsewhere (an item linked, a quantity that moved
    // the amount) rewrites a field, and only when the field no longer
    // reads as the value: a half-typed "15." stays as typed.
    if (old.line.name != line.name && _name.text != line.name) {
      _name.text = line.name;
    }
    if (old.line.amountPiastres != line.amountPiastres &&
        parsePiastres(_amount.text) != line.amountPiastres) {
      _amount.text = _amountText(line);
    }
    if (old.line.quantityMilli != line.quantityMilli &&
        (parseQuantityMilli(_quantity.text) ?? 1000) != line.quantityMilli) {
      _quantity.text = _quantityText(line);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _quantity.dispose();
    super.dispose();
  }

  InputDecoration _decoration(
    BuildContext context, {
    required bool warn,
    required String warningKey,
    String? hint,
    String? helper,
    String? suffix,
  }) {
    final palette = context.palette;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: warn
          ? BorderSide(color: palette.warning, width: 1.5)
          : BorderSide(color: palette.outline),
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      helperText: helper,
      helperStyle: AppText.caption.copyWith(color: palette.warning),
      suffixText: suffix,
      enabledBorder: border,
      border: border,
      suffixIcon: warn
          ? Icon(AppIcons.warning,
              key: Key(warningKey), size: 20, color: palette.warning)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final line = widget.line;
    final problems = line.problems;
    final missingAmount = problems.contains(ReviewProblem.missingAmount);
    final missingCategory = problems.contains(ReviewProblem.missingCategory);
    final missingName = problems.contains(ReviewProblem.missingName);
    final category =
        widget.categories.where((c) => c.key == line.categoryKey).firstOrNull;
    final warnCategory =
        missingCategory || line.uncertain.contains(ReviewField.category);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: problems.isEmpty ? palette.divider : palette.warning,
          width: problems.isEmpty ? 1 : 1.5,
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.ms, AppSpacing.ms, AppSpacing.xs, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('line-name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    context,
                    warn: missingName ||
                        line.uncertain.contains(ReviewField.name),
                    warningKey: 'line-name-warning',
                    hint: 'الاسم',
                    helper: missingName ? 'اكتب اسم المنتج' : null,
                  ),
                  onChanged: (text) => widget.onChanged(line.withName(text)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 124,
                child: TextField(
                  key: const Key('line-amount'),
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  style: AppText.bodyStrong,
                  decoration: _decoration(
                    context,
                    warn: missingAmount ||
                        line.uncertain.contains(ReviewField.amount),
                    warningKey: 'line-amount-warning',
                    hint: '0',
                    helper: missingAmount ? 'اكتب المبلغ' : null,
                    suffix: 'ج.م',
                  ),
                  onChanged: (text) =>
                      widget.onChanged(line.withAmount(parsePiastres(text))),
                ),
              ),
              IconButton(
                key: const Key('line-remove'),
                tooltip: 'امسح السطر',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(AppIcons.close, size: 20, color: palette.textSecondary),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 84,
                child: TextField(
                  key: const Key('line-quantity'),
                  controller: _quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: _decoration(
                    context,
                    warn: line.uncertain.contains(ReviewField.quantity),
                    warningKey: 'line-quantity-warning',
                    hint: '1',
                  ),
                  onChanged: (text) {
                    final quantity = text.trim().isEmpty
                        ? 1000
                        : parseQuantityMilli(text);
                    if (quantity != null) {
                      widget.onChanged(line.withQuantity(quantity));
                    }
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final MapEntry(key: unit, value: unitLabel)
                          in entryUnitLabels.entries)
                        SelectableChip(
                          key: Key('unit-$unit'),
                          label: unitLabel,
                          icon: AppIcons.check,
                          selected: line.unit == unit,
                          onTap: () => widget.onChanged(
                              line.withUnit(line.unit == unit ? null : unit)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (line.reference case final reference?)
            Padding(
              key: const Key('line-reference'),
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(AppIcons.reference,
                      size: 16, color: palette.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text('رقم العملية',
                      style: AppText.caption
                          .copyWith(color: palette.textSecondary)),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(reference,
                        textDirection: TextDirection.ltr,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption),
                  ),
                ],
              ),
            ),
          if (line.barcode case final barcode?)
            Padding(
              key: const Key('line-barcode'),
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(AppIcons.barcode,
                      size: 16, color: palette.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                      line.itemId != null
                          ? 'باركود'
                          : line.fromCatalogue
                              ? 'من الدليل'
                              : 'منتج جديد',
                      style: AppText.caption
                          .copyWith(color: palette.textSecondary)),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(barcode,
                        textDirection: TextDirection.ltr,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption),
                  ),
                ],
              ),
            ),
          if (warnCategory)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(AppIcons.warning,
                      key: const Key('line-category-warning'),
                      size: 16,
                      color: palette.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Text(missingCategory ? 'اختار الفئة' : 'اتأكد من الفئة',
                      style: AppText.caption.copyWith(color: palette.warning)),
                ],
              ),
            ),
          CategoryStrip(
            categories: widget.categories,
            selectedKey: line.categoryKey,
            showAll: false,
            onSelected: (key) {
              if (key != null) widget.onChanged(line.withCategory(key));
            },
          ),
          if (widget.subcategories.isNotEmpty)
            SubcategoryStrip(
              subcategories: widget.subcategories,
              selectedKey: line.subcategoryKey,
              colorKey: category?.colorKey,
              onSelected: (key) =>
                  widget.onChanged(line.withSubcategory(key)),
            ),
          if (widget.items.isNotEmpty)
            SizedBox(
              height: 52,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in widget.items)
                      SelectableChip(
                        key: Key('item-${item.id}'),
                        label: item.nameAr,
                        icon: iconFor(category?.iconName ?? ''),
                        colorKey: category?.colorKey,
                        selected: line.itemId == item.id,
                        onTap: () => widget.onChanged(line.withItem(item)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The before/after comparison of spec §6.6: the lines as they stand and
/// the smart ones, one under the other (side by side does not fit a phone
/// held in one hand), with the rewrite under them. اعتمد pops true.
class _SmartCompareDialog extends StatelessWidget {
  final List<ReviewLine> before;
  final SmartResult after;

  const _SmartCompareDialog({required this.before, required this.after});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget heading(String text) => Padding(
          padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.ms, bottom: AppSpacing.xs),
          child: Text(text,
              style: AppText.label.copyWith(color: palette.textSecondary)),
        );
    Widget row(String name, int quantityMilli, String? unit, int? amount) {
      final quantity = quantityMilli == 1000 && unit == null
          ? ''
          : ' ${formatQuantityMilli(quantityMilli)} '
              '${entryUnitLabels[unit] ?? ''}';
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text('$name$quantity'.trim(), style: AppText.body),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              amount == null ? '—' : formatPiastres(amount),
              textDirection: TextDirection.ltr,
              style: AppText.body.copyWith(
                  color: amount == null ? palette.warning : null),
            ),
          ],
        ),
      );
    }

    int total(Iterable<int?> amounts) =>
        amounts.fold(0, (sum, a) => sum + (a ?? 0));

    return AlertDialog(
      key: const Key('smart-compare'),
      title: Row(
        children: [
          Icon(AppIcons.enhance, color: palette.primary),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('النتيجة الذكية', style: AppText.title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('قبل'),
            if (before.isEmpty)
              Text('مفيش سطور',
                  style: AppText.body.copyWith(color: palette.textSecondary)),
            for (final l in before)
              row(l.name.isEmpty ? '؟' : l.name, l.quantityMilli, l.unit,
                  l.amountPiastres),
            heading('بعد'),
            for (final l in after.lines)
              row(l.name, l.quantityMilli, l.unit, l.amountPiastres),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Text('الإجمالي',
                    style:
                        AppText.label.copyWith(color: palette.textSecondary)),
                const Spacer(),
                Text(
                  '${formatPiastres(total(before.map((l) => l.amountPiastres)))}'
                  ' ← '
                  '${formatPiastres(total(after.lines.map((l) => l.amountPiastres)))}',
                  textDirection: TextDirection.ltr,
                  style: AppText.body,
                ),
              ],
            ),
            if (after.cleanText.trim().isNotEmpty) ...[
              heading('النص بعد التحسين'),
              Container(
                padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Text(after.cleanText.trim(),
                    style: AppText.caption
                        .copyWith(color: palette.textSecondary)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('smart-keep'),
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('سيبه زي ما هو'),
        ),
        FilledButton(
          key: const Key('smart-accept'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('اعتمد'),
        ),
      ],
    );
  }
}
