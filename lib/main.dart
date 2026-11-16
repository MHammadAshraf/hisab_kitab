import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ───────────────────────── THEME ─────────────────────────
class C {
  static const bg = Color(0xFFF5F1E8);
  static const ink = Color(0xFF2B2A38);
  static const purple = Color(0xFF6C63FF);
  static const lilac = Color(0xFF9D97FF);
  static const pink = Color(0xFFFF6584);
  static const mint = Color(0xFF43D9AD);
  static const green = Color(0xFF1FAE85);
  static const orange = Color(0xFFD98E1B);
  static const amber = Color(0xFFFFB347);
  static const navy = Color(0xFF1E1E33);
  static const border = Color(0xFFE6DFD0);
  static const muted = Color(0xFF857F70);
  static const soft = Color(0xFF6E6859);
  static const faint = Color(0xFFA8A4C0);
  static const palette = [
    Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF43D9AD), Color(0xFFFFB347),
    Color(0xFF4FC3F7), Color(0xFFF06292), Color(0xFF81C784), Color(0xFFFFD54F),
  ];
}

Color friendColor(String n) {
  final i = app.friends.indexOf(n);
  return C.palette[(i < 0 ? 0 : i) % C.palette.length];
}

BoxDecoration box({Color border = C.border, double r = 14}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: border),
      boxShadow: const [BoxShadow(color: Color(0x0F2B2A38), blurRadius: 6, offset: Offset(0, 1))],
    );

String rs(double v) => 'Rs. ${v.toStringAsFixed(0)}';
String ymd(DateTime d) => d.toIso8601String().substring(0, 10);

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c).hideCurrentSnackBar();
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F0F1A))),
    backgroundColor: C.mint,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  ));
}

Future<bool> confirm(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
      ],
    ),
  );
  return r ?? false;
}

// ───────────────────────── MODELS ─────────────────────────
class Expense {
  final int id;
  final String title;
  final double amount;
  final String paidBy;
  final List<String> participants;
  final String date;
  Expense({required this.id, required this.title, required this.amount, required this.paidBy, required this.participants, required this.date});

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'amount': amount, 'paidBy': paidBy, 'participants': participants, 'date': date};
  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'],
        title: j['title'],
        amount: (j['amount'] as num).toDouble(),
        paidBy: j['paidBy'],
        participants: List<String>.from(j['participants']),
        date: j['date'] ?? '',
      );
}

class Settlement {
  final int id;
  final String from, to, date;
  final double amount;
  Settlement({required this.id, required this.from, required this.to, required this.amount, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'from': from, 'to': to, 'amount': amount, 'date': date};
  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        id: j['id'], from: j['from'], to: j['to'], amount: (j['amount'] as num).toDouble(), date: j['date'] ?? '');
}

class Debt {
  final String from, to;
  final double amount;
  Debt(this.from, this.to, this.amount);
}

// ───────────────────────── STATE ─────────────────────────
class AppState extends ChangeNotifier {
  List<String> friends = ['Hammad', 'Masab', 'Burhan'];
  List<Expense> expenses = [];
  List<Settlement> settlements = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final f = p.getString('fl_friends');
    final e = p.getString('fl_expenses');
    final s = p.getString('fl_settlements');
    if (f != null) friends = List<String>.from(jsonDecode(f));
    if (e != null) expenses = (jsonDecode(e) as List).map((x) => Expense.fromJson(x)).toList();
    if (s != null) settlements = (jsonDecode(s) as List).map((x) => Settlement.fromJson(x)).toList();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('fl_friends', jsonEncode(friends));
    await p.setString('fl_expenses', jsonEncode(expenses.map((e) => e.toJson()).toList()));
    await p.setString('fl_settlements', jsonEncode(settlements.map((e) => e.toJson()).toList()));
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  // Friends
  bool addFriend(String name) {
    if (friends.contains(name)) return false;
    friends.add(name);
    _changed();
    return true;
  }

