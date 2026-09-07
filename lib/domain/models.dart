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

class SubcategoryView extends Equatable {
  final String key;
  final String categoryKey;
  final String labelAr;
  final String iconName;

  const SubcategoryView({
    required this.key,
    required this.categoryKey,
    required this.labelAr,
    required this.iconName,
  });

  @override
  List<Object?> get props => [key, categoryKey, labelAr, iconName];
}

class QuickPickItem extends Equatable {
  final String id;
  final String nameAr;
  final int? defaultAmountPiastres;
  final String categoryKey;

  /// The item's own subcategory in the catalogue, if it has one — null for
  /// the genuine one-offs that were never classified past their category.
  final String? subcategoryKey;

  const QuickPickItem({
    required this.id,
    required this.nameAr,
    required this.categoryKey,
    this.defaultAmountPiastres,
    this.subcategoryKey,
  });

  @override
  List<Object?> get props =>
      [id, nameAr, defaultAmountPiastres, categoryKey, subcategoryKey];
}

class DraftEntry extends Equatable {
  final int? amountPiastres;
  final String? itemId;
  final String? description;
  final String? categoryKey;
  final String? subcategoryKey;
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
    this.subcategoryKey,
    this.paymentMethod,
    this.photoPath,
    this.voiceNotePath,
    required this.source,
    this.confidence = 1.0,
  });

  bool get isComplete => amountPiastres != null && categoryKey != null;

  /// Returns a copy with [photoPath] replaced — including replacing it
  /// with null to remove a previously attached photo. Kept separate from
  /// [copyWith], whose `??`-based fields can't express "clear this value".
  DraftEntry withPhotoPath(String? photoPath) => DraftEntry(
        amountPiastres: amountPiastres,
        itemId: itemId,
        description: description,
        categoryKey: categoryKey,
        subcategoryKey: subcategoryKey,
        paymentMethod: paymentMethod,
        photoPath: photoPath,
        voiceNotePath: voiceNotePath,
        source: source,
        confidence: confidence,
      );

  DraftEntry copyWith({
    int? amountPiastres,
    String? description,
    String? categoryKey,
    String? subcategoryKey,
    String? paymentMethod,
  }) =>
      DraftEntry(
        amountPiastres: amountPiastres ?? this.amountPiastres,
        itemId: itemId,
        description: description ?? this.description,
        categoryKey: categoryKey ?? this.categoryKey,
        subcategoryKey: subcategoryKey ?? this.subcategoryKey,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        photoPath: photoPath,
        voiceNotePath: voiceNotePath,
        source: source,
        confidence: confidence,
      );

  @override
  List<Object?> get props => [
        amountPiastres,
        itemId,
        description,
        categoryKey,
        subcategoryKey,
        paymentMethod,
        source
      ];
}
