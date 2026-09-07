import 'package:equatable/equatable.dart';

enum EntrySource { quickPick, barcode, ocr, imageLabel, voice, manual }

class PeriodSummary extends Equatable {
  final int salaryPiastres;
  final int spentPiastres;
  final int daysRemaining;

  const PeriodSummary({
    required this.salaryPiastres,
    required this.spentPiastres,
    required this.daysRemaining,
  });

  int get leftPiastres => salaryPiastres - spentPiastres;

  /// Null when nothing is left. A negative daily allowance is noise; the red
  /// `left` figure already carries the message.
  int? get safeDailyPiastres {
    if (leftPiastres <= 0 || daysRemaining <= 0) return null;
    return leftPiastres ~/ daysRemaining;
  }

  @override
  List<Object?> get props => [salaryPiastres, spentPiastres, daysRemaining];
}

class EntryView extends Equatable {
  final String id;
  final String displayName;
  final int amountPiastres;
  final String categoryKey;
  final String categoryLabelAr;
  final DateTime date;

  const EntryView({
    required this.id,
    required this.displayName,
    required this.amountPiastres,
    required this.categoryKey,
    required this.categoryLabelAr,
    required this.date,
  });

  @override
  List<Object?> get props =>
      [id, displayName, amountPiastres, categoryKey, date];
}

class CategoryView extends Equatable {
  final String key;
  final String labelAr;
  final String iconName;

  const CategoryView({
    required this.key,
    required this.labelAr,
    required this.iconName,
  });

  @override
  List<Object?> get props => [key, labelAr, iconName];
}

class QuickPickItem extends Equatable {
  final String id;
  final String nameAr;
  final int? defaultAmountPiastres;
  final String categoryKey;

  const QuickPickItem({
    required this.id,
    required this.nameAr,
    required this.categoryKey,
    this.defaultAmountPiastres,
  });

  @override
  List<Object?> get props => [id, nameAr, defaultAmountPiastres, categoryKey];
}

class DraftEntry extends Equatable {
  final int? amountPiastres;
  final String? itemId;
  final String? description;
  final String? categoryKey;
  final String? paymentMethod;
  final String? photoPath;
  final String? voiceNotePath;
  final EntrySource source;
  final double confidence;

  const DraftEntry({
    this.amountPiastres,
    this.itemId,
    this.description,
    this.categoryKey,
    this.paymentMethod,
    this.photoPath,
    this.voiceNotePath,
    required this.source,
    this.confidence = 1.0,
  });

  bool get isComplete => amountPiastres != null && categoryKey != null;

  DraftEntry copyWith({
    int? amountPiastres,
    String? description,
    String? categoryKey,
    String? paymentMethod,
  }) =>
      DraftEntry(
        amountPiastres: amountPiastres ?? this.amountPiastres,
        itemId: itemId,
        description: description ?? this.description,
        categoryKey: categoryKey ?? this.categoryKey,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        photoPath: photoPath,
        voiceNotePath: voiceNotePath,
        source: source,
        confidence: confidence,
      );

  @override
  List<Object?> get props =>
      [amountPiastres, itemId, description, categoryKey, paymentMethod, source];
}
