import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../services/notification_service.dart';
import 'profile_screen.dart';
import 'vehicle_form_screen.dart';
import 'maintenance_screens.dart';
import 'odometer_screen.dart';

const _ink = Color(0xFFF4F7FA);
const _green = Color(0xFFA5D84D);
const _muted = Color(0xFFAAB9C5);
const _line = Color(0xFF304351);
const _canvas = Color(0xFF07121D);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  List<Vehicle> _vehicles = [];
  int _pendingReminders = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final profile = await AppDatabase.instance.getProfile();
    final vehicles = await AppDatabase.instance.getVehicles();
    final reminders = await AppDatabase.instance.getUnnotifiedReminders();
    for (final reminder in reminders) {
      final vehicle = _vehicleById(vehicles, reminder.vehicleId);
      if (vehicle != null && reminder.dueMileage != null && vehicle.mileage >= reminder.dueMileage! && reminder.id != null) {
        await NotificationService.instance.showDueReminder(
          id: reminder.id!, title: reminder.title,
          vehicleName: _vehicleName(vehicle),
        );
        await AppDatabase.instance.markReminderNotified(reminder.id!);
      }
    }
    final allReminders = await AppDatabase.instance.getReminders();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _vehicles = vehicles;
      _pendingReminders = allReminders.where((r) => !r.completed).length;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(profile: _profile)));
    await _load();
  }

  Future<void> _editVehicle([Vehicle? vehicle]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleFormScreen(vehicle: vehicle)));
    await _load();
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Supprimer ce véhicule ?'),
      content: Text('La fiche ${vehicle.make} ${vehicle.model} et son historique seront supprimés.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
      ],
    ));
    if (ok == true && vehicle.id != null) {
      final reminders = await AppDatabase.instance.getReminders(vehicleId: vehicle.id);
      for (final reminder in reminders) { if (reminder.id != null) await NotificationService.instance.cancelReminder(reminder.id!); }
      await AppDatabase.instance.deleteVehicle(vehicle.id!);
      await _load();
    }
  }

  Future<void> _testNotifications() async {
    final messenger = ScaffoldMessenger.of(context);
    final granted = await NotificationService.instance.requestPermission();
    if (!mounted) return;
    if (granted) await NotificationService.instance.showTestNotification();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(granted ? 'Notification de test envoyée.' : 'Autorisation de notification non accordée.')));
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?.firstName.trim().isNotEmpty == true ? _profile!.firstName.trim() : 'Bienvenue';
    return Scaffold(
      backgroundColor: _canvas,
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        color: _green,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 23)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MON GARAGE', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: _ink)),
                SizedBox(height: 2), Text('Votre carnet automobile', style: TextStyle(fontSize: 11, color: _muted)),
              ])),
              IconButton(onPressed: _testNotifications, tooltip: 'Tester les notifications', icon: const Icon(Icons.notifications_none_rounded, color: _ink)),
              IconButton.filledTonal(onPressed: _editProfile, tooltip: 'Mon profil', style: IconButton.styleFrom(backgroundColor: const Color(0xFF1A2D3A), foregroundColor: const Color(0xFFF4F7FA)), icon: const Icon(Icons.person_outline_rounded)),
            ]),
          ))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(18, 20, 18, 30), sliver: SliverList(delegate: SliverChildListDelegate([
            _HeaderPanel(name: name, vehicleCount: _vehicles.length, pending: _pendingReminders),
            const SizedBox(height: 27),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Expanded(child: Text('Mes véhicules', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5))),
              Text('${_vehicles.length} ${_vehicles.length > 1 ? 'véhicules' : 'véhicule'}', style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            if (_vehicles.isEmpty)
              _EmptyVehicles(onAdd: () => _editVehicle())
            else ...[
              ..._vehicles.map((v) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _VehicleCard(
                vehicle: v,
                onEdit: () => _editVehicle(v),
                onDelete: () => _deleteVehicle(v),
                onOdometer: () => _open(OdometerScreen(vehicle: v)),
              ))),
              OutlinedButton.icon(onPressed: () => _editVehicle(), icon: const Icon(Icons.add_rounded), label: const Text('Ajouter un véhicule'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: Color(0xFF506575)), foregroundColor: _green)),
            ],
            const SizedBox(height: 28),
            const Text('Suivi et entretien', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5)),
            const SizedBox(height: 5),
            const Text('Toutes les opérations et échéances de vos véhicules.', style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 13),
            _ActionTile(icon: Icons.build_circle_outlined, title: 'Interventions et entretiens', subtitle: 'Enregistrer une vidange, réparation ou pièce', onTap: () => _open(const MaintenanceRecordsScreen())),
            const SizedBox(height: 9),
            _ActionTile(icon: Icons.history_rounded, title: 'Historique', subtitle: 'Consulter les opérations réalisées', onTap: () => _open(const MaintenanceRecordsScreen(historyOnly: true))),
            const SizedBox(height: 9),
            _ActionTile(icon: Icons.notifications_active_outlined, title: 'Rappels et alertes', subtitle: 'Échéances par date et kilométrage', trailing: _pendingReminders.toString(), onTap: () => _open(const RemindersScreen())),
            const SizedBox(height: 24),
            const Center(child: Text('Vos données restent enregistrées sur cet appareil', style: TextStyle(fontSize: 10, color: Color(0xFF8093A1)))),
          ]))),
        ]),
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  final String name; final int vehicleCount; final int pending;
  const _HeaderPanel({required this.name, required this.vehicleCount, required this.pending});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(21, 21, 21, 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(19),
      color: const Color(0xFF0D1B28),
      border: Border.all(color: const Color(0xFF304351)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Bonjour $name', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
        const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF83B9C4), size: 27),
      ]),
      const SizedBox(height: 5),
      const Text('Votre suivi automobile, clair et maîtrisé.', style: TextStyle(color: Color(0xFFAAB9C5), fontSize: 12)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _Metric(value: '$vehicleCount', label: vehicleCount > 1 ? 'VÉHICULES' : 'VÉHICULE')),
        Container(width: 1, height: 34, color: Colors.white24),
        Expanded(child: _Metric(value: '$pending', label: 'ÉCHÉANCES ACTIVES')),
      ]),
    ]),
  );
}

