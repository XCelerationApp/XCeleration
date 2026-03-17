import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Colours ─────────────────────────────────────────────────────────────────
const kPrimary = Color(0xFFE2572B);
const kRed     = Color(0xFFE53935);
const kGreen   = Color(0xFF43A047);
const kAmber   = Color(0xFFF59E0B);
const kSurface = Color(0xFFF7F7F7);
const kBorder  = Color(0xFFEEEEEE);
const kText    = Color(0xFF1A1A1A);
const kSub     = Color(0xFF888888);
const kLight   = Color(0xFFBBBBBB);

// ─── Models ───────────────────────────────────────────────────────────────────
class RunnerModel {
  final int bib;
  final String name, last, first, team;
  const RunnerModel({required this.bib, required this.name,
    required this.last, required this.first, required this.team});
}

class RaceRecord {
  final int id;
  int bib;
  int? correctedTo;
  RaceRecord({required this.id, required this.bib, this.correctedTo});
  RaceRecord copyWith({int? bib, int? correctedTo}) =>
    RaceRecord(id: id, bib: bib ?? this.bib, correctedTo: correctedTo ?? this.correctedTo);
}

class RaceModel {
  final int id;
  final String name, date;
  final int teams;
  final String status; // ready | done
  const RaceModel({required this.id, required this.name,
    required this.date, required this.teams, required this.status});
  RaceModel withStatus(String s) =>
    RaceModel(id: id, name: name, date: date, teams: teams, status: s);
}

class VerifierEntry {
  final int id, pos, bib;
  final String? flag;
  String status; // pending | confirmed | wrong | skipped
  VerifierEntry({required this.id, required this.pos,
    required this.bib, this.flag, this.status = 'pending'});
}

class FixerEntry {
  final int id, pos, bib;
  final String flag, context;
  FixerEntry({required this.id, required this.pos, required this.bib,
    required this.flag, required this.context});
}

class FixerResolved {
  final int pos, resolvedBib;
  final String resolvedName;
  final bool corrected, isNew;
  const FixerResolved({required this.pos, required this.resolvedBib,
    required this.resolvedName, this.corrected = false, this.isNew = false});
}

// ─── Data ─────────────────────────────────────────────────────────────────────
const kRoster = [
  RunnerModel(bib:1,   name:'Alex Johnson',      last:'Johnson',   first:'Alex',    team:'EAG'),
  RunnerModel(bib:10,  name:'Cameron Whitfield', last:'Whitfield', first:'Cameron', team:'TIG'),
  RunnerModel(bib:15,  name:'Logan White',       last:'White',     first:'Logan',   team:'FAL'),
  RunnerModel(bib:101, name:'Marcus Webb',       last:'Webb',      first:'Marcus',  team:'WES'),
  RunnerModel(bib:102, name:'Nia Okafor',        last:'Okafor',    first:'Nia',     team:'LAK'),
  RunnerModel(bib:103, name:'Elena Cruz',        last:'Cruz',      first:'Elena',   team:'WES'),
  RunnerModel(bib:104, name:'James Holden',      last:'Holden',    first:'James',   team:'PIN'),
  RunnerModel(bib:105, name:'Sarah Tran',        last:'Tran',      first:'Sarah',   team:'LAK'),
  RunnerModel(bib:107, name:'Priya Singh',       last:'Singh',     first:'Priya',   team:'RIV'),
  RunnerModel(bib:108, name:'Tom Gallagher',     last:'Gallagher', first:'Tom',     team:'PIN'),
  RunnerModel(bib:110, name:'Jalen Moore',       last:'Moore',     first:'Jalen',   team:'WES'),
  RunnerModel(bib:111, name:'Rosa Vega',         last:'Vega',      first:'Rosa',    team:'LAK'),
  RunnerModel(bib:113, name:'Callum Grant',      last:'Grant',     first:'Callum',  team:'RIV'),
];

const kTeamColors = {
  'EAG': Color(0xFF1E88E5), 'TIG': Color(0xFFFB8C00), 'FAL': Color(0xFF43A047),
  'WES': Color(0xFF8E24AA), 'LAK': Color(0xFF1E88E5), 'PIN': Color(0xFFFB8C00),
  'RIV': Color(0xFF43A047),
};

const kMockRaces = [
  RaceModel(id:1, name:'Varsity Boys 5K',  date:'Today · 10:00 AM', teams:8,  status:'ready'),
  RaceModel(id:2, name:'JV Girls 3K',      date:'Today · 11:30 AM', teams:6,  status:'ready'),
  RaceModel(id:3, name:'Open 5K',          date:'Mar 14 · 9:00 AM', teams:12, status:'done'),
  RaceModel(id:4, name:'Freshman 1.5K',    date:'Mar 14 · 2:00 PM', teams:5,  status:'done'),
];

List<VerifierEntry> get kDemoEntries => [
  VerifierEntry(id:1, pos:1, bib:107, flag:null),
  VerifierEntry(id:2, pos:2, bib:101, flag:null),
  VerifierEntry(id:3, pos:3, bib:23,  flag:'UNKNOWN'),
  VerifierEntry(id:4, pos:4, bib:110, flag:null),
  VerifierEntry(id:5, pos:5, bib:103, flag:null),
  VerifierEntry(id:6, pos:6, bib:108, flag:null),
  VerifierEntry(id:7, pos:7, bib:107, flag:'DUPLICATE'),
  VerifierEntry(id:8, pos:8, bib:111, flag:null),
];

List<FixerEntry> get kFixerQueue => [
  FixerEntry(id:3, pos:3, bib:23,  flag:'UNKNOWN',   context:"Marked wrong — bib doesn't match runner"),
  FixerEntry(id:7, pos:7, bib:107, flag:'DUPLICATE', context:'Bib 107 already recorded at position 1'),
  FixerEntry(id:9, pos:9, bib:415, flag:'UNKNOWN',   context:"Marked wrong — bib doesn't match runner"),
];

// ─── Helpers ─────────────────────────────────────────────────────────────────
String ordinal(int n) {
  final v = n % 100;
  const s = ['th','st','nd','rd'];
  return '$n${s[(v - 20) % 10 < 4 ? (v - 20) % 10 : 0].isNotEmpty && (v - 20) % 10 < 4 ? s[(v - 20) % 10] : s[v] ?? s[0]}';
}

String _ordinal(int n) {
  final v = n % 100;
  if (v >= 11 && v <= 13) return '${n}th';
  switch (n % 10) {
    case 1: return '${n}st';
    case 2: return '${n}nd';
    case 3: return '${n}rd';
    default: return '${n}th';
  }
}

String? getFlag(int bib, List<RaceRecord> records, {int? excludeId}) {
  final inRoster = kRoster.any((r) => r.bib == bib);
  final dupes = records.where((r) => r.bib == bib && r.id != excludeId).length;
  if (dupes > 0) return 'duplicate';
  if (!inRoster) return 'unknown';
  return null;
}

RunnerModel? findRunner(int bib) =>
  kRoster.where((r) => r.bib == bib).firstOrNull;

