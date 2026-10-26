class Verdict {
  final String level; // safe | suspicious | scam
  final List<String> flags;
  final List<String> actions;
  Verdict(this.level, this.flags, this.actions);
}

class Rule {
  final RegExp pattern;
  final int weight;
  final String es, en;
  Rule(String p, this.weight, this.en, this.es)
      : pattern = RegExp(p, caseSensitive: false);
}

final _rules = <Rule>[
  Rule(r'(urgente|urgent|inmediat|immediately|last chance|últim[oa] aviso|within 24)', 2,
      'Creates urgency or pressure', 'Genera urgencia o presión'),
  Rule(r'(código|codigo|verification code|otp|token|pin\b|clave)', 3,
      'Asks for a code, PIN or password', 'Pide un código, PIN o clave'),
  Rule(r'(transfer|transferi|depósit|deposit|western union|giftcard|gift card|bitcoin|usdt|cripto)', 3,
      'Asks for a transfer or unusual payment', 'Pide una transferencia o pago inusual'),
  Rule(r'(cuenta (bloqueada|suspendida)|account (locked|suspended|blocked)|verify your account|verific[aá] tu cuenta)', 3,
      'Claims your account has a problem', 'Dice que tu cuenta tiene un problema'),
  Rule(r'(ganaste|you won|premio|prize|sorteo|lottery|herencia|inheritance)', 3,
      'Promises a prize or windfall', 'Promete un premio o dinero fácil'),
  Rule(r'(hola (mamá|mama|papá|papa)|mom,? i lost my phone|nuevo número|new number)', 2,
      'Family-emergency / new-number pattern', 'Patrón de "familiar con número nuevo"'),
  Rule(r'(bit\.ly|tinyurl|t\.co/|cutt\.ly|rb\.gy|goo\.gl)', 2,
      'Uses a shortened link that hides the destination', 'Usa un enlace acortado que oculta el destino'),
  Rule(r'https?://\d{1,3}(\.\d{1,3}){3}', 3,
      'Link points to a raw IP address', 'El enlace apunta a una dirección IP'),
  Rule(r'https?://[^\s/]*(\.xyz|\.top|\.click|\.live|\.icu|\.vip)\b', 2,
      'Link uses a domain often abused by scammers', 'Dominio frecuentemente usado en estafas'),
  Rule(r'(paypa[l1]|mercadopago|mercad0|banco\s?naci[oó]n|santander|galicia|bbva|afip|anses|correo argentino)[^\s]*\.(?!com\.ar\b|gob\.ar\b|com\b)', 3,
      'Brand name on a suspicious domain', 'Nombre de marca en un dominio sospechoso'),
];

Verdict localCheck(String text, bool es) {
  var score = 0;
  final flags = <String>[];
  for (final r in _rules) {
    if (r.pattern.hasMatch(text)) {
      score += r.weight;
      flags.add(es ? r.es : r.en);
    }
  }
  final level = score >= 6 ? 'scam' : (score >= 3 ? 'suspicious' : 'safe');
  return Verdict(level, flags, actionsFor(level, es));
}

List<String> actionsFor(String level, bool es) {
  if (level == 'safe') {
    return [es ? 'No vimos señales claras, pero seguí con cuidado.' : 'No clear warning signs, but stay careful.'];
  }
  return es
      ? ['No hagas clic en enlaces.', 'No compartas códigos ni claves.', 'Contactá a la entidad por su canal oficial.', 'Bloqueá y denunciá el número.']
      : ["Don't click any links.", "Never share codes or passwords.", 'Contact the company through its official channel.', 'Block and report the sender.'];
}
