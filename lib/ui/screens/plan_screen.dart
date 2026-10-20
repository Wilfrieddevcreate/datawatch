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
import '../widgets/segmented.dart';
import '../widgets/usage_row.dart';

enum VolumeUnit { mo, go }

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
      .replaceAll(RegExp(r'[\s\u00A0]'), '')
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
  bool _recurring = false;
  String? _volumeError;

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
      _start = _nowMinute();
      _validity = Validity.week;
      _customEnd = null;
      _thresholds = {...DataPlan.defaultThresholds};
      _recurring = false;
      return;
    }
    _operator = plan.operator;
    _unit = plan.volumeBytes >= DataUnits.bytesPerGo
        ? VolumeUnit.go
        : VolumeUnit.mo;
    _volume.text = volumeText(plan.volumeBytes, _unit);
    _start = plan.start;
    _validity = Validity.of(plan.validity);
    _customEnd = _validity == Validity.custom ? plan.end : null;
    _thresholds = {...plan.thresholds};
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
      setState(() => _volumeError = 'Indiquez le volume de votre forfait.');
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
    final existing = {...DataPlan.defaultThresholds, ..._thresholds};
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
                Text(
                  '$value$nbsp%',
                  style: DwFonts.style(
                    DwFonts.display,
                    40,
                    700,
                    letterSpacing: -1.2,
                  ),
                ),
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

    return DwPage(
      title: 'Mon forfait',
      overline: saved == null
          ? 'Aucun forfait déclaré'
          : '${saved.operator.label} · ${formatBytes(saved.volumeBytes)} · ${saved.isExpired(now) ? 'expiré' : 'actif'}',
      subtitle: Text(
        saved == null
            ? 'Déclarez votre forfait pour suivre ce qu’il reste.'
            : saved.isExpired(now)
            ? 'Expiré le ${formatDayMonthTime(saved.end)}. Démarrez un nouveau suivi après votre recharge.'
            : 'Expire dans ${formatRemaining(saved.end.difference(now))}, le ${formatDayMonthTime(saved.end)}.',
      ),
      actions: widget.actions,
      children: [
        _Section(
          title: 'Opérateur',
          child: DwSegmented<Operator>(
            values: Operator.values,
            selected: _operator,
            fontSize: 14,
            trackColor: c.background,
            labelOf: (o) => o.label,
            onChanged: (o) => setState(() => _operator = o),
          ),
        ),
        const SizedBox(height: 12),

        _Section(
          title: 'Volume du forfait',
          trailing: DwSegmented<VolumeUnit>(
            values: VolumeUnit.values,
            selected: _unit,
            expand: false,
            height: 32,
            trackColor: c.background,
            labelOf: (u) => u == VolumeUnit.go ? 'Go' : 'Mo',
            onChanged: _setUnit,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _volume,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                ],
                onChanged: (_) => setState(() => _volumeError = null),
                style: DwFonts.style(
                  DwFonts.display,
                  52,
                  700,
                  letterSpacing: -2,
                  tabular: true,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  errorText: _volumeError,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.only(bottom: 4),
                  suffixText: _unit == VolumeUnit.go ? 'Go' : 'Mo',
                  suffixStyle: DwFonts.style(
                    DwFonts.display,
                    24,
                    600,
                  ).copyWith(color: c.text),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.strong, width: 2),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.strong, width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.wifi, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bytes == null
                    ? '1${nbsp}Go = 1${nbsp}024${nbsp}Mo'
                    : _unit == VolumeUnit.go
                    ? '= ${formatThousands((bytes / DataUnits.bytesPerMo).round())}${nbsp}Mo · 1${nbsp}Go = 1${nbsp}024${nbsp}Mo'
                    : '= ${formatNumber(bytes / DataUnits.bytesPerGo)}${nbsp}Go · 1${nbsp}Go = 1${nbsp}024${nbsp}Mo',
                style: DwFonts.style(
                  DwFonts.mono,
                  12,
                  400,
                ).copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, preset) in _presets.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _PresetButton(
                        label: formatBytes(preset),
                        selected: bytes == preset,
                        onTap: () => _setPreset(preset),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _Section(
          title: 'Période',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldButton(
                icon: Icons.calendar_today_outlined,
                label: 'Début',
                value: '${formatDate(_start)} · ${formatTime(_start)}',
                onTap: _pickStart,
              ),
              const SizedBox(height: 12),
              Text(
                'Validité',
                style: t.bodySmall!.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 8),
              DwSegmented<Validity>(
                values: Validity.values,
                selected: _validity,
                trackColor: c.background,
                fontSize: 13.5,
                labelOf: (v) => v.label,
                onChanged: (v) => v == Validity.custom
                    ? _pickCustomEnd()
                    : setState(() => _validity = v),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? const Color(0xFFF0FBCB)
                      : c.positiveSoft,
                  borderRadius: BorderRadius.circular(DwRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Fin du suivi', style: t.bodyMedium)),
                    Text(
                      end == null
                          ? 'Choisir une date'
                          : '${formatDate(end)} à ${formatTime(end)}',
                      style: t.titleSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _Section(
          title: 'Seuils d’alerte',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final pct in ({
                ...DataPlan.defaultThresholds,
                ..._thresholds,
              }.toList()..sort()))
                _ThresholdRow(
                  percent: pct,
                  amount: bytes == null
                      ? null
                      : formatBytes(bytes * pct ~/ 100),
                  enabled: _thresholds.contains(pct),
                  onChanged: (on) => setState(() {
                    _thresholds = on
                        ? ({..._thresholds, pct})
                        : (_thresholds.where((t) => t != pct).toSet());
                  }),
                  // Les seuils ajoutés se retirent ; ceux par défaut se désactivent.
                  onRemove: DataPlan.defaultThresholds.contains(pct)
                      ? null
                      : () => setState(
                          () => _thresholds = _thresholds
                              .where((t) => t != pct)
                              .toSet(),
                        ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addThreshold,
                  style: TextButton.styleFrom(
                    foregroundColor: c.wifi,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Ajouter un seuil'),
                ),
              ),
              const SizedBox(height: 4),
              _AlertsStatus(controller: controller),
            ],
          ),
        ),
        const SizedBox(height: 12),

        DwCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Forfait récurrent', style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'À l’expiration, DataWatch vous propose de relancer le suivi avec les mêmes réglages.',
                          style: t.bodyMedium!.copyWith(color: c.textSecondary),
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(DwRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'DataWatch ne voit pas vos achats de forfait. Après une recharge, démarrez un nouveau suivi.',
                        style: t.bodySmall!.copyWith(color: c.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        FilledButton(
          onPressed: _save,
          child: const Text('Enregistrer le forfait'),
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
                  style: TextButton.styleFrom(foregroundColor: c.critical),
                  child: const Text('Réinitialiser'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: t.bodyMedium!
                      .weight(600)
                      .copyWith(color: context.dw.textSecondary),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.positiveSoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DwRadius.md),
          side: BorderSide(color: selected ? c.strong : c.divider),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DwRadius.md),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall!.copyWith(fontSize: 13.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: c.text),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: t.bodySmall!.copyWith(color: c.textSecondary),
                      ),
                      Text(value, style: t.titleMedium),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({
    required this.percent,
    required this.amount,
    required this.enabled,
    required this.onChanged,
    this.onRemove,
  });

  final int percent;
  final String? amount;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final color = switch (percent) {
      >= 100 => c.critical,
      >= 80 => c.warningText,
      _ => c.text,
    };
    return MergeSemantics(
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                '$percent$nbsp%',
                style: DwFonts.style(
                  DwFonts.display,
                  22,
                  700,
                  letterSpacing: -0.6,
                ).copyWith(color: color),
              ),
            ),
            Expanded(
              child: amount == null
                  ? Text(
                      'du volume déclaré',
                      style: t.bodyMedium!.copyWith(color: c.textSecondary),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'à '),
                          TextSpan(
                            text: amount,
                            style: TextStyle(color: c.text).weight(600),
                          ),
                          const TextSpan(text: ' consommés'),
                        ],
                      ),
                      style: t.bodyMedium!.copyWith(color: c.textSecondary),
                    ),
            ),
            if (onRemove == null)
              Switch(value: enabled, onChanged: onChanged)
            else
              IconButton(
                onPressed: onRemove,
                tooltip: 'Retirer le seuil de $percent %',
                icon: Icon(Icons.close_rounded, color: c.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ce qui empêcherait les alertes de s'afficher, avec le moyen d'y remédier.
class _AlertsStatus extends StatelessWidget {
  const _AlertsStatus({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final settings = controller.settings;

    if (controller.alertsActive) {
      return Text(
        'Une seule notification par seuil et par forfait, vérifiée environ toutes les 15 minutes.',
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
        borderRadius: BorderRadius.circular(DwRadius.md),
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