Color teamColor(String team) => kTeamColors[team] ?? kSub;

// ─── Connection simulation ────────────────────────────────────────────────────
enum ConnectionStatus { connected, offline, syncing }

class ConnectionNotifier extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.connected;
  int_queueCount = 0;
  Timer? _cycleTimer;
  Timer?_queueTimer;

  ConnectionStatus get status => _status;
  int get queueCount =>_queueCount;

  void startSimulation() {
    _schedule();
  }

  void stopSimulation() {
    _cycleTimer?.cancel();
    _queueTimer?.cancel();
    _status = ConnectionStatus.connected;
    _queueCount = 0;
    notifyListeners();
  }

  void _schedule() {
    _cycleTimer = Timer(const Duration(seconds: 18), () {
      _status = ConnectionStatus.offline;
      _queueCount = 0;
      notifyListeners();
      int q = 0;
      _queueTimer = Timer.periodic(const Duration(milliseconds: 1200), (t) {
        q++;
        _queueCount = q;
        notifyListeners();
        if (q >= 3) t.cancel();
      });
      Timer(const Duration(seconds: 5), () {
        _status = ConnectionStatus.syncing;
        notifyListeners();
        Timer(const Duration(seconds: 2), () {
          _status = ConnectionStatus.connected;
          _queueCount = 0;
          notifyListeners();
          _schedule();
        });
      });
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _queueTimer?.cancel();
    super.dispose();
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
          decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('LIVE', style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w800, color: kRed, letterSpacing: 0.3)),
      ]),
    );
  }
}

class NotStartedBadge extends StatelessWidget {
  const NotStartedBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: kBorder),
      ),
      child: const Text('Not Started', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: kSub)),
    );
  }
}

class ConnectionBanner extends StatelessWidget {
  final String role;
  final ConnectionStatus status;
  final int queueCount;
  const ConnectionBanner({super.key, required this.role,
    required this.status, required this.queueCount});

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.connected) return const SizedBox.shrink();
    final peer = role == 'bib' ? 'Verifier' : role == 'verifier' ? 'Fixer' : 'Coach';
    final isOffline = status == ConnectionStatus.offline;
    final color = isOffline ? kSub : kAmber;
    final bg    = isOffline ? const Color(0xFFF5F5F5) : const Color(0xFFFFF8E1);
    final border= isOffline ? kBorder : const Color(0xFFFFE082);
    final icon  = isOffline ? '⚡' : '⏳';
    final msg   = isOffline
      ? '$peer offline — entries queuing locally'
      : 'Reconnected — syncing $queueCount queued entr${queueCount == 1 ? "y" : "ies"}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: color))),
      ]),
    );
  }
}

// ─── App sheet ────────────────────────────────────────────────────────────────
Future<T?> showAppSheet<T>(BuildContext context, {
  String? title, required Widget child, bool tall = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>_AppSheet(title: title, tall: tall, child: child),
  );
}

class _AppSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool tall;
  const_AppSheet({this.title, required this.child, this.tall = false});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: tall ? 0.88 : 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(99)))),
          if (title != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title!, style: const TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w700, color: kText)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F0F0), shape: BoxShape.circle),
                      child: const Center(child: Text('✕',
                        style: TextStyle(fontSize: 14, color: kSub))),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kBorder),
          ],
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(22),
            children: [child],
          )),
        ]),
      ),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────
class BottomBar extends StatefulWidget {
  final bool live;
  final VoidCallback? onStop;
  final VoidCallback? onBegin;
  final String stopLabel;
  final List<_MenuItem> menuItems;

  const BottomBar({super.key,
    this.live = true, this.onStop, this.onBegin,
    this.stopLabel = 'Stop Race', this.menuItems = const [],
  });

  @override State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  bool_menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final isResume = widget.stopLabel.toLowerCase().contains('resume');
    final useGreen = !widget.live || isResume;
    final btnColor  = useGreen ? kGreen : kRed;
    final btnBg     = useGreen ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.06);
    final btnBorder = useGreen ? kGreen : kRed.withOpacity(0.35);
    final btnLabel  = !widget.live ? 'Start Race' : widget.stopLabel;
    final menuItems = widget.menuItems.isNotEmpty
      ? widget.menuItems
      : [_MenuItem('See Runners'),_MenuItem('Load New Race'), _MenuItem('Settings')];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: !widget.live ? widget.onBegin : widget.onStop,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: btnBg, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: btnBorder),
                  boxShadow: useGreen ? [BoxShadow(
                    color: kGreen.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 3))] : [],
                ),
                child: Center(child: Text(btnLabel, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: btnColor))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _menuOpen = !_menuOpen),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: const Center(child: Text('⋮',
                style: TextStyle(fontSize: 20, color: kSub))),
            ),
          ),
        ]),
        if (_menuOpen) ...[
          Positioned.fill(child: GestureDetector(
            onTap: () => setState(() => _menuOpen = false),
            child: Container(color: Colors.transparent),
          )),
          Positioned(
            bottom: 52, right: 0,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 8, shadowColor: Colors.black26,
              child: SizedBox(
                width: 210,
                child: Column(mainAxisSize: MainAxisSize.min,
                  children: menuItems.asMap().entries.map((e) {
                    final i = e.key; final item = e.value;
                    return GestureDetector(
                      onTap: () { setState(() => _menuOpen = false); item.onPress?.call(); },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          border: i < menuItems.length - 1
                            ? const Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))
                            : null,
                        ),
                        child: Text(item.label, style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: item.danger ? kRed : kText)),
                      ),
                    );
                  }).toList()),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _MenuItem {
  final String label;
  final VoidCallback? onPress;
  final bool danger;
  const_MenuItem(this.label, {this.onPress, this.danger = false});
}

// ─── Confirm sheet ────────────────────────────────────────────────────────────
Future<bool?> showConfirm(BuildContext context, {
  required String title, required String message,
  String confirmLabel = 'Delete',
}) => showAppSheet<bool>(context,
  title: title,
  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(message, style: const TextStyle(
      fontSize: 14, color: Color(0xFF666666), height: 1.6)),
    const SizedBox(height: 22),
    Row(children: [
      Expanded(child: GestureDetector(
        onTap: () => Navigator.pop(context, false),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
          child: const Center(child: Text('Cancel',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kSub))),
        ),
      )),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: GestureDetector(
        onTap: () => Navigator.pop(context, true),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(confirmLabel, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
        ),
      )),
    ]),
  ]),
);

// ─── Swipeable bib row ────────────────────────────────────────────────────────
class SwipeBibRow extends StatefulWidget {
  final RaceRecord record;
  final int position;
  final List<RaceRecord> records;
  final VoidCallback onDelete;
  final void Function(int) onSave;
  final bool isNew;
  const SwipeBibRow({super.key, required this.record, required this.position,
    required this.records, required this.onDelete, required this.onSave,
    this.isNew = false});
  @override State<SwipeBibRow> createState() => _SwipeBibRowState();
}

class _SwipeBibRowState extends State<SwipeBibRow> {
  bool_editing = false;
  late TextEditingController _ctrl;
  static const double_actionW = 80;

