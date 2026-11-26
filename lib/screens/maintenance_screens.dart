import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/maintenance.dart';
import '../models/vehicle.dart';
import '../services/notification_service.dart';

Vehicle? _findVehicle(List<Vehicle> vehicles, int id) { for (final v in vehicles) { if (v.id == id) return v; } return null; }

String vehicleLabel(Vehicle v) => v.nickname.isNotEmpty ? v.nickname : '${v.make} ${v.model}';
String dateLabel(String? value) {
  if (value == null || value.isEmpty) return 'Sans date';
  final d = DateTime.tryParse(value);
  if (d == null) return value;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class MaintenanceRecordsScreen extends StatefulWidget {
  final bool historyOnly;
  const MaintenanceRecordsScreen({super.key, this.historyOnly = false});
  @override
  State<MaintenanceRecordsScreen> createState() => _MaintenanceRecordsScreenState();
}

class _MaintenanceRecordsScreenState extends State<MaintenanceRecordsScreen> {
  List<Vehicle> _vehicles = [];
  List<MaintenanceRecord> _records = [];
  int? _filter;
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final v = await AppDatabase.instance.getVehicles();
    final r = await AppDatabase.instance.getRecords(vehicleId: _filter);
    if (!mounted) return;
    setState(() { _vehicles = v; _records = r; _loading = false; });
  }
  Future<void> _edit([MaintenanceRecord? record]) async {
    if (_vehicles.isEmpty) { _message('Ajoutez d’abord un véhicule.'); return; }
    final result = await showDialog<MaintenanceRecord>(context: context,
      builder: (_) => _RecordDialog(vehicles: _vehicles, initial: record));
    if (result != null) {
      try {
        await AppDatabase.instance.saveRecord(result);
        await _load();
      } on OdometerReadingException catch (error) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
            title: const Text('Kilométrage incohérent'),
            content: Text(error.message),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Compris')),
            ],
          ),
        );
      }
    }
  }
  Future<void> _delete(MaintenanceRecord r) async {
    final ok = await _confirm(context, 'Supprimer cette intervention ?');
    if (ok && r.id != null) { await AppDatabase.instance.deleteRecord(r.id!); await _load(); }
  }
  void _message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.historyOnly ? 'Historique' : 'Interventions et entretiens'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: widget.historyOnly ? null : FloatingActionButton.extended(
      onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Nouvelle intervention')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
      if (_vehicles.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: DropdownButtonFormField<int?>(initialValue: _filter, decoration: const InputDecoration(labelText: 'Filtrer par véhicule'),
          items: [const DropdownMenuItem<int?>(value: null, child: Text('Tous les véhicules')),
            ..._vehicles.map((v) => DropdownMenuItem<int?>(value: v.id, child: Text(vehicleLabel(v))))],
          onChanged: (v) { setState(() { _filter = v; _loading = true; }); _load(); })),
      Expanded(child: _records.isEmpty ? const _EmptyState(text: 'Aucune intervention enregistrée.') : ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: _records.length,
        itemBuilder: (_, i) {
          final r = _records[i];
          final v = _findVehicle(_vehicles, r.vehicleId);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF122331),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF304351)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: const Color(0xFF1A2D3A), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.build_circle_outlined, color: Color(0xFFA5D84D), size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFF4F7FA))),
                      const SizedBox(height: 3),
                      Text(v == null ? 'Véhicule supprimé' : vehicleLabel(v), style: const TextStyle(fontSize: 11, color: Color(0xFFAAB9C5))),
                      const SizedBox(height: 7),
                      Wrap(spacing: 7, runSpacing: 5, children: [
                        _InfoTag(icon: Icons.category_outlined, text: r.category),
                        _InfoTag(icon: Icons.calendar_today_outlined, text: dateLabel(r.date)),
                        _InfoTag(icon: Icons.speed_rounded, text: '${r.mileage} km'),
                      ]),
                      const SizedBox(height: 7),
                      Text('${r.cost.toStringAsFixed(2)} DA', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFA5D84D))),
                    ],
                  ),
                ),
                if (!widget.historyOnly)
                  PopupMenuButton<String>(
                    onSelected: (x) => x == 'edit' ? _edit(r) : _delete(r),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
              ],
            ),
          );
        })),
    ]),
  );
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}
class _RemindersScreenState extends State<RemindersScreen> {
  List<Vehicle> _vehicles = [];
  List<MaintenanceReminder> _reminders = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final v = await AppDatabase.instance.getVehicles();
    final r = await AppDatabase.instance.getReminders();
    if (!mounted) return;
    setState(() { _vehicles = v; _reminders = r; _loading = false; });
  }
  Future<void> _edit([MaintenanceReminder? reminder]) async {
    if (_vehicles.isEmpty) { _message('Ajoutez d’abord un véhicule.'); return; }
    final result = await showDialog<MaintenanceReminder>(context: context,
      builder: (_) => _ReminderDialog(vehicles: _vehicles, initial: reminder));
    if (result == null) return;
    final id = await AppDatabase.instance.saveReminder(result);
    final savedId = result.id ?? id;
    await NotificationService.instance.cancelReminder(savedId);
    await NotificationService.instance.requestPermission();
    if (result.completed) {
      await NotificationService.instance.cancelReminder(savedId);
    } else if (result.dueDate != null) {
      final vehicle = _vehicles.firstWhere((v) => v.id == result.vehicleId);
      await NotificationService.instance.scheduleReminder(id: savedId,
        title: result.title, vehicleName: vehicleLabel(vehicle), date: DateTime.parse(result.dueDate!));
    }
    await _load();
  }
  Future<void> _complete(MaintenanceReminder r, bool value) async {
    if (r.id == null) return;
    await AppDatabase.instance.setReminderCompleted(r.id!, value);
    if (value) { await NotificationService.instance.cancelReminder(r.id!); }
    else if (r.dueDate != null) {
      final v = _vehicles.firstWhere((x) => x.id == r.vehicleId);
      await NotificationService.instance.scheduleReminder(id: r.id!, title: r.title,
        vehicleName: vehicleLabel(v), date: DateTime.parse(r.dueDate!));
    }
    await _load();
  }
  Future<void> _delete(MaintenanceReminder r) async {
    if (!await _confirm(context, 'Supprimer ce rappel ?') || r.id == null) return;
    await NotificationService.instance.cancelReminder(r.id!);
    await AppDatabase.instance.deleteReminder(r.id!);
    await _load();
  }
  void _message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  bool _isOverdue(MaintenanceReminder r, Vehicle? v) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = r.dueDate == null ? false : DateTime.parse(r.dueDate!).isBefore(today);
    final km = r.dueMileage != null && v != null && v.mileage >= r.dueMileage!;
    return !r.completed && (date || km);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rappels')),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add_alarm), label: const Text('Nouveau rappel')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _reminders.isEmpty
      ? const _EmptyState(text: 'Aucun rappel programmé. Ajoutez une échéance par date ou kilométrage.')
      : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _reminders.length, itemBuilder: (_, i) {
        final r = _reminders[i];
        final v = _findVehicle(_vehicles, r.vehicleId);
        final overdue = _isOverdue(r, v);
        final statusColor = r.completed ? const Color(0xFFA5D84D) : overdue ? const Color(0xFFFF6B64) : const Color(0xFFA5D84D);
        final statusText = r.completed ? 'TERMINÉ' : overdue ? 'EN RETARD' : 'À VENIR';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(13, 12, 7, 12),
          decoration: BoxDecoration(color: const Color(0xFF122331), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF304351))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: Icon(r.completed ? Icons.check_circle_outline : overdue ? Icons.warning_amber_rounded : Icons.notifications_active_outlined, color: statusColor, size: 21)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFF4F7FA))),
              const SizedBox(height: 3),
              Text(v == null ? 'Véhicule supprimé' : vehicleLabel(v), style: const TextStyle(fontSize: 11, color: Color(0xFFAAB9C5))),
              const SizedBox(height: 7),
              if (r.dueDate != null) _InfoTag(icon: Icons.calendar_today_outlined, text: dateLabel(r.dueDate)),
              if (r.dueMileage != null) Padding(padding: const EdgeInsets.only(top: 5), child: _InfoTag(icon: Icons.speed_rounded, text: '${r.dueMileage} km')),
              const SizedBox(height: 7),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withAlpha(18), borderRadius: BorderRadius.circular(6)),
                child: Text(statusText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5))),
            ])),
            PopupMenuButton<String>(onSelected: (x) { if (x == 'done') _complete(r, !r.completed); if (x == 'edit') _edit(r); if (x == 'delete') _delete(r); }, itemBuilder: (_) => [
              PopupMenuItem(value: 'done', child: Text(r.completed ? 'Réactiver' : 'Marquer terminé')),
              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer'))]),
          ]),
        );
      }),
  );
}