  void removeFriend(String name) {
    friends.remove(name);
    expenses.removeWhere((e) => e.paidBy == name);
    expenses = expenses
        .map((e) => Expense(
            id: e.id, title: e.title, amount: e.amount, paidBy: e.paidBy,
            participants: e.participants.where((p) => p != name).toList(), date: e.date))
        .where((e) => e.participants.isNotEmpty)
        .toList();
    settlements.removeWhere((s) => s.from == name || s.to == name);
    _changed();
  }

  // Expenses
  void addExpense(Expense e) {
    expenses.add(e);
    _changed();
  }

  void deleteExpense(int id) {
    expenses.removeWhere((e) => e.id == id);
    _changed();
  }

  // Settlements
  void addSettlement(Settlement s) {
    settlements.add(s);
    _changed();
  }

  void deleteSettlement(int id) {
    settlements.removeWhere((s) => s.id == id);
    _changed();
  }

  // Calculations
  double get total => expenses.fold(0.0, (s, e) => s + e.amount);

  Map<String, double> get balances {
    final bal = {for (final f in friends) f: 0.0};
    for (final e in expenses) {
      final share = e.amount / e.participants.length;
      for (final p in e.participants) {
        if (p != e.paidBy) {
          bal[e.paidBy] = (bal[e.paidBy] ?? 0) + share;
          bal[p] = (bal[p] ?? 0) - share;
        }
      }
    }
    for (final s in settlements) {
      bal[s.from] = (bal[s.from] ?? 0) + s.amount;
      bal[s.to] = (bal[s.to] ?? 0) - s.amount;
    }
    return bal;
  }

  /// Pairwise debts (same as the HTML version): nets only between the same two people.
  List<Debt> get debts {
    final pairs = <(String, String), double>{};
    void add(String debtor, String creditor, double amt) {
      if (debtor == creditor || amt == 0) return;
      final sorted = [debtor, creditor]..sort();
      final key = (sorted[0], sorted[1]);
      pairs[key] = (pairs[key] ?? 0) + (debtor == sorted[0] ? amt : -amt);
    }

    for (final e in expenses) {
      final share = e.amount / e.participants.length;
      for (final p in e.participants) {
        if (p != e.paidBy) add(p, e.paidBy, share);
      }
    }
    for (final s in settlements) {
      add(s.to, s.from, s.amount);
    }

    final out = <Debt>[];
    pairs.forEach((k, v) {
      if (v.abs() < 0.01) return;
      if (v > 0) {
        out.add(Debt(k.$1, k.$2, v));
      } else {
        out.add(Debt(k.$2, k.$1, -v));
      }
    });
    out.sort((a, b) => b.amount.compareTo(a.amount));
    return out;
  }
}

final app = AppState();

// ───────────────────────── MAIN ─────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const HisabKitabApp());
}

class HisabKitabApp extends StatelessWidget {
  const HisabKitabApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HisabKitab',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: C.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: C.purple),
          fontFamily: 'Roboto',
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => Column(
            children: [
              _header(context),
              Container(
                color: C.navy,
                child: const TabBar(
                  labelColor: C.lilac,
                  unselectedLabelColor: C.faint,
                  indicatorColor: C.lilac,
                  dividerColor: C.purple,
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  unselectedLabelStyle: TextStyle(fontSize: 12.5),
                  tabs: [
                    Tab(text: '📊 Dashboard'),
                    Tab(text: '💸 Expenses'),
                    Tab(text: '🤝 Settle'),
                    Tab(text: '👥 Friends'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(children: [DashboardTab(), ExpensesTab(), SettleTab(), FriendsTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
        color: C.navy,
        child: Row(
          children: [
            const Text('📒', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HisabKitab 📒', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.lilac)),
                  Text('Group expense tracker', style: TextStyle(fontSize: 11, color: C.faint)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total Spent', style: TextStyle(fontSize: 10, color: C.faint)),
                Text(rs(app.total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.mint)),
              ],
            ),
            const SizedBox(width: 10),
            _PdfButton(compact: true),
          ],
        ),
      );
}

// ───────────────────────── SHARED WIDGETS ─────────────────────────
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: friendColor(name),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.38)),
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600, letterSpacing: 1)),
      );
}

class TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const TagChip({super.key, required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: selected ? color : C.border, borderRadius: BorderRadius.circular(20)),
          child: Text(selected ? '✓ $label' : label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : C.muted)),
        ),
      );
}

