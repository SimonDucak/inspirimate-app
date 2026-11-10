import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Question {
  const _Question(
    this.id,
    this.label, {
    this.required = true,
    this.numeric = false,
    this.hint,
  });

  final String id;
  final String label;
  final bool required;
  final bool numeric;
  final String? hint;
}

const _questions = <_Question>[
  _Question('email', 'E-mail'),
  _Question('1790650575', 'Meno a priezvisko'),
  _Question('residence', 'Bydlisko'),
  _Question('151972161', 'Vek', numeric: true),
  _Question('2065577512', 'Výška (cm)', numeric: true),
  _Question('654556250', 'Váha (kg)', numeric: true),
  _Question('1705547760', 'Obvod pása (najužšia časť), cm', numeric: true),
  _Question('776737536', 'Obvod stehna (10 cm nad kolenom), cm', numeric: true),
  _Question('1099433820', 'Obvod bokov (najširšia časť), cm', numeric: true),
  _Question(
    '361024416',
    'Obvod hrudníka (cez najväčšiu časť), cm',
    numeric: true,
  ),
  _Question(
    '1066223291',
    'Obvod bicepsu (nadlaktie v strede), cm',
    numeric: true,
  ),
  _Question(
    '1996309377',
    'Aký je váš cieľ?',
    hint:
        'Príklad: zhodiť xy kg, obliecť si veľkosť oblečenia M, odbehnúť 20 km alebo mať tlak v norme.',
  ),
  _Question(
    '667428850',
    'Za ako dlho chcete dosiahnuť svoje ciele?',
    hint: 'Koľko dní, týždňov, mesiacov alebo rokov?',
  ),
  _Question(
    '478032874',
    'Ako veľmi ste odhodlaný/á pracovať na svojich cieľoch pravidelne?',
    numeric: true,
    hint: 'Škála 1–10, kde 10 = extrémne odhodlaný/á.',
  ),
  _Question('321239061', '12. Čo vám bráni v dosiahnutí týchto cieľov?'),
  _Question(
    '1897615530',
    '13. Čo si myslíte, že potrebujete pravidelne robiť preto, aby ste svoje ciele dosiahli?',
  ),
  _Question(
    '1539574703',
    'Aké sú vaše životné hodnoty?',
    hint: 'Zoraďte podľa dôležitosti (napr. 1. rodina, 2. zdravie a pod.).',
  ),
  _Question(
    '1561350105',
    'Akú úroveň prísnosti a kontroly potrebujete od trénera?',
    required: false,
    hint:
        'Škála 1–10: 1 = nechcem tlak, potrebujem slobodu; 10 = veľmi prísny prístup a kontrola.',
  ),
  _Question('2038982537', 'Aké pohybové aktivity máte rád/rada?'),
  _Question(
    '1264220689',
    'Koľkokrát v týždni ste ochotný/á venovať sa pohybu?',
  ),
  _Question(
    '2011498187',
    'Koľko času dokážete pohybovým aktivitám týždenne venovať?',
  ),
  _Question(
    '972152892',
    'Aké náradie alebo stroje na cvičenie máte k dispozícii?',
    required: false,
  ),
  _Question(
    '11866013',
    'Ako vyzeralo vaše stravovanie včera a dnes?',
    hint:
        'Konkrétne jedlá aj približné porcie (1 ks, 1 krajec chleba a pod.) alebo presné gramáže.',
  ),
  _Question(
    '832041141',
    'Napíšte aspoň 4 alternatívy každého jedla, ktoré máte počas dňa.',
    hint: 'Napr. raňajky: 1. chlieb s maslom, 2. ovsená kaša, 3. praženica...',
  ),
  _Question('121161229', '19. Kde vidíte problém vo vašom stravovaní?'),
  _Question(
    '881984416',
    '20. Máte nejaké alergie, intolerancie alebo citlivosť na konkrétne potraviny?',
  ),
  _Question('414573096', 'Aké potraviny vám chutia?', required: false),
  _Question('1746869559', 'Aké potraviny vám nechutia?', required: false),
  _Question(
    '738511309',
    'Koľko a akých tekutín počas dňa vypijete?',
    required: false,
  ),
  _Question(
    '1570088594',
    '21. Máte nejaké zdravotné problémy, komplikácie, zranenia alebo operácie, ktoré ste prekonali?',
  ),
  _Question('1076152202', '22. Beriete nejaké lieky alebo doplnky výživy?'),
  _Question(
    '2034844477',
    'Ako vyzerá priebeh vášho dňa alebo víkendu?',
    hint:
        'Kedy vstávate, kedy chodíte spať, aké aktivity a povinnosti máte medzi tým?',
  ),
  _Question(
    '680454320',
    'Najväčšie problémy v oblasti stravy, pohybu, myslenia-motivácie, bolesti a pohybového aparátu',
    required: false,
    hint:
        'Stručne v bodoch (napr. nedostatočný pitný režim, veľa sladkostí, nekvalitný spánok...).',
  ),
  _Question('1621509751', 'Čo očakávate od spolupráce so mnou?'),
  _Question(
    '298825788',
    'Máte nejaké doplňujúce informácie, ktoré by som mal vedieť?',
    hint:
        'Čokoľvek, čo by nám pomohlo dosiahnuť ciele kvalitnejšie, rýchlejšie a efektívnejšie.',
  ),
];

