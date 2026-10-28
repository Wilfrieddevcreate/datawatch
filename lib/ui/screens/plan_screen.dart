import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../domain/data_plan.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/primitives.dart';
import '../widgets/text_tabs.dart';

enum VolumeUnit { mo, go }

/// Choix rapide des seuils d'alerte.
enum ThresholdPreset {
  everyTwenty('Tous les 20 %', DataPlan.everyTwentyThresholds),
  classic('50 · 80 · 100 %', DataPlan.classicThresholds);

  const ThresholdPreset(this.label, this.thresholds);
  final String label;
  final Set<int> thresholds;

  /// Le choix rapide d'où viennent des seuils enregistrés.
  static ThresholdPreset of(Set<int> thresholds) {
    final usesClassic = thresholds.any(
      (t) =>
          DataPlan.classicThresholds.contains(t) &&
          !DataPlan.everyTwentyThresholds.contains(t),
    );
    return usesClassic ? classic : everyTwenty;
  }
}

enum Validity {
  day('24${nbsp}h', Duration(hours: 24)),
  week('7 jours', Duration(days: 7)),
  month('30 jours', Duration(days: 30)),
  custom('Autre', null);

  const Validity(this.label, this.duration);
  final String label;
  final Duration? duration;

  static Validity of(Duration d) => Validity.values.firstWhere(
    (v) => v.duration == d,
    orElse: () => Validity.custom,
  );
}

/// Volume saisi (« 5 », « 1,5 », « 5 120 ») converti en octets.
int? parseVolume(String text, VolumeUnit unit) {
  final cleaned = text
      .replaceAll(RegExp(r'[\s ]'), '')
      .replaceAll(',', '.');
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  final factor = unit == VolumeUnit.go
      ? DataUnits.bytesPerGo
      : DataUnits.bytesPerMo;
  return (value * factor).round();
}

/// Texte du champ pour un volume donné, dans l'unité choisie.
String volumeText(int bytes, VolumeUnit unit) => unit == VolumeUnit.go
    ? formatNumber(bytes / DataUnits.bytesPerGo)
    : formatNumber(bytes / DataUnits.bytesPerMo, maxDecimals: 0);

