import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/tokens.dart';
import '../../../data/gemini_key_store.dart';
import '../../../data/net/gemini_client.dart';
import '../../../domain/online_features.dart';
import '../../../domain/spending_repository.dart';

/// The label of each online feature's switch (spec §4.6).
const _featureLabels = {
  OnlineFeature.gemini: 'تحسين ذكي بـ Gemini',
  OnlineFeature.geminiAudio: 'فهم الصوت بـ Gemini',
  OnlineFeature.productLookup: 'اسم المنتج من الباركود (Open Food Facts)',
  OnlineFeature.onlineSpeech: 'التعرف على الكلام أونلاين',
};

/// Online features (spec §4.6): the master switch, one switch per feature
/// under it, the Gemini key with a test button, the model id, and the
/// warning that the data goes to Google.
///
/// A feature's switch keeps its own choice while the master is off (it is
/// only greyed out), so turning the master back on restores what was on.
/// The key is written to secure storage and never shown again once saved:
/// the field stays empty with "المفتاح محفوظ" under it.
class OnlineSettingsSection extends StatefulWidget {
  final SpendingRepository repository;
  final GeminiKeyStore keyStore;
  final GeminiClient gemini;

  const OnlineSettingsSection({
    super.key,
    required this.repository,
    required this.keyStore,
    required this.gemini,
  });

  @override
  State<OnlineSettingsSection> createState() => _OnlineSettingsSectionState();
}

class _OnlineSettingsSectionState extends State<OnlineSettingsSection> {
  SpendingRepository get _repo => widget.repository;

  final _key = TextEditingController();
  final _model = TextEditingController(text: defaultGeminiModel);
  bool _master = false;
  Map<OnlineFeature, bool> _features = {
    for (final f in OnlineFeature.values) f: false,
  };
  bool _keySaved = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final master = await _repo.setting(onlineFeaturesSettingKey) == 'true';
    final features = {
      for (final f in OnlineFeature.values)
        f: await _repo.setting(f.settingKey) == 'true',
    };
    final model = await _repo.setting(geminiModelSettingKey);
    // Secure storage can be unavailable (a device without a keystore, a
    // test): then no key is saved as far as this screen knows.
    var keySaved = false;
    try {
      keySaved = ((await widget.keyStore.read())?.trim() ?? '').isNotEmpty;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _master = master;
      _features = features;
      _keySaved = keySaved;
      if (model != null && model.trim().isNotEmpty) _model.text = model;
    });
  }

  Future<void> _setMaster(bool on) async {
    setState(() => _master = on);
    await _repo.setSetting(onlineFeaturesSettingKey, '$on');
  }

  Future<void> _setFeature(OnlineFeature feature, bool on) async {
    setState(() => _features = {..._features, feature: on});
    await _repo.setSetting(feature.settingKey, '$on');
  }

  Future<void> _saveKey() async {
    final key = _key.text.trim();
    if (key.isEmpty) return;
    try {
      await widget.keyStore.write(key);
    } catch (_) {
      _say('ما قدرتش أحفظ المفتاح، جرب تاني');
      return;
    }
    _key.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _keySaved = true);
    _say('اتحفظ المفتاح');
  }

  Future<void> _clearKey() async {
    try {
      await widget.keyStore.write(null);
    } catch (_) {
      _say('ما قدرتش أمسح المفتاح، جرب تاني');
      return;
    }
    if (mounted) setState(() => _keySaved = false);
  }

  /// Tries the typed key when there is one, so a key can be checked before
  /// it is saved; otherwise the saved one.
  Future<void> _test() async {
    var key = _key.text.trim();
    if (key.isEmpty && _keySaved) {
      try {
        key = (await widget.keyStore.read())?.trim() ?? '';
      } catch (_) {}
    }
    if (key.isEmpty) {
      _say('اكتب المفتاح الأول');
      return;
    }
    setState(() => _testing = true);
    final result = await widget.gemini.check(key: key, model: _model.text);
    if (!mounted) return;
    setState(() => _testing = false);
    _say(switch (result) {
      GeminiCheck.works => 'المفتاح شغال',
      GeminiCheck.fails => 'المفتاح مش شغال أو مفيش نت',
      GeminiCheck.switchedOff => 'شغّل المزايا الأونلاين وتحسين Gemini الأول',
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('settings-online-warning'),
          padding: const EdgeInsetsDirectional.all(AppSpacing.ms),
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.warning, size: 20, color: palette.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'البيانات بتتبعت لجوجل. في الخطة المجانية ممكن تُستخدم '
                  'لتحسين خدماتهم.',
                  style: AppText.caption.copyWith(color: palette.textPrimary),
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          key: const Key('settings-online-master'),
          contentPadding: EdgeInsetsDirectional.zero,
          secondary: Icon(AppIcons.online, color: palette.primary),
          title: const Text('تشغيل المزايا الأونلاين', style: AppText.body),
          subtitle: Text(
            _master
                ? 'المزايا اللي تحت بس هي اللي تكلم النت'
                : 'مقفولة: التطبيق مش بيكلم النت خالص',
            style: AppText.caption.copyWith(color: palette.textSecondary),
          ),
          value: _master,
          onChanged: _setMaster,
        ),
        for (final feature in OnlineFeature.values)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.lg),
            child: SwitchListTile(
              key: Key('settings-online-${feature.name}'),
              contentPadding: EdgeInsetsDirectional.zero,
              title: Text(_featureLabels[feature]!, style: AppText.body),
              value: _features[feature]!,
              onChanged: _master ? (on) => _setFeature(feature, on) : null,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('settings-gemini-key'),
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'مفتاح Gemini',
            helperText: _keySaved ? 'المفتاح محفوظ' : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            FilledButton(
              key: const Key('settings-gemini-key-save'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _saveKey,
              child: const Text('حفظ المفتاح'),
            ),
            OutlinedButton.icon(
              key: const Key('settings-gemini-test'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(AppIcons.check, size: 20),
              label: const Text('اختبار'),
            ),
            if (_keySaved)
              TextButton(
                key: const Key('settings-gemini-key-clear'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _clearKey,
                child: const Text('امسح المفتاح'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('settings-gemini-model'),
          controller: _model,
          autocorrect: false,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'الموديل'),
          onChanged: (value) =>
              _repo.setSetting(geminiModelSettingKey, value.trim()),
        ),
      ],
    );
  }
}
