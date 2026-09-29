import '../domain/gemini_usage.dart';
import '../domain/spending_repository.dart';

/// Keeps the Gemini usage counters in `app_settings`, one JSON row a month
/// under [geminiUsageSettingKey] (see [GeminiMonthUsage]).
class GeminiUsageLog {
  GeminiUsageLog(this._repository);

  final SpendingRepository _repository;

  /// Writes are read, add, write back. Two requests finishing together
  /// would otherwise both read the same row and one would be lost, so all
  /// writes to one repository queue here, whichever log instance makes
  /// them.
  static final _queues = Expando<Future<void>>('gemini usage writes');

  Future<void> get _queue => _queues[_repository] ?? Future.value();
  set _queue(Future<void> next) => _queues[_repository] = next;

  static String _monthOf(String key) => key.substring(key.indexOf(':') + 1);

  /// Adds [event] to its month. Never throws: a counter that cannot be
  /// written must not turn a working request into a failed one.
  Future<void> record(GeminiUsageEvent event) {
    final next = _queue.then((_) async {
      try {
        final key = geminiUsageSettingKey(event.at);
        final month = GeminiMonthUsage.fromJson(
            _monthOf(key), await _repository.setting(key));
        await _repository.setSetting(key, month.recorded(event).toJson());
      } catch (_) {}
    });
    _queue = next;
    return next;
  }

  /// [at]'s month so far.
  Future<GeminiMonthUsage> month(DateTime at) async {
    final key = geminiUsageSettingKey(at);
    await _queue;
    return GeminiMonthUsage.fromJson(
        _monthOf(key), await _repository.setting(key));
  }

  /// «مسح العداد»: [at]'s month starts from nothing again.
  Future<void> reset(DateTime at) {
    final next = _queue
        .then((_) => _repository.setSetting(geminiUsageSettingKey(at), ''));
    _queue = next.catchError((_) {});
    return next;
  }
}