/// Le blanc de la phrase en cours d'édition.
enum _Blank { operator, volume, validity }

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.actions, required this.onSaved});

  final List<Widget> actions;
  final VoidCallback onSaved;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  static const _presets = [
    500 * DataUnits.bytesPerMo,
    DataUnits.bytesPerGo,
    2 * DataUnits.bytesPerGo,
    5 * DataUnits.bytesPerGo,
    10 * DataUnits.bytesPerGo,
  ];

  final _volume = TextEditingController();
  Operator _operator = Operator.mtn;
  VolumeUnit _unit = VolumeUnit.go;
  late DateTime _start;
  Validity _validity = Validity.week;
  DateTime? _customEnd;
  Set<int> _thresholds = {...DataPlan.defaultThresholds};
  ThresholdPreset _preset = ThresholdPreset.everyTwenty;
  bool _recurring = false;
  String? _volumeError;
  _Blank _blank = _Blank.volume;
  bool _customVolume = false;

  DataPlan? _loadedFrom;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final plan = AppScope.of(context).plan;
    if (!_initialized || !identical(plan, _loadedFrom)) {
      _fillFrom(plan);
      _initialized = true;
    }
  }

  void _fillFrom(DataPlan? plan) {
    _loadedFrom = plan;
    _volumeError = null;
    if (plan == null) {
      _operator = Operator.mtn;
      _unit = VolumeUnit.go;
      _volume.text = '';
      _customVolume = false;
      _start = _nowMinute();
      _validity = Validity.week;
      _customEnd = null;
      _thresholds = {...DataPlan.defaultThresholds};
      _preset = ThresholdPreset.everyTwenty;
      _recurring = false;
      return;
    }
    _operator = plan.operator;
    _unit = plan.volumeBytes >= DataUnits.bytesPerGo
        ? VolumeUnit.go
        : VolumeUnit.mo;
    _volume.text = volumeText(plan.volumeBytes, _unit);
    _customVolume = !_presets.contains(plan.volumeBytes);
    _start = plan.start;
    _validity = Validity.of(plan.validity);
    _customEnd = _validity == Validity.custom ? plan.end : null;
    _thresholds = {...plan.thresholds};
    _preset = ThresholdPreset.of(plan.thresholds);
    _recurring = plan.recurring;
  }

  @override
  void dispose() {
    _volume.dispose();
    super.dispose();
  }

  DateTime _nowMinute() {
    final n = AppScope.of(context).now();
    return DateTime(n.year, n.month, n.day, n.hour, n.minute);
  }

  int? get _volumeBytes => parseVolume(_volume.text, _unit);

  DateTime? get _end => _validity == Validity.custom
      ? _customEnd
      : _start.add(_validity.duration!);

  void _setUnit(VolumeUnit unit) {
    if (unit == _unit) return;
    final bytes = _volumeBytes;
    setState(() {
      _unit = unit;
      if (bytes != null) _volume.text = volumeText(bytes, unit);
    });
  }

  void _setPreset(int bytes) {
    setState(() {
      _unit = bytes >= DataUnits.bytesPerGo ? VolumeUnit.go : VolumeUnit.mo;
      _volume.text = volumeText(bytes, _unit);
      _customVolume = false;
      _volumeError = null;
    });
  }

  Future<void> _pickStart() async {
    final now = AppScope.of(context).now();
    final date = await showDatePicker(
      context: context,
      initialDate: _start.isAfter(now) ? now : _start,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      helpText: 'Début du forfait',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      helpText: 'Heure d’achat ou d’activation',
    );
    if (time == null) return;
    var picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isAfter(now)) picked = _nowMinute();
    setState(() => _start = picked);
  }

  Future<void> _pickCustomEnd() async {
    final initial = _customEnd ?? _start.add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _start,
      lastDate: _start.add(const Duration(days: 366)),
      helpText: 'Fin du forfait',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(() {
      _validity = Validity.custom;
      _customEnd = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  DataPlan? _buildPlan() {
    final bytes = _volumeBytes;
    final end = _end;
    if (bytes == null) {
      setState(() {
        _blank = _Blank.volume;
        _customVolume = true;
        _volumeError = 'Indiquez le volume de votre forfait.';
      });
      return null;
    }
    if (end == null || !end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choisissez une date de fin après le début du forfait.',
          ),
        ),
      );
      return null;
    }
    return DataPlan(
      operator: _operator,
      volumeBytes: bytes,
      start: _start,
      end: end,
      thresholds: _thresholds,
      recurring: _recurring,
    );
  }

  Future<void> _save({String message = 'Forfait enregistré'}) async {
    final plan = _buildPlan();
    if (plan == null) return;
    final controller = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    await controller.savePlan(plan);
    messenger.showSnackBar(SnackBar(content: Text(message)));
    // Moment le plus parlant pour demander l'autorisation de notifier :
    // l'utilisateur vient de choisir ses seuils (Android 13+).
    if (controller.settings.notificationsEnabled &&
        plan.thresholds.isNotEmpty) {
      await controller.ensureNotificationPermission();
    }
    widget.onSaved();
  }

  Future<void> _addThreshold() async {
    final existing = {..._preset.thresholds, ..._thresholds};
    final bytes = _volumeBytes;
    var value = existing.contains(90) ? 70 : 90;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final t = Theme.of(context).textTheme;
          final taken = existing.contains(value);
          return AlertDialog(
            title: const Text('Nouveau seuil'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$value$nbsp%', style: DwFonts.hero(44)),
                Slider(
                  value: value.toDouble(),
                  min: 10,
                  max: 95,
                  divisions: 17,
                  label: '$value$nbsp%',
                  onChanged: (v) => setLocal(() => value = v.round()),
                ),
                Text(
                  taken
                      ? 'Ce seuil existe déjà.'
                      : bytes == null
                      ? 'du volume déclaré'
                      : 'soit ${formatBytes(bytes * value ~/ 100)} consommés',
                  style: t.bodyMedium!.copyWith(
                    color: context.dw.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: taken ? null : () => Navigator.pop(context, value),
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) setState(() => _thresholds = {..._thresholds, picked});
  }

  void _toggleThreshold(int pct) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_thresholds.contains(pct)) {
        _thresholds = _thresholds.where((t) => t != pct).toSet();
      } else {
        _thresholds = {..._thresholds, pct};
      }
    });
  }

  Future<void> _restartNow() async {
    setState(() {
      final duration = _end?.difference(_start);
      _start = _nowMinute();
      if (_validity == Validity.custom && duration != null) {
        _customEnd = _start.add(duration);
      }
    });
    await _save(message: 'Nouveau suivi démarré');
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser le forfait ?'),
        content: const Text(
          'Le forfait déclaré et ses seuils seront effacés de ce téléphone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.dw.critical),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.of(context).clearPlan();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final controller = AppScope.of(context);
    final saved = controller.plan;
    final now = controller.now();
    final hasPlan = saved != null;
    final bytes = _volumeBytes;
    final end = _end;
    final marks = ({..._preset.thresholds, ..._thresholds}.toList()..sort());

    return DwPage(
      title: 'Mon forfait',
      overline: saved == null
          ? null
          : '${saved.operator.label} · ${formatBytes(saved.volumeBytes)} · ${saved.isExpired(now) ? 'expiré' : 'actif'}',
      subtitle: Text(
        saved == null
            ? 'Dites ce que vous avez acheté, DataWatch estime le reste.'
            : saved.isExpired(now)
            ? 'Expiré le ${formatDayMonthTime(saved.end)}. Démarrez un nouveau suivi après votre recharge.'
            : 'Expire dans ${formatRemaining(saved.end.difference(now))}, le ${formatDayMonthTime(saved.end)}.',
      ),
      actions: widget.actions,
      children: [
        DwReveal(
          child: DwSheet(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sentence(
                  operator: _operator.label,
                  volume: bytes == null ? '…' : formatBytes(bytes),
                  start:
                      '${formatDayMonth(_start)} à ${formatTime(_start)}',
                  validity: _validity == Validity.custom
                      ? (end == null
                            ? 'une date au choix'
                            : 'jusqu’au ${formatDayMonthTime(end)}')
                      : _validity.label,
                  active: _blank,
                  onOperator: () => setState(() => _blank = _Blank.operator),
                  onVolume: () => setState(() => _blank = _Blank.volume),
                  onStart: _pickStart,
                  onValidity: () => setState(() => _blank = _Blank.validity),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.divider)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (_blank) {
                          _Blank.operator => 'Opérateur',
                          _Blank.volume => 'Volume du forfait',
                          _Blank.validity => 'Validité',
                        },
                        style: t.bodySmall!.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      switch (_blank) {
                        _Blank.operator => DwChoiceWords<Operator>(
                          values: Operator.values,
                          selected: _operator,
                          labelOf: (o) => o.label,
                          onChanged: (o) => setState(() => _operator = o),
                        ),
                        _Blank.validity => DwChoiceWords<Validity>(
                          values: Validity.values,
                          selected: _validity,
                          labelOf: (v) => v.label,
                          onChanged: (v) => v == Validity.custom
                              ? _pickCustomEnd()
                              : setState(() => _validity = v),
                        ),
                        _Blank.volume => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DwChoiceWords<int?>(
                              values: [..._presets, null],
                              selected: _customVolume
                                  ? null
                                  : (_presets.contains(bytes) ? bytes : -1),
                              labelOf: (b) =>
                                  b == null ? 'Autre…' : formatBytes(b),
                              onChanged: (b) => b == null
                                  ? setState(() => _customVolume = true)
                                  : _setPreset(b),
                            ),
                            if (_customVolume) ...[
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _volume,
                                      autofocus: _volume.text.isEmpty,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9,.\s]'),
                                        ),
                                      ],
                                      onChanged: (_) =>
                                          setState(() => _volumeError = null),
                                      style: DwFonts.hero(44),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: TextStyle(color: c.track),
                                        errorText: _volumeError,
                                        filled: false,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        border: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: c.accent,
                                            width: 3,
                                          ),
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: c.accent,
                                            width: 3,
                                          ),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: c.strong,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: DwChoiceWords<VolumeUnit>(
                                      values: VolumeUnit.values,
                                      selected: _unit,
                                      spacing: 12,
                                      labelOf: (u) =>
                                          u == VolumeUnit.go ? 'Go' : 'Mo',
                                      onChanged: _setUnit,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      },
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: bytes == null
                            ? '1${nbsp}Go = 1${nbsp}024${nbsp}Mo'
                            : _unit == VolumeUnit.go
                            ? '= ${formatThousands((bytes / DataUnits.bytesPerMo).round())}${nbsp}Mo'
                            : '= ${formatNumber(bytes / DataUnits.bytesPerGo)}${nbsp}Go',
                      ),
                      const TextSpan(text: ' · fin du suivi le '),
                      TextSpan(
                        text: end == null
                            ? 'à choisir'
                            : '${formatDate(end)} à ${formatTime(end)}',
                        style: TextStyle(color: c.text).weight(600),
                      ),
                    ],
                  ),
                  style: t.bodySmall!.copyWith(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        DwReveal(
          delay: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DwSectionTitle(
                'Seuils d’alerte',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      controller.alertsActive
                          ? Icons.notifications_none
                          : Icons.notifications_off_outlined,
                      size: 15,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      controller.alertsActive
                          ? 'Notifications activées'
                          : 'Notifications coupées',
                      style: t.bodySmall!.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DwSheet(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ThresholdRuler(
                      marks: marks,
                      enabled: _thresholds,
                      amountOf: (pct) => bytes == null
                          ? null
                          : formatBytes(bytes * pct ~/ 100),
                      onTap: _toggleThreshold,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.divider)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DwChoiceWords<ThresholdPreset>(
                              values: ThresholdPreset.values,
                              selected:
                                  _thresholds.length ==
                                          _preset.thresholds.length &&
                                      _thresholds.containsAll(
                                        _preset.thresholds,
                                      )
                                  ? _preset
                                  : null,
                              labelOf: (p) => p.label,
                              onChanged: (p) => setState(() {
                                _preset = p;
                                _thresholds = {...p.thresholds};
                              }),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addThreshold,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              textStyle: t.titleSmall,
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Seuil'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AlertsStatus(
                      controller: controller,
                      nextThreshold: _thresholds.isEmpty
                          ? null
                          : (_thresholds.toList()..sort()).first,
                      bytes: bytes,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        DwReveal(
          delay: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DwSectionTitle('Renouvellement'),
              const SizedBox(height: 12),
              DwSheet(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Forfait récurrent', style: t.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            'À l’expiration, DataWatch propose de relancer le suivi avec les mêmes réglages. Il ne voit pas vos achats : après une recharge, démarrez un nouveau suivi.',
                            style: t.bodyMedium!.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: _recurring,
                      onChanged: (v) => setState(() => _recurring = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        DwReveal(
          delay: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DwPrimaryButton(
                label: 'Enregistrer le forfait',
                onPressed: _save,
              ),
              if (hasPlan) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _restartNow,
                        child: const Text('Nouveau suivi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: _reset,
                        style: TextButton.styleFrom(
                          foregroundColor: c.critical,
                        ),
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// « Je suis chez MTN, j’ai pris 5 Go le 15 oct. à 08:30, valable 7 jours. »
class _Sentence extends StatelessWidget {
  const _Sentence({
    required this.operator,
    required this.volume,
    required this.start,
    required this.validity,
    required this.active,
    required this.onOperator,
    required this.onVolume,
    required this.onStart,
    required this.onValidity,
  });

  final String operator;
  final String volume;
  final String start;
  final String validity;
  final _Blank? active;
  final VoidCallback onOperator;
  final VoidCallback onVolume;
  final VoidCallback onStart;
  final VoidCallback onValidity;

  @override
  Widget build(BuildContext context) {
    final style = DwFonts.style(
      DwFonts.display,
      26,
      600,
      height: 1.45,
      letterSpacing: -0.5,
    ).copyWith(color: context.dw.text);
    WidgetSpan blank(
      String label,
      String semantic,
      bool on,
      VoidCallback onTap,
    ) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: _BlankButton(
        label: label,
        semanticLabel: semantic,
        active: on,
        style: style,
        onTap: onTap,
      ),
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Je suis chez '),
          blank(
            operator,
            'Opérateur : $operator, modifier',
            active == _Blank.operator,
            onOperator,
          ),
          const TextSpan(text: ', j’ai pris '),
          blank(
            volume,
            'Volume : $volume, modifier',
            active == _Blank.volume,
            onVolume,
          ),
          const TextSpan(text: ' le '),
          blank(start, 'Début : $start, modifier', false, onStart),
          const TextSpan(text: ', valable '),
          blank(
            validity,
            'Validité : $validity, modifier',
            active == _Blank.validity,
            onValidity,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

class _BlankButton extends StatelessWidget {
  const _BlankButton({
    required this.label,
    required this.semanticLabel,
    required this.active,
    required this.style,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool active;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DwRadius.xs),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? c.accent : c.accent.withValues(alpha: 0.45),
                width: 3,
              ),
            ),
          ),
          child: Text(label, style: style.copyWith(height: 1.1)),
        ),
      ),
    );
  }
}

/// La règle des seuils : un point par seuil, coché ou non, posé à son
/// pourcentage le long d'un trait.
class _ThresholdRuler extends StatelessWidget {
  const _ThresholdRuler({
    required this.marks,
    required this.enabled,
    required this.amountOf,
    required this.onTap,
  });

  final List<int> marks;
  final Set<int> enabled;
  final String? Function(int) amountOf;
  final ValueChanged<int> onTap;

  static const _inset = 22.0;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final active = marks.where(enabled.contains).toList();
    final maxOn = active.isEmpty ? 0 : active.last;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        double x(int pct) => _inset + (w - 2 * _inset) * pct / 100;
        return SizedBox(
          height: 66,
          child: Stack(
            children: [
              Positioned(
                left: _inset,
                right: _inset,
                top: 21,
                child: Container(height: 2, color: c.divider),
              ),
              Positioned(
                left: _inset,
                top: 21,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  width: x(maxOn) - _inset,
                  height: 2,
                  color: c.strong,
                ),
              ),
              for (final pct in marks)
                Positioned(
                  left: x(pct) - 22,
                  top: 0,
                  width: 44,
                  height: 66,
                  child: _Mark(
                    pct: pct,
                    on: enabled.contains(pct),
                    amount: amountOf(pct),
                    onTap: () => onTap(pct),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.pct,
    required this.on,
    required this.amount,
    required this.onTap,
  });

  final int pct;
  final bool on;
  final String? amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Semantics(
      toggled: on,
      button: true,
      label:
          'Alerte à $pct %${amount == null ? '' : ', soit $amount consommés'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DwRadius.sm),
        child: Column(
          children: [
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: on ? c.accent : c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: on ? c.strong : c.track, width: 2),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$pct$nbsp%',
              style: DwFonts.style(
                DwFonts.body,
                11.5,
                600,
                tabular: true,
              ).copyWith(color: on ? c.text : c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ce qui empêcherait les alertes de s'afficher, avec le moyen d'y remédier ;
/// sinon, le prochain seuil.
class _AlertsStatus extends StatelessWidget {
  const _AlertsStatus({
    required this.controller,
    required this.nextThreshold,
    required this.bytes,
  });

  final AppController controller;
  final int? nextThreshold;
  final int? bytes;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final settings = controller.settings;

    if (controller.alertsActive) {
      final next = nextThreshold;
      return Text(
        next == null
            ? 'Aucun seuil : vous ne serez pas prévenu.'
            : 'Une seule notification par seuil et par forfait, vérifiée environ toutes les 15 minutes.'
                  '${bytes == null ? '' : ' Premier seuil : $next$nbsp%, soit ${formatBytes(bytes! * next ~/ 100)} consommés.'}',
        style: t.bodySmall!.copyWith(color: c.textSecondary),
      );
    }
    final (text, action, onPressed) = !settings.notificationsEnabled
        ? (
            'Les alertes sont désactivées dans les paramètres.',
            'Activer',
            () => controller.setNotificationsEnabled(true),
          )
        : (
            'Android bloque les notifications de DataWatch.',
            'Autoriser',
            () async {
              if (!await controller.ensureNotificationPermission()) {
                await controller.openNotificationSettings();
              }
            },
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.warningSoft,
        borderRadius: BorderRadius.circular(DwRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 18,
            color: c.warningText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: t.bodyMedium!.copyWith(color: c.text)),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(foregroundColor: c.warningText),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
