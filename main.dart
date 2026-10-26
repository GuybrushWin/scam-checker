import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'rules.dart';
import 'family.dart';

const backendUrl = 'https://YOUR-WORKER.workers.dev/check'; // TODO: set yours

const kBg = Color(0xFF0A0F1E), kCard = Color(0xFF131A2D), kLine = Color(0xFF232C45);
const kA = Color(0xFF6C7CFF), kB = Color(0xFF22D3C5);
const kOk = Color(0xFF34D399), kWarn = Color(0xFFFBBF24), kBad = Color(0xFFF87171);
const kGrad = LinearGradient(colors: [kA, kB], begin: Alignment.topLeft, end: Alignment.bottomRight);

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Scam Checker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(primary: kB, secondary: kA, surface: kCard),
          appBarTheme: const AppBarTheme(backgroundColor: kBg, elevation: 0, scrolledUnderElevation: 0),
          navigationBarTheme: NavigationBarThemeData(backgroundColor: kCard, indicatorColor: kA.withOpacity(0.28)),
        ),
        home: const Shell(),
      );
}

class ShieldLogo extends StatelessWidget {
  final double size;
  const ShieldLogo({super.key, this.size = 40});
  @override
  Widget build(BuildContext c) => CustomPaint(size: Size(size, size), painter: _ShieldPainter());
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(w * .5, h * .04)
      ..cubicTo(w * .66, h * .16, w * .82, h * .17, w * .92, h * .18)
      ..cubicTo(w * .92, h * .62, w * .76, h * .85, w * .5, h * .97)
      ..cubicTo(w * .24, h * .85, w * .08, h * .62, w * .08, h * .18)
      ..cubicTo(w * .18, h * .17, w * .34, h * .16, w * .5, h * .04)
      ..close();
    canvas.drawPath(path, Paint()..shader = kGrad.createShader(Offset.zero & s));
    final tick = Path()
      ..moveTo(w * .31, h * .5)
      ..lineTo(w * .45, h * .64)
      ..lineTo(w * .70, h * .36);
    canvas.drawPath(
        tick,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .09
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class GradBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const GradBtn({super.key, required this.label, this.onTap, this.busy = false});
  @override
  Widget build(BuildContext c) => Opacity(
        opacity: onTap == null && !busy ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(gradient: kGrad, borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: SizedBox(
                height: 56,
                child: Center(
                  child: busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      );
}

class LangPill extends StatelessWidget {
  const LangPill({super.key});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: () => isEs.value = !isEs.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(20)),
          child: Text(isEs.value ? 'EN' : 'ES', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
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
      setState(() { loading = false; note = es ? 'Límite diario alcanzado: solo análisis básico.' : 'Daily limit reached: basic analysis only.'; });
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
      note = es ? 'Sin conexión con la IA; mostrando análisis básico.' : 'Could not reach the AI; showing basic analysis.';
    }
    setState(() => loading = false);
  }

  Color _color(String l) => l == 'scam' ? kBad : l == 'suspicious' ? kWarn : kOk;
  IconData _icon(String l) => l == 'scam' ? Icons.gpp_bad_rounded : l == 'suspicious' ? Icons.warning_amber_rounded : Icons.verified_user_rounded;
  String _label(String l) => es
      ? {'scam': 'Probable estafa', 'suspicious': 'Sospechoso', 'safe': 'Sin señales claras'}[l]!
      : {'scam': 'Likely scam', 'suspicious': 'Suspicious', 'safe': 'No clear warning signs'}[l]!;

  Widget _row(IconData i, Color c, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(child: Text(s, style: const TextStyle(height: 1.3))),
        ]),
      );

  Widget _result(Verdict v, String Function(String, String) t) {
    final c = _color(v.level);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(24), border: Border.all(color: c.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: c.withOpacity(0.2), shape: BoxShape.circle), child: Icon(_icon(v.level), color: c, size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Text(_label(v.level), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c))),
        ]),
        if (v.flags.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...v.flags.map((f) => _row(Icons.flag_rounded, c, f)),
        ],
        const Divider(height: 28, color: kLine),
        Text(t('Qué hacer', 'What to do'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        ...v.actions.map((a) => _row(Icons.check_circle_rounded, kB, a)),
        if (note != null) Text(note!, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white54, fontSize: 13)),
      ]),
    );
  }

  @override
  void dispose() { isEs.removeListener(_rebuild); _sub?.cancel(); ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    String t(String e, String n) => es ? e : n;
    final v = result;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          Row(children: [
            const ShieldLogo(size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Scam Checker', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                Text(t('¿Es una estafa? Averigualo.', 'Is it a scam? Find out.'), style: const TextStyle(color: Colors.white60)),
              ]),
            ),
            const LangPill(),
          ]),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(22), border: Border.all(color: kLine)),
            child: Column(children: [
              TextField(
                controller: ctrl, minLines: 4, maxLines: 8, style: const TextStyle(fontSize: 16),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: InputBorder.none, contentPadding: const EdgeInsets.all(18),
                  hintText: t('Pegá un mensaje, enlace o número…', 'Paste a message, link or number…'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: () async {
                      final d = await Clipboard.getData('text/plain');
                      if (d?.text != null) setState(() => ctrl.text = d!.text!);
                    },
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: Text(t('Pegar', 'Paste')),
                  ),
                  const Spacer(),
                  if (ctrl.text.isNotEmpty)
                    IconButton(onPressed: () => setState(() { ctrl.clear(); result = null; }), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          GradBtn(label: t('Analizar', 'Check'), busy: loading, onTap: loading ? null : check),
          const SizedBox(height: 10),
          Center(child: Text(t('Análisis con IA gratis hoy: $freeLeft', 'Free AI checks left today: $freeLeft'), style: const TextStyle(color: Colors.white54, fontSize: 13))),
          if (v != null) ...[
            const SizedBox(height: 18),
            _result(v, t),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(t('Es una evaluación de riesgo, no una garantía.', 'This is a risk assessment, not a guarantee.'),
                  style: const TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
            ),
          ] else ...[
            const SizedBox(height: 28),
            Text(t('Tip: en WhatsApp o SMS, mantené presionado un mensaje → Compartir → Scam Checker.',
                'Tip: in WhatsApp or SMS, long-press a message → Share → Scam Checker.'),
                style: const TextStyle(color: Colors.white38), textAlign: TextAlign.center),
          ],
        ]),
      ),
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
              NavigationDestination(icon: const Icon(Icons.shield_outlined), selectedIcon: const Icon(Icons.shield_rounded), label: es ? 'Analizar' : 'Check'),
              NavigationDestination(icon: const Icon(Icons.family_restroom_outlined), selectedIcon: const Icon(Icons.family_restroom_rounded), label: es ? 'Familia' : 'Family'),
            ],
          ),
        ),
      );
}