InputDecoration dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA39C8A)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.purple)),
    );

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> colors;
  const GradientButton({super.key, required this.label, required this.onTap, this.colors = const [C.purple, Color(0xFF5A52E0)]});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(12)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      );
}

class _PdfButton extends StatefulWidget {
  final bool compact;
  const _PdfButton({this.compact = false});
  @override
  State<_PdfButton> createState() => _PdfButtonState();
}

class _PdfButtonState extends State<_PdfButton> {
  bool busy = false;
  Future<void> _run() async {
    setState(() => busy = true);
    try {
      await exportPdf();
    } catch (e) {
      if (mounted) toast(context, 'PDF failed: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: busy ? null : _run,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 12 : 14, vertical: widget.compact ? 8 : 9),
          decoration: BoxDecoration(
            color: widget.compact ? null : C.pink,
            gradient: widget.compact ? const LinearGradient(colors: [C.pink, Color(0xFFE0446A)]) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(busy ? '⏳...' : (widget.compact ? '📄 PDF' : '📥 PDF'),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: widget.compact ? 12 : 13)),
        ),
      );
}

// ───────────────────────── DASHBOARD ─────────────────────────
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final bal = app.balances;
    final debts = app.debts;
    final recent = app.expenses.reversed.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A0D1A), Color(0xFF2A1A2E)]),
            border: Border.all(color: const Color(0x44FF6584)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Text('📄', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Download Full Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: C.pink)),
                SizedBox(height: 2),
                Text('PDF: Who Pays Whom + History + All Expenses', style: TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
            _PdfButton(),
          ]),
        ),
        const SectionLabel('Friend Balances'),
        if (app.friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('Add friends to get started!', style: TextStyle(color: Color(0xFFA39C8A)))),
          ),
        ...app.friends.map((f) {
          final b = bal[f] ?? 0;
          final pos = b > 0.01, neg = b < -0.01;
          final col = pos ? C.green : neg ? C.pink : C.muted;
          final txt = pos ? 'is owed money' : neg ? 'owes money' : 'settled up ✓';
          final bord = pos ? const Color(0x3343D9AD) : neg ? const Color(0x33FF6584) : C.border;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: box(border: bord),
            child: Row(children: [
              Avatar(f),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(txt, style: const TextStyle(fontSize: 12, color: C.soft)),
                ]),
              ),
              Text('${pos ? '+' : ''}${b.toStringAsFixed(0)} Rs',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: col)),
            ]),
          );
        }),
        const SizedBox(height: 14),
        const SectionLabel('Who Pays Whom'),
        if (debts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: box(border: const Color(0x3343D9AD)),
            child: const Text('🎉 All settled up!', style: TextStyle(color: C.green, fontWeight: FontWeight.w600)),
          )
        else
          ...debts.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: box(border: const Color(0x22FF6584), r: 12),
                child: Row(children: [
                  Avatar(d.from, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: d.from, style: const TextStyle(color: C.pink, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' pays ', style: TextStyle(color: C.soft, fontSize: 13)),
                      TextSpan(text: d.to, style: const TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                    ])),
                  ),
                  Text(rs(d.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: C.orange, fontSize: 15)),
                ]),
              )),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionLabel('Recent Expenses'),
          ...recent.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: box(r: 12),
                child: Row(children: [
                  Avatar(e.paidBy, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('${e.paidBy} paid • ${e.date}', style: const TextStyle(fontSize: 11, color: C.soft)),
                    ]),
                  ),
                  Text(rs(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: C.purple)),
                ]),
              )),
        ],
      ],
    );
  }
}

