import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile? profile;
  const ProfileScreen({super.key, this.profile});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _email;
  late final TextEditingController _country;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: widget.profile?.firstName ?? '');
    _last = TextEditingController(text: widget.profile?.lastName ?? '');
    _email = TextEditingController(text: widget.profile?.email ?? '');
    _country = TextEditingController(text: widget.profile?.country ?? 'Algérie');
  }

  @override
  void dispose() {
    _first.dispose(); _last.dispose(); _email.dispose(); _country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await AppDatabase.instance.saveProfile(UserProfile(
      firstName: _first.text.trim(), lastName: _last.text.trim(),
      email: _email.text.trim(), country: _country.text.trim(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mon profil')),
    body: SafeArea(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Informations personnelles', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Ces informations peuvent être modifiées à tout moment.', style: TextStyle(color: Color(0xFFAAB9C5))),
      const SizedBox(height: 22),
      _field('Prénom', _first, required: true),
      const SizedBox(height: 14),
      _field('Nom (facultatif)', _last),
      const SizedBox(height: 14),
      _field('Adresse e-mail (facultatif)', _email, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 14),
      _field('Pays', _country),
      const SizedBox(height: 26),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Enregistrement...' : 'Enregistrer')),
    ]))),
  );

  Widget _field(String label, TextEditingController controller, {bool required = false, TextInputType? keyboard}) => TextFormField(
    controller: controller, keyboardType: keyboard, decoration: InputDecoration(labelText: label),
    validator: (value) => required && (value == null || value.trim().isEmpty) ? 'Ce champ est obligatoire.' : null,
  );
}