class _RecordDialog extends StatefulWidget {
  final List<Vehicle> vehicles; final MaintenanceRecord? initial;
  const _RecordDialog({required this.vehicles, this.initial});
  @override State<_RecordDialog> createState() => _RecordDialogState();
}
class _RecordDialogState extends State<_RecordDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title, _mileage, _cost, _notes;
  late int _vehicleId; late String _category; late DateTime _date;
  final _categories = const ['Entretien', 'Réparation', 'Remplacement', 'Contrôle', 'Diagnostic', 'Autre'];
  @override void initState() { super.initState(); final r = widget.initial; _vehicleId = r?.vehicleId ?? widget.vehicles.first.id!; _title = TextEditingController(text: r?.title ?? ''); _mileage = TextEditingController(text: r?.mileage.toString() ?? widget.vehicles.first.mileage.toString()); _cost = TextEditingController(text: r?.cost.toString() ?? '0'); _notes = TextEditingController(text: r?.notes ?? ''); _category = r?.category ?? _categories.first; _date = r == null ? DateTime.now() : DateTime.parse(r.date); }
  @override void dispose() { _title.dispose(); _mileage.dispose(); _cost.dispose(); _notes.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.initial == null ? 'Nouvelle intervention' : 'Modifier intervention'), content: SizedBox(width: 420, child: Form(key: _key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    DropdownButtonFormField<int>(initialValue: _vehicleId, decoration: const InputDecoration(labelText: 'Véhicule'), items: widget.vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(vehicleLabel(v)))).toList(), onChanged: (v) => setState(() => _vehicleId = v!)),
    const SizedBox(height: 10), TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Intervention *'), validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null),
    const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Type'), items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _category = v!)),
    const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, title: Text('Date : ${dateLabel(_date.toIso8601String())}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => _date = d); }),
    TextFormField(controller: _mileage, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilométrage *'), validator: (v) { final km = int.tryParse(v ?? ''); return km == null || km < 0 ? 'Kilométrage invalide' : null; }),
    const SizedBox(height: 10), TextFormField(controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Coût (DA)'), validator: (v) => double.tryParse((v ?? '').replaceAll(',', '.')) == null ? 'Montant invalide' : null),
    const SizedBox(height: 10), TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (facultatif)')),
  ])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: () { if (!_key.currentState!.validate()) return; Navigator.pop(context, MaintenanceRecord(id: widget.initial?.id, vehicleId: _vehicleId, title: _title.text.trim(), category: _category, date: _date.toIso8601String().substring(0, 10), mileage: int.parse(_mileage.text), cost: double.parse(_cost.text.replaceAll(',', '.')), notes: _notes.text.trim())); }, child: const Text('Enregistrer'))]);
}

