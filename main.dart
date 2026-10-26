import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'rules.dart';
import 'family.dart';

const backendUrl = 'https://YOUR-WORKER.workers.dev/check'; // TODO: set yours

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Scam Checker',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const Shell(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ctrl = TextEditingController();
  bool loading = false;
  bool get es => isEs.value;
  Verdict? result;
  String? note;
  StreamSubscription? _sub;
  int freeLeft = 3; // TODO: persist per day + verify with Play Billing

  @override
  void initState() {
    super.initState();
    isEs.addListener(_rebuild);
    ReceiveSharingIntent.instance.getInitialMedia().then(_onShared);
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared);
  }

  void _rebuild() { if (mounted) setState(() {}); }

  void _onShared(List<SharedMediaFile> files) {
    final t = files.where((f) => f.type == SharedMediaType.text).map((f) => f.path).join('\n');
    if (t.isNotEmpty) {
      setState(() => ctrl.text = t);
      check();
    }
  }

  Future<void> check() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    final local = localCheck(text, es);
    setState(() { loading = true; result = local; note = null; });
    if (freeLeft <= 0) {
      setState(() { loading = false; note = es ? 'Límite diario alcanzado: mostrando solo el análisis básico.' : 'Daily limit reached: showing basic analysis only.'; });
      return;
    }
    try {
      final r = await http
          .post(Uri.parse(backendUrl), headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'text': text, 'lang': es ? 'es' : 'en'}))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        final flags = List<String>.from(j['flags'] ?? []);
        final level = j['level'] ?? local.level;
        freeLeft--;
        setState(() => result = Verdict(level, flags.isEmpty ? local.flags : flags, actionsFor(level, es)));
      } else {
        note = es ? 'Análisis con IA no disponible; mostrando análisis básico.' : 'AI analysis unavailable; showing basic analysis.';
      }
    } catch (_) {
      note = es ? 'Sin conexión; mostrando análisis básico.' : 'Offline; showing basic analysis.';
    }
    setState(() => loading = false);
  }

  Color _color(String l) => l == 'scam' ? Colors.red : l == 'suspicious' ? Colors.orange : Colors.green;
  String _label(String l) => es
      ? {'scam': 'Probable estafa', 'suspicious': 'Sospechoso', 'safe': 'Sin señales claras'}[l]!
      : {'scam': 'Likely scam', 'suspicious': 'Suspicious', 'safe': 'No clear warning signs'}[l]!;

  @override
  void dispose() { isEs.removeListener(_rebuild); _sub?.cancel(); ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final v = result;
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Detector de estafas' : 'Scam Checker'), actions: [
        TextButton(onPressed: () { isEs.value = !isEs.value; setState(() {}); }, child: Text(es ? 'EN' : 'ES')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: ctrl, minLines: 4, maxLines: 8,
          decoration: InputDecoration(border: const OutlineInputBorder(),
              hintText: es ? 'Pegá un mensaje, enlace o número…' : 'Paste a message, link or number…'),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: loading ? null : check,
            child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(es ? 'Analizar' : 'Check')),
        Text(es ? 'Análisis gratis hoy: $freeLeft' : 'Free checks left today: $freeLeft', textAlign: TextAlign.center),
        if (v != null) ...[
          const SizedBox(height: 16),
          Card(color: _color(v.level).withOpacity(0.12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_label(v.level), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _color(v.level))),
            if (v.flags.isNotEmpty) ...[const SizedBox(height: 8), ...v.flags.map((f) => Text('• $f'))],
            const SizedBox(height: 12),
            Text(es ? 'Qué hacer' : 'What to do', style: const TextStyle(fontWeight: FontWeight.bold)),
            ...v.actions.map((a) => Text('• $a')),
            if (note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(note!, style: const TextStyle(fontStyle: FontStyle.italic))),
          ]))),
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(
            es ? 'Es una evaluación de riesgo, no una garantía.' : 'This is a risk assessment, not a guarantee.',
            style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
        ],
      ]),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<bool>(
        valueListenable: isEs,
        builder: (_, es, __) => Scaffold(
          body: IndexedStack(index: i, children: const [Home(), FamilyPage()]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (v) => setState(() => i = v),
            destinations: [
              NavigationDestination(icon: const Icon(Icons.search), label: es ? 'Analizar' : 'Check'),
              NavigationDestination(icon: const Icon(Icons.family_restroom), label: es ? 'Familia' : 'Family'),
            ],
          ),
        ),
      );
}