  @override void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.record.bib}');
  }
  @override void dispose() {_ctrl.dispose(); super.dispose(); }

  void _commit() {
    final n = int.tryParse(_ctrl.text);
    if (n != null && n > 0) widget.onSave(n);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final run = findRunner(widget.record.bib);
    final f   = getFlag(widget.record.bib, widget.records, excludeId: widget.record.id);
    return Dismissible(
      key: ValueKey(widget.record.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async { widget.onDelete(); return false; },
      background: Container(
        alignment: Alignment.centerRight,
        color: kRed,
        padding: const EdgeInsets.only(right: 24),
        child: const Text('Delete', style: TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
      child: Container(
        color: widget.isNew ? kPrimary.withOpacity(0.05) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          SizedBox(width: 26, child: Text('${widget.position}.',
            style: const TextStyle(fontSize: 12, color: kLight))),
          _editing
            ? SizedBox(width: 56, child: TextField(
                controller: _ctrl, autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w800, color: kPrimary),
                decoration: const InputDecoration(
                  isDense: true, contentPadding: EdgeInsets.only(bottom: 2),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: kPrimary, width: 2)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kPrimary, width: 2)),
                ),
                onSubmitted: (_) => _commit(),
              ))
            : GestureDetector(
                onTap: () { setState(() { _editing = true; _ctrl.text = '${widget.record.bib}'; }); },
                child: Container(
                  width: 52,
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD), style: BorderStyle.solid))),
                  child: Text('${widget.record.bib}', style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: kText)),
                ),
              ),
          const SizedBox(width: 6),
          Expanded(child: widget.record.correctedTo != null
            ? Text('✓ corrected → #${widget.record.correctedTo}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGreen))
            : f == null && run != null
              ? Row(children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: teamColor(run.team), shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Text('${run.name}, ${run.team}',
                    style: const TextStyle(fontSize: 13, color: kSub)),
                ])
              : Text(f == 'duplicate' ? '⚠ Duplicate' : '? Not in roster',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: f == 'duplicate' ? const Color(0xFFFF7070) : const Color(0xFFFFA726))),
          ),
          const Text('‹', style: TextStyle(fontSize: 11, color: Color(0xFFCCCCCC))),
        ]),
      ),
    );
  }
}

// ─── Load Race sheet ──────────────────────────────────────────────────────────
class LoadRaceSheet extends StatefulWidget {
  final void Function(RaceModel) onLoaded;
  const LoadRaceSheet({super.key, required this.onLoaded});
  @override State<LoadRaceSheet> createState() => _LoadRaceSheetState();
}

class _LoadRaceSheetState extends State<LoadRaceSheet> {
  bool_searching = true;
  RaceModel? _found;

  @override void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _found = const RaceModel(id: 99, name: 'Spring Invitational',
          date: 'Today · 9:00 AM', teams: 10, status: 'ready');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Coach row
      GestureDetector(
        onTap: () { if (_found != null) { widget.onLoaded(_found!); Navigator.pop(context); } },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
          child: Row(children: [
            const Icon(Icons.person_outline, color: kSub, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Coach', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: kText)),
              if (_found != null) Text(_found!.name, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: kPrimary)),
            ])),
            if (_searching) ...[
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
                strokeWidth: 2, color: kSub.withOpacity(0.5))),
              const SizedBox(width: 6),
              const Text('Searching', style: TextStyle(fontSize: 13, color: kSub)),
            ] else if (_found != null)
              const Text('›', style: TextStyle(fontSize: 18, color: kGreen, fontWeight: FontWeight.w700))
            else
              const Text('None found', style: TextStyle(fontSize: 13, color: kLight)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFF0F0F0))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(fontSize: 13, color: kLight))),
        Expanded(child: Container(height: 1, color: const Color(0xFFF0F0F0))),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder)),
        child: Row(children: [
          const Icon(Icons.qr_code_2_outlined, color: kText, size: 24),
          const SizedBox(width: 14),
          const Text('Scan QR Code', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: kText)),
        ]),
      ),
    ]);
  }
}

// ─── Race lobby ───────────────────────────────────────────────────────────────
class RaceLobby extends StatefulWidget {
  final String role;
  final void Function(RaceModel) onStart;
  const RaceLobby({super.key, required this.role, required this.onStart});
  @override State<RaceLobby> createState() => _RaceLobbyState();
}

class _RaceLobbyState extends State<RaceLobby> {
  List<RaceModel>_races = List.from(kMockRaces);
  RaceModel? _selected;

  String get _roleLabel => {'bib':'Bib Recorder','verifier':'Verifier','fixer':'Fixer'}[widget.role]!;
  String get_roleIcon  => {'bib':'🎙','verifier':'👀','fixer':'🔧'}[widget.role]!;

  void _loadRace(RaceModel r) {
    setState(() {
      if (!_races.any((x) => x.id == r.id)) _races = [r, ..._races];
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _races.where((r) => r.status == 'ready').toList();
    final done  =_races.where((r) => r.status == 'done').toList();

    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(child: Column(children: [
        // Header
        Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_roleIcon $_roleLabel'.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: kLight, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Select a Race', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
              GestureDetector(
                onTap: () => showAppSheet(context,
                  title: 'Load Race',
                  child: LoadRaceSheet(onLoaded: _loadRace)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimary)),
                  child: const Text('＋ Load Race', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
                ),
              ),
            ]),
          ]),
        ),
        // List
        Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
          const Text('AVAILABLE', style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w700, color: kLight, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...ready.map((race) => GestureDetector(
            onTap: () => setState(() => _selected = race),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _selected?.id == race.id
                  ? kPrimary.withOpacity(0.04) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _selected?.id == race.id ? kPrimary : const Color(0xFFE8E8E8),
                  width: _selected?.id == race.id ? 2 : 1.5),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(race.name, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
                  const SizedBox(height: 4),
                  Text('${race.date} · ${race.teams} teams',
                    style: const TextStyle(fontSize: 12, color: kSub)),
                ])),
                if (_selected?.id == race.id)
                  Container(width: 20, height: 20,
                    decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                    child: const Center(child: Text('✓',
                      style: TextStyle(color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w800)))),
              ]),
            ),
          )),
          if (done.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Text('PAST RACES', style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w700, color: kLight, letterSpacing: 1.2)),
            ),
            ...done.map((race) => Opacity(opacity: 0.6, child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F0))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(race.name, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: kText)),
                Text('${race.date} · ${race.teams} teams',
                  style: const TextStyle(fontSize: 12, color: kLight)),
              ]),
            ))),
          ],
        ])),
        // Start button
        Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: kBorder))),
          child: GestureDetector(
            onTap: _selected != null ? () => widget.onStart(_selected!) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: _selected != null
                  ? const LinearGradient(colors: [kPrimary, Color(0xFFF07A50)])
                  : null,
                color: _selected == null ? const Color(0xFFEBEBEB) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _selected != null ? [
                  BoxShadow(color: kPrimary.withOpacity(0.35),
                    blurRadius: 16, offset: const Offset(0, 4))] : [],
              ),
              child: Center(child: Text(
                _selected != null ? 'Start as $_roleLabel →' : 'Select a race to start',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: _selected != null ? Colors.white : kSub))),
            ),
          ),
        ),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BIB RECORDER
