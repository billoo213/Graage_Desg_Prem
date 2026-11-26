import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/vehicle.dart';

class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;
  const VehicleFormScreen({super.key, this.vehicle});
  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname, _make, _model, _year, _engine, _engineCode, _vin, _mileage;
  String _fuel = 'Essence';
  bool _saving = false;
  final _fuels = const ['Essence', 'Diesel', 'GPL', 'Hybride', 'Électrique', 'Autre'];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _nickname = TextEditingController(text: v?.nickname ?? '');
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = TextEditingController(text: v?.year?.toString() ?? '');
    _engine = TextEditingController(text: v?.engine ?? '');
    _engineCode = TextEditingController(text: v?.engineCode ?? '');
    _vin = TextEditingController(text: v?.vin ?? '');
    _mileage = TextEditingController(text: v?.mileage.toString() ?? '');
    _fuel = v?.fuel ?? 'Essence';
  }

  @override
  void dispose() {
    _nickname.dispose(); _make.dispose(); _model.dispose(); _year.dispose();
    _engine.dispose(); _engineCode.dispose(); _vin.dispose(); _mileage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vin = _vin.text.trim().toUpperCase();
    if (vin.isNotEmpty && vin.length != 17) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le VIN doit comporter 17 caractères.')));
      return;
    }
    setState(() => _saving = true);
    final vehicle = Vehicle(
      id: widget.vehicle?.id,
      nickname: _nickname.text.trim(), make: _make.text.trim(), model: _model.text.trim(),
      year: int.tryParse(_year.text.trim()), fuel: _fuel,
      engine: _engine.text.trim(), engineCode: _engineCode.text.trim(),
      vin: vin, mileage: int.parse(_mileage.text.trim()),
    );
    try {
      await AppDatabase.instance.saveVehicle(vehicle);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.vehicle == null ? 'Véhicule ajouté.' : 'Véhicule modifié.')),
      );
      Navigator.pop(context);
    } on OdometerReadingException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’enregistrer le véhicule. Réessayez.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.vehicle == null ? 'Ajouter un véhicule' : 'Modifier le véhicule')),
    body: SafeArea(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Identification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Les champs marqués d’un astérisque sont obligatoires.', style: TextStyle(color: Color(0xFFAAB9C5))),
      const SizedBox(height: 20),
      _textField('Nom personnalisé (facultatif)', _nickname),
      const SizedBox(height: 13),
      _textField('Marque *', _make, required: true),
      const SizedBox(height: 13),
      _textField('Modèle *', _model, required: true),
      const SizedBox(height: 13),
      Row(children: [
        Expanded(child: _textField('Année', _year, keyboard: TextInputType.number, numeric: true)),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonFormField<String>(initialValue: _fuel, decoration: const InputDecoration(labelText: 'Carburant *'), items: _fuels.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) => setState(() => _fuel = v ?? 'Essence'))),
      ]),
      const SizedBox(height: 13),
      _textField('Motorisation (ex. 1.2 VTi)', _engine),
      const SizedBox(height: 13),
      _textField('Code moteur (facultatif)', _engineCode),
      const SizedBox(height: 13),
      _textField('Numéro VIN (17 caractères, facultatif)', _vin, maxLength: 17),
      const SizedBox(height: 13),
      _textField('Kilométrage actuel *', _mileage, required: true, keyboard: TextInputType.number, numeric: true),
      const SizedBox(height: 26),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Enregistrement...' : 'Enregistrer le véhicule')),
    ]))),
  );

  Widget _textField(String label, TextEditingController controller, {bool required = false, TextInputType? keyboard, bool numeric = false, int? maxLength}) => TextFormField(
    controller: controller, keyboardType: keyboard, maxLength: maxLength,
    decoration: InputDecoration(labelText: label, counterText: maxLength == null ? null : ''),
    validator: (value) {
      if (required && (value == null || value.trim().isEmpty)) return 'Ce champ est obligatoire.';
      if (numeric && value != null && value.trim().isNotEmpty && int.tryParse(value.trim()) == null) return 'Saisissez un nombre entier.';
      if (label == 'Année' && value != null && value.trim().isNotEmpty) {
        final y = int.tryParse(value.trim());
        if (y == null || y < 1950 || y > DateTime.now().year + 1) return 'Année invalide.';
      }
      return null;
    },
  );
}