// ───────────────────────── EXPENSES ─────────────────────────
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});
  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  final titleC = TextEditingController();
  final amountC = TextEditingController();
  DateTime date = DateTime.now();
  String paidBy = '';
  final Set<String> participants = {};

  @override
  void dispose() {
    titleC.dispose();
    amountC.dispose();
    super.dispose();
  }

  void _add() {
    final title = titleC.text.trim();
    final amount = double.tryParse(amountC.text.trim());
    if (title.isEmpty || amount == null || amount <= 0 || paidBy.isEmpty || participants.isEmpty) {
      toast(context, 'Please fill all fields!');
      return;
    }
    app.addExpense(Expense(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      amount: amount,
      paidBy: paidBy,
      participants: participants.toList(),
      date: ymd(date),
    ));
    setState(() {
      titleC.clear();
      amountC.clear();
      date = DateTime.now();
      paidBy = '';
      participants.clear();
    });
    FocusScope.of(context).unfocus();
    toast(context, 'Expense added! 💸');
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => date = d);
  }

  @override
  Widget build(BuildContext context) {
    final amt = double.tryParse(amountC.text.trim());
    final list = app.expenses.reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: box(r: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('➕ Add New Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.purple)),
            const SizedBox(height: 16),
            TextField(controller: titleC, decoration: dec("What was it? (e.g. Dinner at McDonald's)")),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: amountC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: dec('Amount (Rs)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                    decoration: BoxDecoration(
                        border: Border.all(color: C.border), borderRadius: BorderRadius.circular(10)),
                    child: Text(ymd(date), style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            const Text('Who paid?', style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in app.friends)
                TagChip(label: f, selected: paidBy == f, color: friendColor(f), onTap: () => setState(() => paidBy = f)),
            ]),
            const SizedBox(height: 14),
            const Text('Who was there?', style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in app.friends)
                TagChip(
                  label: f,
                  selected: participants.contains(f),
                  color: friendColor(f),
                  onTap: () => setState(() => participants.contains(f) ? participants.remove(f) : participants.add(f)),
                ),
            ]),
            const SizedBox(height: 16),
            if (amt != null && amt > 0 && participants.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0x226C63FF), borderRadius: BorderRadius.circular(8)),
                child: Text('Each person pays: ${rs(amt / participants.length)}',
                    style: const TextStyle(fontSize: 13, color: C.purple)),
              ),
            GradientButton(label: 'Add Expense', onTap: _add),
          ]),
        ),
        SectionLabel('All Expenses (${list.length})'),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('No expenses yet. Add one above! 👆', style: TextStyle(color: Color(0xFFA39C8A)))),
          ),
        ...list.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: box(),
              child: Column(children: [
                Row(children: [
                  Avatar(e.paidBy, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: C.soft), children: [
                        const TextSpan(text: 'Paid by '),
                        TextSpan(text: e.paidBy, style: TextStyle(color: friendColor(e.paidBy), fontWeight: FontWeight.w600)),
                        TextSpan(text: ' • ${e.date}'),
                      ])),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(rs(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: C.purple)),
                    Text('÷${e.participants.length} = Rs.${(e.amount / e.participants.length).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: C.soft)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final p in e.participants)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                              color: friendColor(p).withAlpha(51), borderRadius: BorderRadius.circular(20)),
                          child: Text(p,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: friendColor(p))),
                        ),
                    ]),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      if (await confirm(context, 'Delete this expense?')) {
                        app.deleteExpense(e.id);
                        if (context.mounted) toast(context, 'Deleted');
                      }
                    },
                    icon: const Text('🗑️', style: TextStyle(fontSize: 18)),
                  ),
                ]),
              ]),
            )),
      ],
    );
  }
}

// ───────────────────────── SETTLE UP ─────────────────────────
class SettleTab extends StatefulWidget {
  const SettleTab({super.key});
  @override
  State<SettleTab> createState() => _SettleTabState();
}

class _SettleTabState extends State<SettleTab> {
  final amountC = TextEditingController();
  String from = '', to = '';

  @override
  void dispose() {
    amountC.dispose();
    super.dispose();
  }

  void _add() {
    final amt = double.tryParse(amountC.text.trim());
    if (from.isEmpty || to.isEmpty || amt == null || amt <= 0 || from == to) {
      toast(context, 'Please fill all fields!');
      return;
    }
    app.addSettlement(Settlement(
        id: DateTime.now().millisecondsSinceEpoch, from: from, to: to, amount: amt, date: ymd(DateTime.now())));
    setState(() {
      amountC.clear();
      from = '';
      to = '';
    });
    FocusScope.of(context).unfocus();
    toast(context, 'Payment recorded! ✅');
  }