// ══════════════════════════════════════════════════════════════════════════════
class BibRecorderScreen extends StatefulWidget {
  const BibRecorderScreen({super.key});
  @override State<BibRecorderScreen> createState() => _BibRecorderScreenState();
}

class _BibRecorderScreenState extends State<BibRecorderScreen> {
  RaceModel?_race;
  bool _live   = false;
  bool_stopped = false;
  List<RaceRecord> _records = [];

  void _addBib(int bib) =>
    setState(() =>_records.add(RaceRecord(id: DateTime.now().millisecondsSinceEpoch, bib: bib)));
  void _leave()  => setState(() {_race = null; _live = false;_stopped = false; _records = []; });
  void_delete() => _leave();

  @override
  Widget build(BuildContext context) {
    if (_race == null) return RaceLobby(role: 'bib', onStart: (r) => setState(() =>_race = r));
    if (_stopped) return_ManageModeWidget(
      raceName: _race!.name, records:_records,
      onSetRecords: (r) => setState(() => _records = r),
      onResume: () => setState(() {_stopped = false; _live = true; }),
      onLeave:_leave, onDelete: _delete,
    );
    return_RaceModeWidget(
      raceName: _race!.name, records:_records,
      onSetRecords: (r) => setState(() => _records = r),
      onAdd:_addBib,
      onStop: () => setState(() => _stopped = true),
      onDelete:_delete,
      live: _live, onBegin: () => setState(() =>_live = true),
    );
  }
}

class _RaceModeWidget extends StatefulWidget {
  final String raceName;
  final List<RaceRecord> records;
  final void Function(List<RaceRecord>) onSetRecords;
  final void Function(int) onAdd;
  final VoidCallback onStop, onDelete;
  final bool live;
  final VoidCallback onBegin;
  const_RaceModeWidget({required this.raceName, required this.records,
    required this.onSetRecords, required this.onAdd, required this.onStop,
    required this.onDelete, required this.live, required this.onBegin});
  @override State<_RaceModeWidget> createState() =>_RaceModeWidgetState();
}

class _RaceModeWidgetState extends State<_RaceModeWidget> {
  bool _listening = false;
  String_transcript = '';
  int? _confirming;
  int?_flash;
  double _wavePhase = 0;
  Timer?_waveTimer;
  Timer? _demoTimer;
  int_demoBibIdx = 0;
  final _demoBibs = const [108, 415, 111, 113, 15, 104, 102, 107];
  final_connNotifier = ConnectionNotifier();

  @override void initState() { super.initState(); if (widget.live) _connNotifier.startSimulation(); }
  @override void didUpdateWidget(_RaceModeWidget old) {
    super.didUpdateWidget(old);
    if (widget.live && !old.live) _connNotifier.startSimulation();
    if (!widget.live && old.live)_connNotifier.stopSimulation();
  }
  @override void dispose() { _waveTimer?.cancel();_demoTimer?.cancel(); _connNotifier.dispose(); super.dispose(); }

  void _start() {
    _demoTimer?.cancel();
    setState(() { _listening = true;_transcript = ''; _confirming = null; });
    _waveTimer = Timer.periodic(const Duration(milliseconds: 80),
      (_) => setState(() =>_wavePhase += 1));
    final bib = _demoBibs[_demoBibIdx % _demoBibs.length];
    _demoBibIdx++;
    final s = '$bib'; int i = 0;
    _demoTimer = Timer.periodic(const Duration(milliseconds: 160), (t) {
      i++; setState(() =>_transcript = s.substring(0, i));
      if (i >= s.length) t.cancel();
    });
  }

  void _finish() {
    _waveTimer?.cancel(); _demoTimer?.cancel();
    final n = int.tryParse(_transcript);
    setState(() { _listening = false; if (n != null && n > 0)_confirming = n; });
    // Simulate back-propagation after 12s
    if (widget.live) {
      Future.delayed(const Duration(seconds: 12), () {
        if (!mounted) return;
        final dupIdx = widget.records.indexWhere(
          (r) => getFlag(r.bib, widget.records, excludeId: r.id) == 'duplicate');
        if (dupIdx >= 0) {
          final updated = List<RaceRecord>.from(widget.records);
          updated[dupIdx] = updated[dupIdx].copyWith(correctedTo: 114);
          widget.onSetRecords(updated);
        }
      });
    }
  }

  void _confirmAdd() {
    if (_confirming == null) return;
    widget.onAdd(_confirming!);
    setState(() {_flash = _confirming;_confirming = null; _transcript = ''; });
    Future.delayed(const Duration(milliseconds: 800), () { if (mounted) setState(() =>_flash = null); });
  }

  List<double> get _bars {
    if (!_listening) return List.filled(20, 3);
    return List.generate(20, (i) {
      final v = sin((_wavePhase + i) *0.6)* 0.5 + 0.5
              + sin(_wavePhase *1.7 + i* 1.3) *0.3;
      return max(3, (v* 28).roundToDouble());
    });
  }

  String? get _flag {
    final d =_confirming ?? (int.tryParse(_transcript));
    if (d == null) return null;
    return getFlag(d, widget.records);
  }

  RunnerModel? get _runner {
    final d =_confirming ?? (int.tryParse(_transcript));
    return d != null ? findRunner(d) : null;
  }

  Color get _borderColor {
    if (_confirming != null) {
      if (_flag == 'duplicate') return kRed.withOpacity(0.6);
      if (_flag == 'unknown')   return kAmber.withOpacity(0.5);
      return kPrimary.withOpacity(0.6);
    }
    if (_listening) return kPrimary.withOpacity(0.5);
    return kBorder;
  }

