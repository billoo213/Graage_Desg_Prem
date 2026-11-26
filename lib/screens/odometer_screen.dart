import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../models/vehicle.dart';

const _ink = Color(0xFFF4F7FA);
const _green = Color(0xFFA5D84D);
const _muted = Color(0xFFAAB9C5);
const _line = Color(0xFF304351);
const _canvas = Color(0xFF07121D);

class OdometerScreen extends StatefulWidget {
  final Vehicle vehicle;
  const OdometerScreen({super.key, required this.vehicle});

  @override
  State<OdometerScreen> createState() => _OdometerScreenState();
}

class _OdometerScreenState extends State<OdometerScreen> {
  List<OdometerReading> _readings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await AppDatabase.instance.getOdometerReadings(widget.vehicle.id!);
    if (!mounted) return;
    setState(() {
      _readings = rows;
      _loading = false;
    });
  }

  Future<void> _addOrEdit([OdometerReading? reading]) async {
    final result = await showDialog<_ReadingInput>(
      context: context,
      builder: (_) => _ReadingDialog(initial: reading),
    );
    if (result == null) return;

    try {
      await AppDatabase.instance.saveOdometerReading(
        vehicleId: widget.vehicle.id!,
        mileage: result.mileage,
        date: result.date,
        id: reading?.id,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relevé kilométrique enregistré.')),
      );
    } on OdometerReadingException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 30),
          title: const Text('Kilométrage incohérent'),
          content: Text(error.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _delete(OdometerReading reading) async {
    if (_readings.length <= 1) {
      _message('Conservez au moins un relevé pour définir le kilométrage actuel.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce relevé ?'),
        content: const Text(
          'Le kilométrage actuel sera recalculé à partir du relevé le plus récent conservé.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true && reading.id != null) {
      await AppDatabase.instance.deleteOdometerReading(reading.id!, widget.vehicle.id!);
      await _load();
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final vehicleName = widget.vehicle.nickname.isNotEmpty
        ? widget.vehicle.nickname
        : '${widget.vehicle.make} ${widget.vehicle.model}';
    final currentMileage = _readings.isNotEmpty ? _readings.first.mileage : widget.vehicle.mileage;
    final latestDate = _readings.isNotEmpty ? _dateLabel(_readings.first.date) : 'Aucun relevé';

    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        title: const Text('Compteur kilométrique'),
        actions: [
          IconButton(onPressed: _load, tooltip: 'Actualiser', icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: _green,
        foregroundColor: const Color(0xFF17220B),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau relevé'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: _green,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                    children: [
                      _VehicleMileagePanel(
                        vehicleName: vehicleName,
                        vehicleDetails: '${widget.vehicle.make} ${widget.vehicle.model}',
                        mileage: currentMileage,
                        lastUpdate: latestDate,
                        onUpdate: () => _addOrEdit(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: Text(
                              'Historique du compteur',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.4),
                            ),
                          ),
                          Text(
                            '${_readings.length} relevé${_readings.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Les relevés sont classés par date. Le kilométrage ne peut jamais diminuer avec le temps.',
                        style: TextStyle(fontSize: 12, height: 1.45, color: _muted),
                      ),
                      const SizedBox(height: 14),
                      if (_readings.isEmpty)
                        const _EmptyReadings()
                      else
                        ..._readings.asMap().entries.map((entry) {
                          final index = entry.key;
                          final reading = entry.value;
                          return _ReadingTile(
                            reading: reading,
                            isLatest: index == 0,
                            onEdit: () => _addOrEdit(reading),
                            onDelete: () => _delete(reading),
                          );
                        }),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2D3A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF304351)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined, color: _green, size: 19),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Contrôle automatique : un relevé récent doit avoir un kilométrage supérieur ou égal à celui de chaque relevé antérieur. Cette règle est vérifiée avant chaque enregistrement.',
                                style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xFFB9C7D1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _VehicleMileagePanel extends StatelessWidget {
  final String vehicleName;
  final String vehicleDetails;
  final int mileage;
  final String lastUpdate;
  final VoidCallback onUpdate;

  const _VehicleMileagePanel({
    required this.vehicleName,
    required this.vehicleDetails,
    required this.mileage,
    required this.lastUpdate,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B28),
          border: Border.all(color: const Color(0xFF304351)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withAlpha(18), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.directions_car_filled_rounded, color: Color(0xFFA5D84D), size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicleName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(vehicleDetails, style: const TextStyle(color: Color(0xFFAAB9C5), fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.speed_rounded, color: Color(0xFFA5D84D), size: 27),
              ],
            ),
            const SizedBox(height: 25),
            const Text('KILOMÉTRAGE ACTUEL', style: TextStyle(color: Color(0xFFAAB9C5), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${_formatMileage(mileage)} km',
                style: const TextStyle(color: Colors.white, fontSize: 37, fontWeight: FontWeight.w900, letterSpacing: -1.3),
              ),
            ),
            const SizedBox(height: 5),
            Text('Dernier relevé : $lastUpdate', style: const TextStyle(color: Color(0xFFAAB9C5), fontSize: 11)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.edit_road_rounded, size: 18),
                label: const Text('Actualiser le compteur'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA5D84D),
                  foregroundColor: const Color(0xFF0D1B28),
                  minimumSize: const Size.fromHeight(47),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ReadingTile extends StatelessWidget {
  final OdometerReading reading;
  final bool isLatest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReadingTile({
    required this.reading,
    required this.isLatest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF122331),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isLatest ? const Color(0xFF506575) : _line),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isLatest ? const Color(0xFF263C43) : const Color(0xFF1A2D3A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isLatest ? Icons.flag_rounded : Icons.speed_rounded,
                  color: isLatest ? _green : const Color(0xFFAAB9C5), size: 21),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text('${_formatMileage(reading.mileage)} km',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                ),
                if (isLatest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF263C43), borderRadius: BorderRadius.circular(20)),
                    child: const Text('ACTUEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _green, letterSpacing: 0.5)),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(_dateLabel(reading.date), style: const TextStyle(fontSize: 11, color: _muted)),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Actions sur le relevé',
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ),
        ),
      );
}

class _EmptyReadings extends StatelessWidget {
  const _EmptyReadings();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF122331), borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: const Column(
          children: [
            Icon(Icons.speed_rounded, color: _green, size: 34),
            SizedBox(height: 9),
            Text('Aucun relevé enregistré', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            SizedBox(height: 4),
            Text('Ajoutez le premier relevé pour suivre l’évolution du compteur.', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _muted, height: 1.4)),
          ],
        ),
      );
}

class _ReadingInput {
  final int mileage;
  final DateTime date;
  const _ReadingInput(this.mileage, this.date);
}

class _ReadingDialog extends StatefulWidget {
  final OdometerReading? initial;
  const _ReadingDialog({this.initial});

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mileage;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _mileage = TextEditingController(text: widget.initial?.mileage.toString() ?? '');
    _date = widget.initial == null ? DateTime.now() : DateTime.parse(widget.initial!.date);
  }

  @override
  void dispose() {
    _mileage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'Nouveau relevé' : 'Modifier le relevé'),
        content: SizedBox(
          width: 390,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _mileage,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kilométrage affiché',
                    suffixText: 'km',
                    prefixIcon: Icon(Icons.speed_rounded),
                  ),
                  validator: (value) {
                    final number = int.tryParse((value ?? '').replaceAll(' ', ''));
                    return number == null || number < 0 ? 'Saisissez un kilométrage valide.' : null;
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, color: _green),
                  title: const Text('Date du relevé'),
                  subtitle: Text(_dateLabel(_date.toIso8601String())),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Un relevé ancien peut être ajouté ou corrigé. Son kilométrage doit respecter les relevés qui l’entourent dans le temps.',
                    style: TextStyle(fontSize: 11, height: 1.45, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _ReadingInput(int.parse(_mileage.text.replaceAll(' ', '')), _date),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      );
}

String _formatMileage(int value) => value.toString().replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => ' ');

String _dateLabel(String value) {
  final date = DateTime.parse(value);
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