const _sections = <(int, String)>[
  (0, '1. Základné údaje'),
  (6, '2. Telesné miery'),
  (11, '3. Ciele a motivácia'),
  (18, '4. Pohyb a vybavenie'),
  (22, '5. Stravovanie'),
  (29, '6. Zdravotný stav'),
  (31, '7. Denný režim'),
  (32, '8. Zhrnutie a očakávania'),
];

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  String? _strictness;
  String? _submittedAt;
  bool _loading = true;
  bool _saving = false;

  SupabaseClient get _client => Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    for (final question in _questions) {
      _controllers[question.id] = TextEditingController();
    }
    _controllers['email']!.text = _client.auth.currentUser?.email ?? '';
    _loadAnswers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAnswers() async {
    try {
      final row = await _client
          .from('client_questionnaires')
          .select('responses, submitted_at')
          .eq('user_id', _userId)
          .maybeSingle();
      if (row != null) {
        final responses = Map<String, dynamic>.from(row['responses'] as Map);
        for (final question in _questions) {
          final answer = responses[question.id];
          if (answer is String && question.id != 'email') {
            _controllers[question.id]!.text = answer;
          }
        }
        final strictness = responses['1561350105'];
        if (strictness is String) _strictness = strictness;
        _submittedAt = row['submitted_at'] as String?;
      }
    } catch (_) {
      if (mounted) _message('Dotazník sa nepodarilo načítať.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({required bool submit}) async {
    if (_saving || _loading || (submit && !_formKey.currentState!.validate())) {
      return;
    }
    setState(() => _saving = true);
    final responses = <String, String>{
      for (final question in _questions)
        if (question.id != 'email' &&
            _controllers[question.id]!.text.trim().isNotEmpty)
          question.id: _controllers[question.id]!.text.trim(),
      if (_controllers['email']!.text.trim().isNotEmpty)
        'email': _controllers['email']!.text.trim(),
      if (_strictness != null) '1561350105': _strictness!,
    };
    final now = DateTime.now().toUtc().toIso8601String();
    final submittedAt = submit ? now : _submittedAt;
    var saved = false;
    try {
      await _client.from('client_questionnaires').upsert({
        'user_id': _userId,
        'responses': responses,
        'submitted_at': submittedAt,
        'updated_at': now,
      });
      saved = true;
      if (!mounted) return;
      setState(() => _submittedAt = submittedAt);
      if (submit) {
        final pdf = await _createPdf(responses);
        await Printing.sharePdf(
          bytes: pdf,
          filename: 'vstupny-dotaznik.pdf',
          subject: 'Vstupný dotazník',
          body:
              'Vstupný dotazník od ${responses['1790650575'] ?? ''} '
              '(${responses['email'] ?? ''}).',
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        _message('Rozpracovaný dotazník bol uložený.');
      }
    } catch (_) {
      if (mounted) {
        _message(
          saved
              ? 'Dotazník bol uložený, ale PDF sa nepodarilo zdieľať.'
              : 'Dotazník sa nepodarilo uložiť. Skúste to znova.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List> _createPdf(Map<String, String> responses) async {
    final document = pw.Document();
    final content = <pw.Widget>[
      pw.Text(
        _plainText('Vstupný dotazník'),
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Text(_plainText('E-mail: ${responses['email'] ?? ''}')),
      pw.SizedBox(height: 16),
    ];

    for (var index = 0; index < _questions.length; index++) {
      for (final section in _sections) {
        if (section.$1 == index) {
          content.addAll([
            pw.SizedBox(height: 12),
            pw.Text(
              _plainText(section.$2),
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
          ]);
        }
      }
      final question = _questions[index];
      final answer = responses[question.id]?.trim();
      content.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _plainText(question.label),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                _plainText(answer == null || answer.isEmpty ? '-' : answer),
              ),
            ],
          ),
        ),
      );
    }

    document.addPage(
      pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (_) => content),
    );
    return document.save();
  }

  String _plainText(String value) {
    const replacements = {
      'á': 'a',
      'ä': 'a',
      'č': 'c',
      'ď': 'd',
      'é': 'e',
      'í': 'i',
      'ĺ': 'l',
      'ľ': 'l',
      'ň': 'n',
      'ó': 'o',
      'ô': 'o',
      'ŕ': 'r',
      'š': 's',
      'ť': 't',
      'ú': 'u',
      'ý': 'y',
      'ž': 'z',
      'Á': 'A',
      'Ä': 'A',
      'Č': 'C',
      'Ď': 'D',
      'É': 'E',
      'Í': 'I',
      'Ĺ': 'L',
      'Ľ': 'L',
      'Ň': 'N',
      'Ó': 'O',
      'Ô': 'O',
      'Ŕ': 'R',
      'Š': 'S',
      'Ť': 'T',
      'Ú': 'U',
      'Ý': 'Y',
      'Ž': 'Z',
    };
    return value
        .split('')
        .map((character) => replacements[character] ?? character)
        .join();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String? _validate(_Question question, String? value) {
    final answer = value?.trim() ?? '';
    if (question.required && answer.isEmpty) return 'Toto pole je povinné.';
    if (question.id == 'email' &&
        answer.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(answer)) {
      return 'Zadajte platnú e-mailovú adresu.';
    }
    if (answer.isNotEmpty && question.numeric) {
      final number = double.tryParse(answer.replaceAll(',', '.'));
      if (number == null) return 'Zadajte platné číslo.';
      if (question.id == '478032874' && (number < 1 || number > 10)) {
        return 'Zadajte hodnotu od 1 do 10.';
      }
      if (question.id == '478032874' && number != number.roundToDouble()) {
        return 'Zadajte celé číslo od 1 do 10.';
      }
    }
    return null;
  }

  Widget _questionField(_Question question) {
    final isLongAnswer =
        !question.numeric &&
        question.id != '151972161' &&
        question.id != '2065577512' &&
        question.id != '654556250' &&
        question.id != '1705547760' &&
        question.id != '776737536' &&
        question.id != '1099433820' &&
        question.id != '361024416' &&
        question.id != '1066223291' &&
        question.id != '1264220689' &&
        question.id != '2011498187';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: _controllers[question.id],
        keyboardType: question.numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : question.id == 'email'
            ? TextInputType.emailAddress
            : isLongAnswer
            ? TextInputType.multiline
            : TextInputType.text,
        minLines: isLongAnswer ? 3 : 1,
        maxLines: isLongAnswer ? 5 : 1,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: question.numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))]
            : null,
        decoration: InputDecoration(
          label: Text(
            question.label,
            maxLines: 5,
            style: const TextStyle(height: 1.35),
          ),
          alignLabelWithHint: isLongAnswer,
          helperText: question.hint ?? (question.required ? null : 'Nepovinné'),
          helperMaxLines: 6,
          helperStyle: const TextStyle(height: 1.4),
          border: const OutlineInputBorder(),
        ),
        validator: (value) => _validate(question, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[];
    for (var index = 0; index < _questions.length; index++) {
      for (final section in _sections) {
        if (section.$1 == index) {
          fields.add(
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 18, bottom: 12),
              child: Text(
                section.$2,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }
      }
      final question = _questions[index];
      if (question.id == '1561350105') {
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: InputDecorator(
              decoration: const InputDecoration(
                label: Text(
                  'Akú úroveň prísnosti a kontroly potrebujete od trénera?',
                  maxLines: 5,
                  style: TextStyle(height: 1.35),
                ),
                helperText:
                    '1 – Nechcem tlak, potrebujem slobodu; 10 – Veľmi prísny prístup a kontrola (nepovinné)',
                helperMaxLines: 6,
                helperStyle: TextStyle(height: 1.4),
                border: OutlineInputBorder(),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(10, (i) {
                  final value = '${i + 1}';
                  return ChoiceChip(
                    label: Text(value),
                    selected: _strictness == value,
                    onSelected: (selected) =>
                        setState(() => _strictness = selected ? value : null),
                  );
                }),
              ),
            ),
          ),
        );
      } else {
        fields.add(_questionField(question));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vstupný dotazník')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('Poprosím vyplňte všetky otázky :)'),
                    if (_submittedAt != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Dotazník už bol odoslaný. Odpovede môžete upraviť a odoslať znova.',
                      ),
                    ],
                    const SizedBox(height: 22),
                    ...fields,
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _save(submit: false),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Uložiť koncept'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(submit: true),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_saving ? 'Ukladá sa…' : 'Odoslať dotazník'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