  @override
  Widget build(BuildContext context) {
    final displayBib = _confirming ?? int.tryParse(_transcript);
    final reversed = widget.records.reversed.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BIB RECORDER', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: kLight, letterSpacing: 1.2)),
              const SizedBox(height: 3),
              Text(widget.raceName, style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
            ]),
            Row(children: [
              widget.live ? const LiveBadge() : const NotStartedBadge(),
              const SizedBox(width: 8),
              Text('${widget.records.length}', style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: kSub)),
            ]),
          ]),
        ),
        // Connection banner
        if (widget.live) ListenableBuilder(
          listenable: _connNotifier,
          builder: (_, __) => ConnectionBanner(
            role: 'bib', status: _connNotifier.status,
            queueCount: _connNotifier.queueCount),
        ),
        // Voice display
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor, width: 1.5),
              ),
              child: _listening
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: _bars.map((h) =>
                    AnimatedContainer(duration: const Duration(milliseconds: 80),
                      width: 3, height: h, margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.6 + (h / 32) * 0.4),
                        borderRadius: BorderRadius.circular(99)),
                    )).toList())
                : _transcript.isNotEmpty
                  ? Column(children: [
                      Text('#$_transcript', style: const TextStyle(
                        fontSize: 44, fontWeight: FontWeight.w900, color: kText,
                        letterSpacing: -2, height: 1)),
                      if (_runner != null && _flag == null) ...[
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 7, height: 7,
                            decoration: BoxDecoration(color: teamColor(_runner!.team),
                              shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('${_runner!.name}, ${_runner!.team}',
                            style: const TextStyle(fontSize: 13, color: kSub)),
                        ]),
                      ],
                      if (_flag == 'duplicate') Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: const Text('⚠ Already recorded — will be flagged',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFFFF7070)))),
                      if (_flag == 'unknown') Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: const Text('❓ Not in roster — will be flagged',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFFFFB74D)))),
                    ])
                  : const Center(child: Text('Hold mic to record a bib number',
                      style: TextStyle(fontSize: 14, color: kLight))),
            ),
            const SizedBox(height: 12),
            if (_confirming != null) Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _confirming = null; _transcript = ''; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder)),
                  child: const Center(child: Text('Re-record',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kSub)))),
              )),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: GestureDetector(
                onTap: _confirmAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _flag == 'duplicate' ? kRed : _flag == 'unknown' ? kAmber : kPrimary,
                    borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(
                    _flag != null ? 'Add Anyway' : 'Add #${_confirming}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white)))),
              )),
            ])
            else if (widget.live) Column(children: [
              GestureDetector(
                onPanStart: (_) => _start(),
                onPanEnd: (_) => _finish(),
                onTapDown: (_) => _start(),
                onTapUp: (_) => _finish(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? kPrimary : const Color(0xFFF0F0F0),
                    border: Border.all(
                      color: _listening ? kPrimary : const Color(0xFFDDDDDD), width: 2.5),
                    boxShadow: _listening ? [
                      BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 20, spreadRadius: 4),
                    ] : [],
                  ),
                  child: Icon(Icons.mic,
                    color: _listening ? Colors.white : kSub, size: 28),
                ),
              ),
              const SizedBox(height: 8),
              Text(_listening ? 'LISTENING…' : 'HOLD TO RECORD',
                style: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w600, color: kLight, letterSpacing: 0.5)),
            ]),
          ]),
        ),
        // Record list
        Expanded(child: widget.records.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('🏁', style: TextStyle(fontSize: 32)),
              SizedBox(height: 10),
              Text('Enter the first bib above',
                style: TextStyle(fontSize: 14, color: kLight)),
            ]))
          : ListView.builder(
              itemCount: reversed.length,
              itemBuilder: (_, i) => SwipeBibRow(
                record: reversed[i],
                position: widget.records.length - i,
                records: widget.records,
                isNew: _flash == reversed[i].bib && i == 0,
                onDelete: () => widget.onSetRecords(
                  widget.records.where((r) => r.id != reversed[i].id).toList()),
                onSave: (n) => widget.onSetRecords(
                  widget.records.map((r) =>
                    r.id == reversed[i].id ? r.copyWith(bib: n) : r).toList()),
              ),
            ),
        ),
        BottomBar(
          live: widget.live, onBegin: widget.onBegin,
          onStop: () => showConfirm(context,
            title: 'Stop Race?',
            message: 'Stopping ends recording. You can still edit entries and share results.',
            confirmLabel: 'Stop Race',
          ).then((v) { if (v == true) widget.onStop(); }),
          menuItems: [
            _MenuItem('Clear All Records', danger: true,
              onPress: () => widget.onSetRecords([])),
            _MenuItem('Delete Race', danger: true,
              onPress: () => showConfirm(context, title: 'Delete Race?',
                message: 'Permanently deletes all ${widget.records.length} bib records.',
                confirmLabel: 'Delete')
                .then((v) { if (v == true) widget.onDelete(); })),
            _MenuItem('See Runners'),
          ],
        ),
      ])),
    );
  }
}

class _ManageModeWidget extends StatefulWidget {
  final String raceName;
  final List<RaceRecord> records;
  final void Function(List<RaceRecord>) onSetRecords;
  final VoidCallback onResume, onLeave, onDelete;
  const_ManageModeWidget({required this.raceName, required this.records,
    required this.onSetRecords, required this.onResume,
    required this.onLeave, required this.onDelete});
  @override State<_ManageModeWidget> createState() =>_ManageModeWidgetState();
}

class _ManageModeWidgetState extends State<_ManageModeWidget> {
  List<RaceRecord> get _conflicts =>
    widget.records.where((r) => getFlag(r.bib, widget.records, excludeId: r.id) != null).toList();