  @override
  Widget build(BuildContext context) {
    final debts = app.debts;
    final hist = app.settlements.reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        if (debts.isNotEmpty) ...[
          const SectionLabel('Suggested Payments'),
          ...debts.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: box(border: const Color(0x3343D9AD), r: 12),
                child: Row(children: [
                  Avatar(d.from, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text.rich(TextSpan(style: const TextStyle(fontSize: 14), children: [
                        TextSpan(text: d.from, style: const TextStyle(color: C.pink, fontWeight: FontWeight.w700)),
                        const TextSpan(text: ' → ', style: TextStyle(color: C.soft)),
                        TextSpan(text: d.to, style: const TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                      ])),
                      const Text('Suggested amount', style: TextStyle(fontSize: 12, color: C.soft)),
                    ]),
                  ),
                  Text(rs(d.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: C.orange, fontSize: 16)),
                ]),
              )),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: box(r: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('✅ Record a Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.green)),
            const SizedBox(height: 16),
            const Text('Who paid?', style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in app.friends)
                TagChip(label: f, selected: from == f, color: friendColor(f), onTap: () => setState(() => from = f)),
            ]),
            const SizedBox(height: 14),
            const Text('Paid to?', style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in app.friends)
                TagChip(label: f, selected: to == f, color: friendColor(f), onTap: () => setState(() => to = f)),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: amountC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: dec('Amount paid (Rs)'),
            ),
            const SizedBox(height: 10),
            GradientButton(label: 'Record Payment', onTap: _add, colors: const [C.mint, Color(0xFF2BB890)]),
          ]),
        ),
        const SectionLabel('Payment History'),
        if (hist.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('No payments recorded yet.', style: TextStyle(color: Color(0xFFA39C8A)))),
          ),
        ...hist.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: box(r: 12),
              child: Row(children: [
                Avatar(s.from, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(TextSpan(style: const TextStyle(fontSize: 13), children: [
                      TextSpan(text: s.from, style: const TextStyle(color: C.pink, fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' paid ', style: TextStyle(color: C.soft)),
                      TextSpan(text: s.to, style: const TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                    ])),
                    Text(s.date, style: const TextStyle(fontSize: 11, color: C.soft)),
                  ]),
                ),
                Text(rs(s.amount), style: const TextStyle(fontWeight: FontWeight.w700, color: C.green, fontSize: 15)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    if (await confirm(context, 'Delete this payment?')) {
                      app.deleteSettlement(s.id);
                      if (context.mounted) toast(context, 'Deleted');
                    }
                  },
                  icon: const Text('🗑️', style: TextStyle(fontSize: 16)),
                ),
              ]),
            )),
      ],
    );
  }
}

// ───────────────────────── FRIENDS ─────────────────────────
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});
  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final nameC = TextEditingController();

  @override
  void dispose() {
    nameC.dispose();
    super.dispose();
  }

  void _add() {
    final n = nameC.text.trim();
    if (n.isEmpty) return;
    if (!app.addFriend(n)) {
      toast(context, 'Already in group!');
      return;
    }
    nameC.clear();
    toast(context, '$n added! 🎉');
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 11, color: C.soft)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bal = app.balances;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: box(r: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('👤 Add Friend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.orange)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(controller: nameC, decoration: dec("Friend's name"), onSubmitted: (_) => _add())),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  decoration: BoxDecoration(color: C.amber, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, color: C.navy, fontSize: 14)),
                ),
              ),
            ]),
          ]),
        ),
        SectionLabel('Group Members (${app.friends.length})'),
        if (app.friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('No friends added yet.', style: TextStyle(color: Color(0xFFA39C8A)))),
          ),
        ...app.friends.map((f) {
          final b = bal[f] ?? 0;
          final paid = app.expenses.where((e) => e.paidBy == f).fold(0.0, (s, e) => s + e.amount);
          final count = app.expenses.where((e) => e.participants.contains(f)).length;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: box(border: friendColor(f).withAlpha(51)),
            child: Column(children: [
              Row(children: [
                Avatar(f, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const Text('Member', style: TextStyle(fontSize: 12, color: C.soft)),
                  ]),
                ),
                GestureDetector(
                  onTap: () async {
                    if (await confirm(context, 'Remove $f from group? Their expenses will also be deleted.')) {
                      app.removeFriend(f);
                      if (context.mounted) toast(context, '$f removed');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x22FF6584),
                      border: Border.all(color: const Color(0x44FF6584)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Remove', style: TextStyle(color: C.pink, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _stat('Total Paid', rs(paid), C.purple),
                const SizedBox(width: 10),
                _stat('Expenses', '$count', C.orange),
                const SizedBox(width: 10),
                _stat('Balance', '${b >= 0 ? '+' : ''}${b.toStringAsFixed(0)}', b >= 0 ? C.green : C.pink),
              ]),
            ]),
          );
        }),
      ],
    );
  }
}

