import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Offline text recognition for photos (spec §6.2). Only Latin script:
/// ML Kit has no Arabic model, so this reads amounts, dates, references and
/// Latin brand names, and `readPhotoText` makes sense of them. Behind an
/// interface so widget tests hand in the text instead of a model.
abstract class TextRecognitionService {
  /// The text on the image at [absolutePath], one recognised line per line.
  /// Throws when the image cannot be read.
  Future<String> recognize(String absolutePath);
}

/// ML Kit's bundled Latin model: on the phone, with no download and no
/// network.
class MlKitTextRecognitionService implements TextRecognitionService {
  @override
  Future<String> recognize(String absolutePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(absolutePath));
      // Line by line, block order: a label and the figure under it stay on
      // neighbouring lines, which is how the reader pairs them.
      return [
        for (final block in result.blocks)
          for (final line in block.lines) line.text,
      ].join('\n');
    } finally {
      await recognizer.close();
    }
  }
}