  @override
  Widget build(BuildContext context) {
    final hasConflicts = _conflicts.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BIB RECORDER', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: kLight, letterSpacing: 1.2)),
              const SizedBox(height: 3),
              Text(widget.raceName, style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
            ]),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kGreen)),
                child: const Text('Completed', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kGreen))),
              if (hasConflicts) ...[
                const SizedBox(width: 8),
                Text('⚠ ${_conflicts.length}', style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
              ],
            ]),
          ]),
        ),
        // Share Bibs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: GestureDetector(
            onTap: () => showAppSheet(context, title: 'Share Bibs',
              child: Column(children: [
                const Text('📡', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                const Text('Ready to share', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: kText)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPrimary, Color(0xFFF07A50)]),
                      borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: Text('Broadcast to Coach →',
                      style: TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700))))),
              ])),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kPrimary, Color(0xFFF07A50)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.35),
                  blurRadius: 16, offset: const Offset(0, 4))]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('⤴ Share Bibs', style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
        // Record list
        Expanded(child: widget.records.isEmpty
          ? const Center(child: Text('No records', style: TextStyle(color: kLight)))
          : ListView.builder(
              itemCount: widget.records.length,
              itemBuilder: (_, i) => SwipeBibRow(
                record: widget.records[i],
                position: i + 1, records: widget.records,
                onDelete: () => widget.onSetRecords(
                  widget.records.where((r) => r.id != widget.records[i].id).toList()),
                onSave: (n) => widget.onSetRecords(
                  widget.records.map((r) =>
                    r.id == widget.records[i].id ? r.copyWith(bib: n) : r).toList()),
              ),
            ),
        ),
        BottomBar(
          live: true, stopLabel: 'Resume Recording', onStop: widget.onResume,
          menuItems: [
            _MenuItem('Clear All Records', danger: true,
              onPress: () => widget.onSetRecords([])),
            _MenuItem('Delete Race', danger: true, onPress: () =>
              showConfirm(context, title: 'Delete Race?',
                message: 'Permanently deletes all ${widget.records.length} records.',
                confirmLabel: 'Delete')
                .then((v) { if (v == true) widget.onDelete(); })),
            _MenuItem('Leave Race', onPress: widget.onLeave),
          ],
        ),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// VERIFIER
// ══════════════════════════════════════════════════════════════════════════════
class VerifierScreen extends StatefulWidget {
  const VerifierScreen({super.key});
  @override State<VerifierScreen> createState() => _VerifierScreenState();
}

class _VerifierScreenState extends State<VerifierScreen> {
  RaceModel?_race;
  bool _live = false;
  void_leave() => setState(() { _race = null;_live = false; });

  @override
  Widget build(BuildContext context) {
    if (_race == null) return RaceLobby(role: 'verifier',
      onStart: (r) => setState(() =>_race = r));
    return _VerifierActiveWidget(
      raceName:_race!.name, live: _live,
      onBegin: () => setState(() =>_live = true),
      onStop: _leave, onLeave:_leave,
      onDelete: () => showConfirm(context, title: 'Delete Race?',
        message: 'Remove "${_race!.name}" from this race?',
        confirmLabel: 'Delete').then((v) { if (v == true)_leave(); }),
    );
  }
}

class _VerifierActiveWidget extends StatefulWidget {
  final String raceName;
  final bool live;
  final VoidCallback onBegin, onStop, onLeave;
  final VoidCallback onDelete;
  const_VerifierActiveWidget({required this.raceName, required this.live,
    required this.onBegin, required this.onStop, required this.onLeave,
    required this.onDelete});
  @override State<_VerifierActiveWidget> createState() =>_VerifierActiveWidgetState();
}

class _VerifierActiveWidgetState extends State<_VerifierActiveWidget> {
  List<VerifierEntry> _entries = [];
  List<VerifierEntry>_history = [];
  final Map<int, Timer> _undoTimers = {};
  int_nextId = 100;
  Timer? _streamTimer;
  final_connNotifier = ConnectionNotifier();

  @override void initState() {
    super.initState();
    if (widget.live) _initLive();
  }

  @override void didUpdateWidget(_VerifierActiveWidget old) {
    super.didUpdateWidget(old);
    if (widget.live && !old.live)_initLive();
  }

  void _initLive() {
    _entries = kDemoEntries;
    _connNotifier.startSimulation();
    _streamTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final sample = kDemoEntries[Random().nextInt(kDemoEntries.length)];
      setState(() =>_entries.add(VerifierEntry(
        id: _nextId++, pos:_entries.length + _history.length + 1,
        bib: sample.bib, flag: sample.flag)));
    });
  }

  @override void dispose() {
    _streamTimer?.cancel();
    for (final t in_undoTimers.values) t.cancel();
    _connNotifier.dispose();
    super.dispose();
  }

  void _act(int id, String action) {
    setState(() =>_entries.firstWhere((e) => e.id == id).status = action);
    _undoTimers[id] = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        final entry =_entries.where((e) => e.id == id).firstOrNull;
        if (entry != null) { _history.insert(0, entry);_entries.removeWhere((e) => e.id == id); }
      });
    });
  }

  void _undo(int id) {
    _undoTimers[id]?.cancel(); _undoTimers.remove(id);
    setState(() =>_entries.firstWhere((e) => e.id == id).status = 'pending');
  }

  int get _confirmed =>_history.where((e) => e.status == 'confirmed').length;
  int get _wrong     =>_history.where((e) => e.status == 'wrong').length;
  int get _skipped   =>_history.where((e) => e.status == 'skipped').length;
  int get _pending   =>_entries.where((e) => e.status == 'pending').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(child: Column(children: [
        // Header
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VERIFIER', style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: kLight, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(widget.raceName, style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
              ]),
              widget.live ? const LiveBadge() : const NotStartedBadge(),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              for (final row in [
                [kGreen, 'CORRECT', _confirmed],
                [kRed,   'WRONG',_wrong],
                [kSub,   'SKIPPED', _skipped],
                [kPrimary,'PENDING',_pending],
              ]) Expanded(child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: (row[0] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text('${row[2]}', style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800, color: row[0] as Color)),
                  Text('${row[1]}', style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: row[0] as Color,
                    letterSpacing: 0.3)),
                ]),
              )),
            ]),
            if (widget.live) ListenableBuilder(
              listenable: _connNotifier,
              builder: (_, __) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ConnectionBanner(role: 'verifier',
                  status: _connNotifier.status, queueCount:_connNotifier.queueCount)),
            ),
          ]),
        ),
        // Entries
        Expanded(child: !widget.live
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('👀', style: TextStyle(fontSize: 36)),
                SizedBox(height: 12),
                Text('Ready to verify', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
                SizedBox(height: 8),
                Text('Tap Start Race to begin receiving bib entries from the Recorder.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: kSub, height: 1.5)),
              ])))
          : _entries.isEmpty &&_history.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('👀', style: TextStyle(fontSize: 36)),
                SizedBox(height: 12),
                Text('Waiting for finishers', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: kSub)),
                SizedBox(height: 6),
                Text('Entries from Bib Recorder appear here',
                  style: TextStyle(fontSize: 13, color: kLight)),
              ]))
            : ListView(padding: const EdgeInsets.all(14), children: [
                ..._entries.map((entry) {
                  final runner = findRunner(entry.bib);
                  final isActed = entry.status != 'pending';
                  final actColor = entry.status == 'confirmed' ? kGreen
                    : entry.status == 'wrong' ? kRed : kSub;
                  final actLabel = entry.status == 'confirmed' ? 'Correct — done'
                    : entry.status == 'wrong' ? 'Wrong — sending to Fixer'
                    : 'Skipped — assumed correct';
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isActed ? actColor.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActed ? actColor.withOpacity(0.5)
                          : entry.flag == 'DUPLICATE' ? kRed.withOpacity(0.35)
                          : entry.flag == 'UNKNOWN'   ? kAmber.withOpacity(0.35)
                          : const Color(0xFFE8E8E8),
                        width: 2),
                    ),
                    child: Opacity(opacity: isActed ? 0.75 : 1, child: Column(children: [
                      if (entry.flag != null && !isActed) Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        decoration: BoxDecoration(
                          color: entry.flag == 'DUPLICATE'
                            ? kRed.withOpacity(0.1) : kAmber.withOpacity(0.12),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: Text(
                          entry.flag == 'DUPLICATE'
                            ? '⚠ DUPLICATE BIB — verify carefully' : 'UNKNOWN BIB',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: entry.flag == 'DUPLICATE' ? kRed : kAmber,
                            letterSpacing: 0.5)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(_ordinal(entry.pos), style: const TextStyle(
                              fontSize: 12, color: kSub, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text('#${entry.bib}', style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900, color: kText)),
                          ]),
                          const SizedBox(height: 6),
                          if (runner != null) Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${runner.first} ${runner.last}', style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800, color: kText,
                              letterSpacing: -0.5, height: 1.15)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: teamColor(runner.team), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(runner.team, style: const TextStyle(
                                fontSize: 13, color: kSub, fontWeight: FontWeight.w600)),
                            ]),
                          ]) else const Text('NOT IN ROSTER', style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800, color: kAmber)),
                          const SizedBox(height: 10),
                          if (!isActed) ...[
                            if (entry.flag == 'UNKNOWN')
                              _actionBtn('Got it', const Color(0xFFF5F5F5),
                                const Color(0xFF555555), () =>_act(entry.id, 'confirmed'))
                            else Row(children: [
                              Expanded(child: _actionBtn('Wrong', kRed.withOpacity(0.08),
                                kRed, () =>_act(entry.id, 'wrong'))),
                              const SizedBox(width: 8),
                              Expanded(child: _actionBtn('Skip', const Color(0xFFF5F5F5),
                                kSub, () =>_act(entry.id, 'skipped'))),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: _actionBtn('Correct',
                                kGreen.withOpacity(0.1), kGreen,
                                () =>_act(entry.id, 'confirmed'))),
                            ]),
                          ] else Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(actLabel, style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: actColor)),
                              GestureDetector(
                                onTap: () => _undo(entry.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: actColor.withOpacity(0.5))),
                                  child: Text('Undo', style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: actColor)))),
                            ]),
                        ]),
                      ),
                    ])),
                  );
                }),
              ]),
        ),
        BottomBar(
          live: widget.live, onBegin: widget.onBegin, onStop: widget.onStop,
          menuItems: [
            _MenuItem('Delete Race', danger: true, onPress: widget.onDelete),
            _MenuItem('Leave Race', onPress: widget.onLeave),
            _MenuItem('See Runners'),
          ],
        ),
      ])),
    );
  }

  Widget _actionBtn(String label, Color bg, Color color, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4))),
      child: Center(child: Text(label, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700, color: color)))));
}

