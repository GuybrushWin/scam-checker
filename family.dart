import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

final isEs = ValueNotifier<bool>(true);

String newSecret() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// 6-digit code that changes every 30 seconds (standard TOTP, HMAC-SHA1).
/// Every phone holding the same secret shows the same code at the same time.
String codeFor(String secret, DateTime t) {
  final counter = t.toUtc().millisecondsSinceEpoch ~/ 30000;
  final msg = List<int>.generate(8, (i) => (counter >> (8 * (7 - i))) & 0xff);
  final h = Hmac(sha1, utf8.encode(secret)).convert(msg).bytes;
  final o = h[19] & 0x0f;
  final bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
  return (bin % 1000000).toString().padLeft(6, '0');
}

String groups(String s) => RegExp('.{1,4}').allMatches(s).map((m) => m[0]).join('-');

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});
  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  String? secret;
  final word = TextEditingController();
  final join = TextEditingController();
  String? err;
  Timer? _tick;
  SharedPreferences? _p;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      _p = p;
      setState(() { secret = p.getString('family_secret'); word.text = p.getString('family_word') ?? ''; });
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && secret != null) setState(() {}); });
  }

  @override
  void dispose() { _tick?.cancel(); word.dispose(); join.dispose(); super.dispose(); }

  Future<void> _save(String s) async {
    await _p?.setString('family_secret', s);
    setState(() { secret = s; err = null; });
  }

  Future<void> _leave() async {
    await _p?.remove('family_secret');
    await _p?.remove('family_word');
    setState(() { secret = null; word.clear(); });
  }

  void _join(bool es) {
    final s = join.text.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(s)) {
      setState(() => err = es ? 'Código inválido: son 32 letras/números.' : 'Invalid code: it should be 32 letters/numbers.');
      return;
    }
    _save(s);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isEs,
      builder: (_, es, __) {
        String t(String e, String n) => es ? e : n;
        return Scaffold(
          appBar: AppBar(title: Text(t('Escudo familiar', 'Family Shield')), actions: [
            TextButton(onPressed: () => isEs.value = !es, child: Text(es ? 'EN' : 'ES')),
          ]),
          body: ListView(padding: const EdgeInsets.all(16), children: secret == null ? _setup(es, t) : _active(es, t)),
        );
      },
    );
  }

  List<Widget> _setup(bool es, String Function(String, String) t) => [
        Text(t('Si alguien te llama o escribe diciendo ser de tu familia y pide dinero o códigos, pedile el código de este escudo. Una voz o un número conocido ya no prueba nada.',
            'If someone claims to be family and asks for money or codes, ask for the code from this shield. A familiar voice or number no longer proves anything.')),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => _save(newSecret()), child: Text(t('Crear grupo familiar', 'Create family group'))),
        const SizedBox(height: 8),
        Text(t('Después compartí el código con tu familia EN PERSONA, no por chat.', 'Then share the code with your family IN PERSON, not by chat.'), style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 32),
        TextField(controller: join, decoration: InputDecoration(border: const OutlineInputBorder(), labelText: t('Unirme con el código de mi familia', 'Join with my family’s code'))),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => _join(es), child: Text(t('Unirme', 'Join'))),
      ];

  List<Widget> _active(bool es, String Function(String, String) t) {
    final now = DateTime.now();
    final left = 30 - (now.toUtc().millisecondsSinceEpoch ~/ 1000) % 30;
    final code = codeFor(secret!, now);
    return [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6C7CFF), Color(0xFF22D3C5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(children: [
          Text(t('TU CÓDIGO AHORA', 'YOUR CODE NOW'), style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          Text('${code.substring(0, 3)}  ${code.substring(3)}', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: 4, color: Colors.white)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: left / 30, minHeight: 6, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
          ),
          const SizedBox(height: 8),
          Text(t('Cambia en $left s', 'Changes in $left s'), style: const TextStyle(color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: 16),
      Text(t('Cómo usarlo', 'How to use it'), style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(t('• Si alguien dice ser familiar y pide algo urgente, pedile que te lea SU código.\n• Tiene que coincidir con el tuyo (puede variar un instante al cambiar).\n• Si no coincide o no puede darlo: cortá y llamá vos al número que ya tenías.\n• Nunca compartas el código del grupo por chat.',
          '• If someone claims to be family and asks for something urgent, ask them to read THEIR code.\n• It must match yours (it may differ for a moment as it changes).\n• If it doesn’t match or they can’t give it: hang up and call the number you already had.\n• Never share the group code over chat.')),
      const SizedBox(height: 16),
      TextField(
        controller: word,
        onChanged: (v) => _p?.setString('family_word', v),
        decoration: InputDecoration(border: const OutlineInputBorder(), labelText: t('Palabra secreta familiar (opcional)', 'Family secret word (optional)')),
      ),
      const Divider(height: 32),
      Text(t('Código del grupo (para sumar familiares, en persona):', 'Group code (to add relatives, in person):')),
      SelectableText(groups(secret!), style: const TextStyle(fontFamily: 'monospace')),
      TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: secret!)), child: Text(t('Copiar', 'Copy'))),
      TextButton(onPressed: _leave, child: Text(t('Salir del grupo', 'Leave group'), style: const TextStyle(color: Colors.red))),
    ];
  }
}