class _Metric extends StatelessWidget {
  final String value; final String label;
  const _Metric({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: const TextStyle(color: Color(0xFFA5D84D), fontSize: 23, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2), Text(label, style: const TextStyle(color: Color(0xFFAAB9C5), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
  ]);
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle; final VoidCallback onEdit; final VoidCallback onDelete; final VoidCallback onOdometer;
  const _VehicleCard({required this.vehicle, required this.onEdit, required this.onDelete, required this.onOdometer});
  @override
  Widget build(BuildContext context) {
    final title = vehicle.nickname.isNotEmpty ? vehicle.nickname : '${vehicle.make} ${vehicle.model}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF122331), borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 47, height: 47, decoration: BoxDecoration(color: const Color(0xFF1A2D3A), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.directions_car_filled_rounded, color: _green, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 3), Text('${vehicle.make} ${vehicle.model}${vehicle.year == null ? '' : ' · ${vehicle.year}'}', style: const TextStyle(fontSize: 11, color: _muted)),
          ])),
          PopupMenuButton<String>(onSelected: (v) => v == 'edit' ? onEdit() : onDelete(), itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Modifier le véhicule')),
            PopupMenuItem(value: 'delete', child: Text('Supprimer le véhicule')),
          ]),
        ]),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _VehicleInfo(label: 'MOTORISATION', value: vehicle.engine.isEmpty ? 'Non précisée' : vehicle.engine, icon: Icons.settings_outlined)),
          Expanded(child: _VehicleInfo(label: 'ÉNERGIE', value: vehicle.fuel, icon: Icons.local_gas_station_outlined)),
        ]),
        const SizedBox(height: 15),
        Container(padding: const EdgeInsets.fromLTRB(13, 12, 10, 12), decoration: BoxDecoration(color: const Color(0xFF1A2D3A), borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            const Icon(Icons.speed_rounded, color: _green, size: 20),
            const SizedBox(width: 9),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('KILOMÉTRAGE ACTUEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: _muted)),
              SizedBox(height: 2),
            ])),
            Text('${_formatMileage(vehicle.mileage)} km', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
          ])),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: onOdometer, icon: const Icon(Icons.update_rounded, size: 18), label: const Text('Actualiser le kilométrage'),
          style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: const Color(0xFF17220B), minimumSize: const Size.fromHeight(45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        )),
      ]),
    );
  }
}

class _VehicleInfo extends StatelessWidget {
  final String label; final String value; final IconData icon;
  const _VehicleInfo({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: const Color(0xFFAAB9C5)), const SizedBox(width: 6),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Color(0xFF8093A1))),
      const SizedBox(height: 2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE0E8EE))),
    ])),
  ]);
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap; final String? trailing;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) => Material(color: const Color(0xFF122331), borderRadius: BorderRadius.circular(17), child: InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(17),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
      child: Row(children: [
        Container(width: 43, height: 43, decoration: BoxDecoration(color: const Color(0xFF1A2D3A), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _green, size: 21)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 3), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _muted)),
        ])),
        if (trailing != null) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF1A2D3A), borderRadius: BorderRadius.circular(20)), child: Text(trailing!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _green))),
        const SizedBox(width: 5), const Icon(Icons.chevron_right_rounded, color: Color(0xFF8093A1)),
      ]),
    ),
  ));
}

class _EmptyVehicles extends StatelessWidget {
  final VoidCallback onAdd; const _EmptyVehicles({required this.onAdd});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFF122331), borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
    child: Column(children: [
      Container(width: 55, height: 55, decoration: BoxDecoration(color: const Color(0xFF1A2D3A), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.directions_car_outlined, size: 28, color: _green)),
      const SizedBox(height: 12), const Text('Aucun véhicule enregistré', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 5), const Text('Ajoutez une voiture pour commencer le suivi.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 14), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Ajouter un véhicule')),
    ]));
}

String _formatMileage(int value) => value.toString().replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => ' ');
Vehicle? _vehicleById(List<Vehicle> vehicles, int id) { for (final v in vehicles) { if (v.id == id) return v; } return null; }
String _vehicleName(Vehicle v) => v.nickname.isNotEmpty ? v.nickname : '${v.make} ${v.model}';