// ══════════════════════════════════════════════════════════════════════════════
// FIXER
// ══════════════════════════════════════════════════════════════════════════════
class FixerScreen extends StatefulWidget {
  const FixerScreen({super.key});
  @override State<FixerScreen> createState() => _FixerScreenState();
}

class _FixerScreenState extends State<FixerScreen> {
  RaceModel?_race;
  bool _live = false;
  void_leave() => setState(() { _race = null;_live = false; });

  @override
  Widget build(BuildContext context) {
    if (_race == null) return RaceLobby(role: 'fixer',
      onStart: (r) => setState(() =>_race = r));
    return _FixerActiveWidget(
      raceName:_race!.name, live: _live,
      onBegin: () => setState(() =>_live = true),
      onStop: _leave, onLeave:_leave,
      onDelete: () => showConfirm(context, title: 'Delete Race?',
        message: 'Remove "${_race!.name}"?', confirmLabel: 'Delete')
        .then((v) { if (v == true)_leave(); }),
    );
  }
}

class _FixerActiveWidget extends StatefulWidget {
  final String raceName;
  final bool live;
  final VoidCallback onBegin, onStop, onLeave, onDelete;
  const_FixerActiveWidget({required this.raceName, required this.live,
    required this.onBegin, required this.onStop, required this.onLeave, required this.onDelete});
  @override State<_FixerActiveWidget> createState() =>_FixerActiveWidgetState();
}

class _FixerActiveWidgetState extends State<_FixerActiveWidget> {
  List<FixerEntry> _queue = [];
  List<FixerResolved>_resolved = [];
  final _connNotifier = ConnectionNotifier();

  @override void initState() { super.initState(); if (widget.live) _initLive(); }
  @override void didUpdateWidget(_FixerActiveWidget old) {
    super.didUpdateWidget(old);
    if (widget.live && !old.live) _initLive();
  }
  void_initLive() {
    _queue = List.from(kFixerQueue);
    _connNotifier.startSimulation();
    setState(() {});
  }
  @override void dispose() { _connNotifier.dispose(); super.dispose(); }

  void _resolveWith(FixerEntry entry, RunnerModel runner) {
    setState(() {
      _resolved.insert(0, FixerResolved(
        pos: entry.pos, resolvedBib: runner.bib, resolvedName: runner.name,
        corrected: runner.bib != entry.bib));
      _queue.removeWhere((e) => e.id == entry.id);
    });
  }

  void _resolveNew(FixerEntry entry, String name, int bib) {
    setState(() {
      _resolved.insert(0, FixerResolved(
        pos: entry.pos, resolvedBib: bib, resolvedName: name, isNew: true));
      _queue.removeWhere((e) => e.id == entry.id);
    });
  }

  void _showFixSheet(BuildContext context, FixerEntry entry) {
    showAppSheet(context, title: 'Fix ${_ordinal(entry.pos)} place', tall: true,
      child: _FixSheet(entry: entry,
        onResolveWith: (r) { Navigator.pop(context);_resolveWith(entry, r); },
        onResolveNew: (n, b) { Navigator.pop(context); _resolveNew(entry, n, b); },
        onLeave: () { Navigator.pop(context); },
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(child: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FIXER', style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: kLight, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(widget.raceName, style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
              ]),
              widget.live ? const LiveBadge() : const NotStartedBadge(),
            ]),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _queue.isNotEmpty ? kPrimary.withOpacity(0.08) : kGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:_queue.isNotEmpty ? kPrimary.withOpacity(0.25) : kGreen.withOpacity(0.25))),
              child: Text(
                _queue.isNotEmpty
                  ? '${_queue.length} entr${_queue.length == 1 ? "y" : "ies"} need attention'
                  : 'All entries resolved ✓',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: _queue.isNotEmpty ? kPrimary : kGreen))),
            if (widget.live) ListenableBuilder(
              listenable: _connNotifier,
              builder: (_, __) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ConnectionBanner(role: 'fixer',
                  status:_connNotifier.status, queueCount: _connNotifier.queueCount)),
            ),
          ]),
        ),
        Expanded(child: !widget.live
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🔧', style: TextStyle(fontSize: 36)),
                SizedBox(height: 12),
                Text('Ready to fix', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: kText)),
                SizedBox(height: 8),
                Text('Tap Start Race to begin receiving flagged entries from the Verifier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: kSub, height: 1.5)),
              ])))
          : ListView(padding: const EdgeInsets.all(14), children: [
              if (_queue.isNotEmpty) ...[
                const Text('NEEDS FIXING', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: kLight, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                ..._queue.map((entry) {
                  final runner = findRunner(entry.bib);
                  return GestureDetector(
                    onTap: () =>_showFixSheet(context, entry),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('#${entry.bib}', style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900, color: kText)),
                          const SizedBox(width: 10),
                          Text(_ordinal(entry.pos), style: const TextStyle(
                            fontSize: 12, color: kSub)),
                          const Spacer(),
                          const Text('›', style: TextStyle(fontSize: 18, color: kLight)),
                        ]),
                        const SizedBox(height: 4),
                        Text(entry.context, style: const TextStyle(fontSize: 12, color: kSub)),
                        if (runner != null) Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Recorded as: ${runner.name}',
                            style: const TextStyle(fontSize: 12, color: kLight))),
                      ]),
                    ),
                  );
                }),
              ],
              if (_resolved.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
                  child: Text('RESOLVED', style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: kLight, letterSpacing: 1.2))),
                ..._resolved.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5)),
                  child: Row(children: [
                    Container(width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: kGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
                      child: const Center(child: Text('✓',
                        style: TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 14)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.resolvedName, style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
                      Text(
                        '#${r.resolvedBib} · ${_ordinal(r.pos)}'
                        '${r.corrected ? ' · bib corrected' : ''}'
                        '${r.isNew ? ' · new runner' : ''}',
                        style: const TextStyle(fontSize: 12, color: kSub)),
                    ])),
                  ]),
                )),
              ],
              if (widget.live &&_queue.isEmpty && _resolved.isEmpty) const Center(
                child: Padding(padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(children: [
                    Text('🎯', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 12),
                    Text('No issues yet', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: kSub)),
                    SizedBox(height: 6),
                    Text('Flagged entries from Verifier appear here',
                      style: TextStyle(fontSize: 13, color: kLight)),
                  ]))),
            ]),
        ),
        BottomBar(
          live: widget.live, onBegin: widget.onBegin, onStop: widget.onStop,
          menuItems: [
            _MenuItem('Delete Race', danger: true, onPress: widget.onDelete),
            _MenuItem('Leave Race', onPress: widget.onLeave),
            _MenuItem('See Runners'),
          ],
        ),
      ])),
    );
  }
}