class _ReminderDialog extends StatefulWidget {
  final List<Vehicle> vehicles; final MaintenanceReminder? initial;
  const _ReminderDialog({required this.vehicles, this.initial});
  @override State<_ReminderDialog> createState() => _ReminderDialogState();
}
class _ReminderDialogState extends State<_ReminderDialog> {
  final _key = GlobalKey<FormState>(); late final TextEditingController _title, _km, _notes;
  late int _vehicleId; DateTime? _date; bool _useDate = true; bool _useKm = false;
  @override void initState() { super.initState(); final r = widget.initial; _vehicleId = r?.vehicleId ?? widget.vehicles.first.id!; _title = TextEditingController(text: r?.title ?? ''); _km = TextEditingController(text: r?.dueMileage?.toString() ?? ''); _notes = TextEditingController(text: r?.notes ?? ''); _date = r?.dueDate == null ? DateTime.now().add(const Duration(days: 30)) : DateTime.parse(r!.dueDate!); _useDate = r?.dueDate != null || r == null; _useKm = r?.dueMileage != null; }
  @override void dispose() { _title.dispose(); _km.dispose(); _notes.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.initial == null ? 'Nouveau rappel' : 'Modifier rappel'), content: SizedBox(width: 420, child: Form(key: _key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    DropdownButtonFormField<int>(initialValue: _vehicleId, decoration: const InputDecoration(labelText: 'Véhicule'), items: widget.vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(vehicleLabel(v)))).toList(), onChanged: (v) => setState(() => _vehicleId = v!)),
    const SizedBox(height: 10), TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Objet du rappel *'), validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null),
    CheckboxListTile(contentPadding: EdgeInsets.zero, value: _useDate, title: const Text('Rappel par date'), onChanged: (v) => setState(() => _useDate = v ?? false)),
    if (_useDate) ListTile(contentPadding: EdgeInsets.zero, title: Text('Échéance : ${dateLabel(_date?.toIso8601String())}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final d = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime(2100)); if (d != null) setState(() => _date = d); }),
    CheckboxListTile(contentPadding: EdgeInsets.zero, value: _useKm, title: const Text('Rappel par kilométrage'), onChanged: (v) => setState(() => _useKm = v ?? false)),
    if (_useKm) TextFormField(controller: _km, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kilométrage prévu'), validator: (v) => _useKm && int.tryParse(v ?? '') == null ? 'Kilométrage invalide' : null),
    TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (facultatif)')),
  ])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), FilledButton(onPressed: () { if (!_useDate && !_useKm) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez une date ou un kilométrage.'))); return; } if (!_key.currentState!.validate()) return; Navigator.pop(context, MaintenanceReminder(id: widget.initial?.id, vehicleId: _vehicleId, title: _title.text.trim(), dueDate: _useDate ? (_date ?? DateTime.now()).toIso8601String().substring(0, 10) : null, dueMileage: _useKm ? int.parse(_km.text) : null, notes: _notes.text.trim(), completed: widget.initial?.completed ?? false)); }, child: const Text('Enregistrer'))]);
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF1A2D3A), borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: const Color(0xFFAAB9C5)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFFAAB9C5))),
        ]),
      );
}

class _EmptyState extends StatelessWidget { final String text; const _EmptyState({required this.text}); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFAAB9C5)), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFAAB9C5)))]))); }
Future<bool> _confirm(BuildContext context, String message) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Confirmation'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer'))])) ?? false;