// ───────────────────────── PDF REPORT ─────────────────────────
Future<void> exportPdf() async {
  final doc = pw.Document();
  final now = DateTime.now();
  final debts = app.debts;
  final settled = app.settlements.reversed.toList();
  final exps = app.expenses.reversed.toList();
  const purple = PdfColor.fromInt(0xFF6C63FF);

  pw.Widget heading(String t, PdfColor c) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: c)),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows, PdfColor head) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
        headerDecoration: pw.BoxDecoration(color: head),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        border: null,
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    footer: (c) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('HisabKitab - Page ${c.pageNumber} of ${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ),
    build: (c) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        color: PdfColor.fromInt(0xFF0F0F1A),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('HisabKitab', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: purple)),
            pw.Text('Group Expense Report', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Generated: ${ymd(now)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
            pw.Text('Members: ${app.friends.join(', ')}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
          ]),
        ]),
      ),
      pw.SizedBox(height: 12),
      pw.Row(children: [
        for (final b in [
          ['Total Spent', rs(app.total)],
          ['Expenses', '${app.expenses.length} items'],
          ['Settlements', '${app.settlements.length} payments'],
        ])
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(b[1], style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: purple)),
                pw.Text(b[0], style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ]),
            ),
          ),
      ]),
      heading('WHO PAYS WHOM', purple),
      if (debts.isEmpty)
        pw.Text('All settled up!', style: const pw.TextStyle(fontSize: 11, color: PdfColors.green700))
      else ...[
        table(['#', 'FROM (Owes)', 'TO (Gets Paid)', 'AMOUNT'],
            [for (var i = 0; i < debts.length; i++) ['${i + 1}', debts[i].from, debts[i].to, rs(debts[i].amount)]], purple),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('TOTAL OUTSTANDING: ${rs(debts.fold(0.0, (s, d) => s + d.amount))}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      ],
      heading('SETTLEMENT HISTORY', PdfColors.teal700),
      if (settled.isEmpty)
        pw.Text('No payments recorded yet.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
      else ...[
        table(['#', 'FROM', 'TO', 'DATE', 'AMOUNT'],
            [for (var i = 0; i < settled.length; i++) ['${i + 1}', settled[i].from, settled[i].to, settled[i].date, rs(settled[i].amount)]],
            PdfColors.teal700),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('TOTAL SETTLED: ${rs(settled.fold(0.0, (s, e) => s + e.amount))}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      ],
      heading('ALL EXPENSES', PdfColors.orange700),
      if (exps.isEmpty)
        pw.Text('No expenses yet.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
      else ...[
        table(['#', 'TITLE', 'PAID BY', 'PARTICIPANTS', 'DATE', 'AMOUNT'],
            [for (var i = 0; i < exps.length; i++)
              ['${i + 1}', exps[i].title, exps[i].paidBy, exps[i].participants.join(', '), exps[i].date, rs(exps[i].amount)]],
            PdfColors.orange700),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('GRAND TOTAL: ${rs(app.total)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      ],
    ],
  ));

  await Printing.sharePdf(bytes: await doc.save(), filename: 'HisabKitab_Report_${ymd(now)}.pdf');
}