class _FixSheet extends StatefulWidget {
  final FixerEntry entry;
  final void Function(RunnerModel) onResolveWith;
  final void Function(String, int) onResolveNew;
  final VoidCallback onLeave;
  const_FixSheet({required this.entry, required this.onResolveWith,
    required this.onResolveNew, required this.onLeave});
  @override State<_FixSheet> createState() =>_FixSheetState();
}

class _FixSheetState extends State<_FixSheet> {
  String _query = '';
  bool_creating = false;
  String _newName = '';
  int?_newBib;
  String _newGrade = '';

  List<RunnerModel> get _results {
    if (_query.trim().isEmpty) return [];
    final lower = _query.toLowerCase();
    return kRoster.where((r) =>
      r.name.toLowerCase().contains(lower) ||
      r.last.toLowerCase().contains(lower) ||
      r.first.toLowerCase().contains(lower) ||
      '${r.bib}'.contains(_query)).take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_creating) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        onTap: () => setState(() =>_creating = false),
        child: const Text('← Back', style: TextStyle(
          color: kPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 16),
      _field('Name', 'Runner\'s full name', (v) => setState(() =>_newName = v)),
      _field('Bib #', 'e.g. ${widget.entry.bib}', (v) => setState(() =>_newBib = int.tryParse(v)),
        type: TextInputType.number),
      const Text('Grade', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
      const SizedBox(height: 8),
      Row(children: ['Fr','So','Jr','Sr'].map((g) => Expanded(child: Padding(
        padding: EdgeInsets.only(right: g != 'Sr' ? 8 : 0),
        child: GestureDetector(
          onTap: () => setState(() => _newGrade = g),
          child: AnimatedContainer(duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color:_newGrade == g ? kPrimary.withOpacity(0.1) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _newGrade == g ? kPrimary : const Color(0xFFE8E8E8), width: 2)),
            child: Center(child: Text(g, style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.w700,
              color:_newGrade == g ? kPrimary : const Color(0xFF555555))))),
        )))).toList()),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: (_newName.trim().isNotEmpty &&_newBib != null)
          ? () => widget.onResolveNew(_newName.trim(),_newBib!) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: (_newName.trim().isNotEmpty &&_newBib != null)
              ? const LinearGradient(colors: [kPrimary, Color(0xFFF07A50)]) : null,
            color: (_newName.trim().isNotEmpty &&_newBib != null) ? null : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text('Add Runner', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w700,
            color: (_newName.trim().isNotEmpty &&_newBib != null) ? Colors.white : kLight)))),
      ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#${widget.entry.bib}', style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w900, color: kText)),
          Text(widget.entry.context, style: const TextStyle(fontSize: 12, color: kSub)),
        ]),
      ),
      const SizedBox(height: 16),
      const Text('SEARCH BY NAME', style: TextStyle(fontSize: 11,
        fontWeight: FontWeight.w700, color: kLight, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      TextField(
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 16, color: kText),
        decoration: InputDecoration(
          hintText: 'e.g. Singh, Priya, Tom G…',
          hintStyle: const TextStyle(color: kLight),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        ),
      ),
      const SizedBox(height: 12),
      ..._results.map((r) => GestureDetector(
        onTap: () => widget.onResolveWith(r),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E8E8), width: 1.5)),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('#${r.bib}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kSub)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
              Row(children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: teamColor(r.team), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(r.team, style: const TextStyle(fontSize: 12, color: kSub)),
              ]),
            ])),
            if (r.bib != widget.entry.bib) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(99)),
              child: const Text('bib change', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary))),
            const SizedBox(width: 8),
            const Text('✓', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
        ),
      )),
      if (_query.isNotEmpty && _results.isEmpty) const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: Text('No matches', style: TextStyle(fontSize: 14, color: kSub)))),
      const Divider(height: 24, color: kBorder),
      GestureDetector(
        onTap: () => setState(() => _creating = true),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: kAmber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kAmber.withOpacity(0.4))),
          child: const Center(child: Text('Create new runner',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kAmber)))),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: widget.onLeave,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
          child: const Center(child: Text('Leave for coach',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kSub)))),
      ),
    ]);
  }

  Widget _field(String label, String hint, void Function(String) onChanged,
    {TextInputType type = TextInputType.text}) =>
    Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
      const SizedBox(height: 8),
      TextField(keyboardType: type, onChanged: onChanged,
        style: const TextStyle(fontSize: 16, color: kText),
        decoration: InputDecoration(hintText: hint,
          hintStyle: const TextStyle(color: kLight),
          filled: true, fillColor: const Color(0xFFF2F2F2),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none))),
    ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// APP
// ══════════════════════════════════════════════════════════════════════════════
void main() => runApp(const FinishLineApp());

class FinishLineApp extends StatelessWidget {
  const FinishLineApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'XCeleration Finish Line',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'SF Pro Display',
      useMaterial3: true,
    ),
    home: const _RoleShell(),
  );
}

class _RoleShell extends StatefulWidget {
  const_RoleShell();
  @override State<_RoleShell> createState() =>_RoleShellState();
}

class _RoleShellState extends State<_RoleShell> {
  int _role = 0;
  final_roles = const [
    ('bib',      '1 · Bib Recorder'),
    ('verifier', '2 · Verifier'),
    ('fixer',    '3 · Fixer'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: _roles.asMap().entries.map((e) {
              final i = e.key; final label = e.value.$2;
              return GestureDetector(
                onTap: () => setState(() =>_role = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _role == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow:_role == i ? [
                      BoxShadow(color: Colors.black.withOpacity(0.15),
                        blurRadius: 4, offset: const Offset(0, 1))] : [],
                  ),
                  child: Text(label, style: TextStyle(
                    fontSize: 13, fontWeight: _role == i ? FontWeight.w700 : FontWeight.w500,
                    color:_role == i ? kText : Colors.white.withOpacity(0.6))),
                ),
              );
            }).toList()),
          ),
        ),
        Expanded(child: IndexedStack(index: _role, children: const [
          BibRecorderScreen(),
          VerifierScreen(),
          FixerScreen(),
        ])),
      ])),
    );
  }
}
