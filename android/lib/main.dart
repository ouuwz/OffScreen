import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = Color(0xFF9BE564);
const _bg = Color(0xFF101411);
const _panel = Color(0xFF1A211C);
const _muted = Color(0xFFA9B4AA);
const _cream = Color(0xFFF1F3E9);

void main() => runApp(const OffscreenApp());

class OffscreenApp extends StatelessWidget {
  const OffscreenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Offscreen',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _bg,
          colorScheme: ColorScheme.fromSeed(seedColor: _green, brightness: Brightness.dark, primary: _green, surface: _panel),
          useMaterial3: true,
          visualDensity: VisualDensity.standard,
          appBarTheme: const AppBarTheme(backgroundColor: _bg, surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF151B16),
            indicatorColor: _green.withValues(alpha: .18),
            labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontSize: 12, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
            height: 70,
          ),
          snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF26352A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          cardTheme: const CardThemeData(color: _panel, margin: EdgeInsets.zero),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _panel,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: .08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _green, width: 1.4)),
          ),
        ),
        home: const HomeScreen(),
      );
}

class JournalEntry {
  JournalEntry({required this.savedAt, required this.place, required this.minutes, required this.focus, required this.mission, required this.observation, required this.completed, this.elapsedMinutes = 0, this.completedAt});
  final DateTime savedAt;
  final String place;
  final int minutes;
  final String focus;
  final String mission;
  final String observation;
  final bool completed;
  final double elapsedMinutes;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() => {
        'saved_at': savedAt.toIso8601String(), 'place': place, 'minutes': minutes,
        'focus': focus, 'mission': mission, 'observation': observation,
        'break_completed': completed, 'elapsed_minutes': elapsedMinutes,
        'break_completed_at': completedAt?.toIso8601String(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        savedAt: DateTime.tryParse('${j['saved_at'] ?? ''}')?.toLocal() ?? DateTime.now(),
        place: '${j['place'] ?? 'Outdoor'}',
        minutes: int.tryParse('${j['minutes'] ?? 10}') ?? 10,
        focus: '${j['focus'] ?? 'A mix of everything'}',
        mission: '${j['mission'] ?? ''}',
        observation: '${j['observation'] ?? ''}',
        completed: j['break_completed'] == true,
        elapsedMinutes: double.tryParse('${j['elapsed_minutes'] ?? 0}') ?? 0,
        completedAt: DateTime.tryParse('${j['break_completed_at'] ?? ''}')?.toLocal(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  String _place = 'Park or garden';
  String _company = 'By myself';
  int _minutes = 10;
  String _energy = 'Okay — a little walking';
  String _focus = 'A mix of everything';
  String _mission = '';
  String _missionSource = 'Built-in mission';
  bool _busy = false;
  String _status = 'Choose a model to enable on-device AI.';
  String? _modelPath;
  LlamaController? _controller;
  final _observation = TextEditingController();
  List<JournalEntry> _entries = [];
  DateTime? _breakStarted;
  DateTime? _breakCompleted;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _modelLoaded = false;

  final _places = const ['College campus', 'Park or garden', 'My neighbourhood', 'Balcony or outdoor area'];
  final _companies = const ['By myself', 'With a friend', 'With family'];
  final _energies = const ['Low — keep it gentle', 'Okay — a little walking', 'High — I want to explore'];
  final _focuses = const ['Plants and leaves', 'Birds and natural sounds', 'Clouds and the sky', 'Small details I usually miss', 'A mix of everything'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocalData();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _observation.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() => _now = DateTime.now());
  }

  Future<File> get _journalFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nature_journal.json');
  }

  Future<void> _loadLocalData() async {
    try {
      final f = await _journalFile;
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is List) _entries = raw.whereType<Map>().map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString('model_path');
      if (savedModel != null && await File(savedModel).exists()) _modelPath = savedModel;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not read local journal: $e');
    }
  }

  Future<void> _persistJournal() async {
    final f = await _journalFile;
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(_entries.map((e) => e.toJson()).toList()));
  }

  Future<void> _chooseModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gguf'], withData: false);
      if (result == null || result.files.single.path == null) return;
      final source = File(result.files.single.path!);
      final support = await getApplicationSupportDirectory();
      final modelDir = Directory('${support.path}/models');
      await modelDir.create(recursive: true);
      final target = File('${modelDir.path}/${result.files.single.name}');
      if (source.path != target.path) await source.copy(target.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('model_path', target.path);
      if (!mounted) return;
      setState(() { _modelPath = target.path; _modelLoaded = false; _status = 'Model copied to app storage. Tap Load model.'; });
    } catch (e) {
      _snack('Could not select model: $e');
    }
  }

  Future<void> _loadModel() async {
    if (_modelPath == null || !await File(_modelPath!).exists()) {
      _snack('Choose a .gguf model file first.');
      return;
    }
    setState(() { _busy = true; _status = 'Loading model. This can take a little while on a phone…'; });
    try {
      await _controller?.dispose();
      final controller = LlamaController();
      await controller.loadModel(modelPath: _modelPath!, threads: 2, contextSize: 1024);
      _controller = controller;
      if (mounted) setState(() { _modelLoaded = true; _status = 'Local AI ready. Airplane mode is fine after model setup.'; });
    } catch (e) {
      if (mounted) setState(() { _modelLoaded = false; _status = 'Model could not load: $e'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fallbackIdea() {
    switch (_focus) {
      case 'Plants and leaves': return 'Notice how leaf edges, colours, and shadows differ from plant to plant.';
      case 'Birds and natural sounds': return 'Stand still and listen for layers of sound without approaching any animal.';
      case 'Clouds and the sky': return 'Notice cloud shapes, gaps of blue, and how sunlight changes their edges.';
      case 'Small details I usually miss': return 'Look for an overlooked pattern, shadow, texture, or tiny change in colour.';
      default: return 'Notice one sound, one shape, and one small detail you usually walk past.';
    }
  }

  Future<String> _generateIdea() async {
    if (!_modelLoaded || _controller == null) return _fallbackIdea();
    final prompt = '''You suggest safe, short outdoor observation ideas. Return ONE sentence with 8-14 ordinary words. No title, list, markdown, preamble, species identification, or advice to touch, eat, collect, approach, chase, feed, or disturb wildlife.\nPlace: $_place\nTime: $_minutes minutes\nEnergy: $_energy\nCompany: $_company\nInterest: $_focus\nOne sentence only:''';
    final buffer = StringBuffer();
    await for (final token in _controller!.generateChat(messages: [
      ChatMessage(role: 'system', content: 'You suggest safe, short outdoor observation ideas. Return exactly one ordinary sentence of 8-14 words. Never suggest touching, eating, collecting, approaching, chasing, feeding, or disturbing wildlife.'),
      ChatMessage(role: 'user', content: prompt),
    ], template: 'chatml', maxTokens: 48, temperature: 0.3)) {
      buffer.write(token);
    }
    var idea = buffer.toString().trim().split('\n').first.replaceAll(RegExp(r'^[\s\-*\d.)"`]+'), '').replaceAll(RegExp(r'\s+'), ' ');
    if (idea.length > 160 || idea.split(' ').length > 22 || RegExp(r'\b(eat|taste|collect|pluck|pick|touch|handle|feed|chase|capture|approach|disturb|climb|cumin)\b', caseSensitive: false).hasMatch(idea)) return _fallbackIdea();
    if (idea.isEmpty) return _fallbackIdea();
    return '${idea.replaceAll(RegExp(r'[.\s]+$'), '')}.';
  }

  String _missionTitle() {
    switch (_focus) {
      case 'Plants and leaves': return 'A Closer Look at Leaves';
      case 'Birds and natural sounds': return 'A Listening Walk';
      case 'Clouds and the sky': return 'Clouds and the Sky';
      case 'Small details I usually miss': return 'The Notice-Three Mission';
      default: return 'A Little Bit of Everything';
    }
  }

  Future<void> _makeMission() async {
    setState(() { _busy = true; _mission = ''; _breakStarted = null; _breakCompleted = null; _observation.clear(); });
    try {
      final idea = await _generateIdea();
      final observationMins = (_minutes ~/ 3).clamp(2, 5);
      final share = _company == 'By myself' ? 'When you finish, remember the detail you found most interesting. No photo needed.' : 'When you finish, each of you can share one detail the other person missed.';
      _mission = '''${_missionTitle()}\n\n$_minutes minutes · $_place · $_energy\n\n1. Find a safe spot. Stay in a familiar public area or on a marked path, and watch for traffic.\n\n2. Your AI idea: $idea\n\n3. Slow down for $observationMins minutes. Notice another sound, shape, or colour. Do not touch or disturb plants or animals.\n\n4. Put your phone away. $share\n\nReflection: What did you notice that you might normally walk past?''';
      _missionSource = _modelLoaded ? 'Generated on this device with your selected open-weight model' : 'Built-in offline suggestion (local model not loaded)';
      if (mounted) setState(() {});
    } catch (e) {
      _mission = 'The local model had trouble generating an idea. Try again or use the built-in offline suggestion:\n\n${_fallbackIdea()}';
      _missionSource = 'Local model error with safe fallback';
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startBreak() {
    setState(() { _breakStarted = DateTime.now(); _breakCompleted = null; });
  }

  void _completeBreak() {
    setState(() => _breakCompleted = DateTime.now());
    _snack('Break marked complete. What did you notice?');
  }

  Future<void> _saveObservation() async {
    final text = _observation.text.trim();
    if (text.isEmpty) { _snack('Write one thing you noticed first.'); return; }
    final elapsed = (_breakStarted != null && _breakCompleted != null)
        ? _breakCompleted!.difference(_breakStarted!).inSeconds / 60.0 : 0.0;
    final entry = JournalEntry(
      savedAt: DateTime.now(), place: _place, minutes: _minutes, focus: _focus,
      mission: _mission, observation: text, completed: _breakCompleted != null,
      elapsedMinutes: elapsed, completedAt: _breakCompleted,
    );
    setState(() => _entries.add(entry));
    try {
      await _persistJournal();
      _observation.clear();
      setState(() { _breakStarted = null; _breakCompleted = null; _tab = 1; });
      _snack('Saved on this device. No account needed.');
    } catch (e) {
      setState(() => _entries.remove(entry));
      _snack('Could not save entry: $e');
    }
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    setState(() => _entries.remove(entry));
    try { await _persistJournal(); } catch (e) { _snack('Could not update journal: $e'); }
  }

  Future<void> _exportJournal() async {
    try {
      final f = await _journalFile;
      if (!await f.exists()) await _persistJournal();
      await Share.shareXFiles([XFile(f.path, mimeType: 'application/json')], text: 'My Offscreen nature journal');
    } catch (e) { _snack('Export failed: $e'); }
  }

  Future<void> _importJournal() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null) return;
      final bytes = result.files.single.bytes;
      final path = result.files.single.path;
      final rawText = bytes != null ? utf8.decode(bytes) : (path != null ? await File(path).readAsString() : null);
      if (rawText == null) { _snack('Could not read that JSON file.'); return; }
      final decoded = jsonDecode(rawText);
      if (decoded is! List) { _snack('This file is not a Offscreen journal list.'); return; }
      final imported = decoded.whereType<Map>().map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e))).toList();
      final existingKeys = _entries.map((e) => '${e.savedAt.toIso8601String()}|${e.observation}').toSet();
      final fresh = imported.where((e) => !existingKeys.contains('${e.savedAt.toIso8601String()}|${e.observation}')).toList();
      setState(() => _entries.addAll(fresh));
      await _persistJournal();
      _snack('Imported ${fresh.length} new journal entr${fresh.length == 1 ? 'y' : 'ies'}.');
    } catch (e) { _snack('Import failed. Choose a valid nature_journal.json file. ($e)'); }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  String _friendlyDate(DateTime value) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h24 = value.hour;
    final h = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = value.minute.toString().padLeft(2, '0');
    return '${value.day} ${months[value.month - 1]} ${value.year}, $h:$mm ${h24 >= 12 ? 'PM' : 'AM'}';
  }

  List<JournalEntry> get _completed => _entries.where((e) => e.completed).toList();
  double get _totalMinutes => _completed.fold(0, (sum, e) => sum + e.elapsedMinutes);
  int get _streak {
    final days = _completed.map((e) => (e.completedAt ?? e.savedAt).toLocal()).map((d) => DateTime(d.year, d.month, d.day)).toSet();
    var day = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(day)) { count++; day = day.subtract(const Duration(days: 1)); }
    return count;
  }
  List<double> get _weeklyMinutes {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return _completed.where((e) { final d = (e.completedAt ?? e.savedAt).toLocal(); return d.year == day.year && d.month == day.month && d.day == day.day; }).fold<double>(0, (sum, e) => sum + e.elapsedMinutes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_buildMissionTab(), _buildJournalTab(), _buildProgressTab(), _buildSettingsTab()];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Row(children: [
          DecoratedBox(decoration: BoxDecoration(color: Color(0xFF233528), borderRadius: BorderRadius.all(Radius.circular(12))), child: Padding(padding: EdgeInsets.all(7), child: Icon(Icons.eco_rounded, color: _green, size: 22))),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Offscreen', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -.4)),
            Text('A LITTLE MORE OUTSIDE', style: TextStyle(fontSize: 9, color: _muted, letterSpacing: 1.15, fontWeight: FontWeight.w700)),
          ]),
        ]),
        actions: [IconButton(tooltip: 'Export journal', onPressed: _entries.isEmpty ? null : _exportJournal, icon: const Icon(Icons.ios_share_rounded))],
      ),
      body: SafeArea(child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        reverseDuration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(.025, 0), end: Offset.zero).animate(animation), child: child)),
        child: KeyedSubtree(key: ValueKey<int>(_tab), child: pages[_tab]),
      )),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.eco_outlined), selectedIcon: Icon(Icons.eco), label: 'Mission'),
        NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Journal'),
        NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
      ]),
    );
  }

  Widget _page(Widget child) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), child: child);
  Widget _card(Widget child) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .07))), child: child);
  Widget _sectionTitle(String title, [String? subtitle]) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)), if (subtitle != null) ...[const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: _muted))]]));

  Widget _heroCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF263E2C), Color(0xFF18251B), Color(0xFF1A211C)]),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _green.withValues(alpha: .16)),
    ),
    child: Stack(children: [
      Positioned(right: -12, top: -20, child: Icon(Icons.eco_rounded, size: 118, color: _green.withValues(alpha: .07))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _green.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_modelLoaded ? Icons.check_circle_rounded : Icons.offline_bolt_rounded, size: 14, color: _green), const SizedBox(width: 6), Text(_modelLoaded ? 'ON-DEVICE AI READY' : 'OFFLINE MODE AVAILABLE', style: const TextStyle(fontSize: 10, letterSpacing: .7, color: _green, fontWeight: FontWeight.w800))])),
        const SizedBox(height: 18),
        const Text('A little less scrolling.\nA little more noticing.', style: TextStyle(fontSize: 27, height: 1.13, fontWeight: FontWeight.w900, letterSpacing: -.8, color: _cream)),
        const SizedBox(height: 10),
        const Text('Get one small mission, then let the world have your attention.', style: TextStyle(color: Color(0xFFC5D0C5), height: 1.45, fontSize: 14)),
        const SizedBox(height: 18),
        Row(children: [
          _heroFact(Icons.timer_outlined, '10–30 min'), const SizedBox(width: 14),
          _heroFact(Icons.phonelink_erase_rounded, 'Phone down'), const SizedBox(width: 14),
          _heroFact(Icons.lock_outline_rounded, 'Private'),
        ]),
      ]),
    ]),
  );

  Widget _heroFact(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: _green), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, color: _cream, fontWeight: FontWeight.w600))]);

  Widget _focusChip(String label, String value, IconData icon) {
    final selected = _focus == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(icon, size: 16, color: selected ? _green : _muted),
        label: Text(label),
        onSelected: (_) => setState(() => _focus = value),
        backgroundColor: _panel,
        selectedColor: _green.withValues(alpha: .13),
        side: BorderSide(color: selected ? _green.withValues(alpha: .55) : Colors.white.withValues(alpha: .08)),
        labelStyle: TextStyle(color: selected ? _cream : _muted, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildMissionTab() => _page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _heroCard(),
    const SizedBox(height: 22), _sectionTitle('Plan your break', 'A few choices. One reason to put your phone away.'),
    Wrap(spacing: 8, runSpacing: 8, children: [
      _focusChip('Leaves', 'Plants and leaves', Icons.spa_outlined),
      _focusChip('Bird sounds', 'Birds and natural sounds', Icons.graphic_eq_rounded),
      _focusChip('Sky', 'Clouds and the sky', Icons.cloud_outlined),
      _focusChip('Little details', 'Small details I usually miss', Icons.search_rounded),
    ]),
    const SizedBox(height: 12),
    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dropdown('Where are you going?', _place, _places, (v) => setState(() => _place = v)), const SizedBox(height: 12),
      _dropdown('Going', _company, _companies, (v) => setState(() => _company = v)), const SizedBox(height: 12),
      _dropdown('How much time do you have?', '$_minutes minutes', ['10 minutes','20 minutes','30 minutes'], (v) => setState(() => _minutes = int.parse(v.split(' ').first))), const SizedBox(height: 12),
      _dropdown('Your energy today', _energy, _energies, (v) => setState(() => _energy = v)), const SizedBox(height: 12),
      _dropdown('What sounds interesting?', _focus, _focuses, (v) => setState(() => _focus = v)), const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _makeMission, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.spa), label: Text(_busy ? 'Making your mission…' : 'Give me a mission'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)))),
    ])),
    if (_mission.isNotEmpty) ...[const SizedBox(height: 18), _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_missionTitle(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text('$_minutes minutes · $_place', style: const TextStyle(color: _muted)), const Divider(height: 24), ..._mission.split('\n\n').skip(2).map((line) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(line, style: const TextStyle(height: 1.45)))), Text(_missionSource, style: const TextStyle(fontSize: 11, color: _muted)), const SizedBox(height: 10),
      if (_breakStarted == null && _breakCompleted == null) SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _startBreak, icon: const Icon(Icons.phone_android), label: const Text('Start phone-down break'))),
      if (_breakStarted != null && _breakCompleted == null) ...[const SizedBox(height: 12), Center(child: Column(children: [
        SizedBox(width: 176, height: 176, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: (_now.difference(_breakStarted!).inSeconds / (_minutes * 60)).clamp(0.0, 1.0), strokeWidth: 5, strokeCap: StrokeCap.round, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation<Color>(_green))),
          Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.phonelink_erase_rounded, color: _green, size: 22), const SizedBox(height: 6), Text(_timerText, style: const TextStyle(fontSize: 39, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()])), const Text('PHONE DOWN', style: TextStyle(color: _muted, letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.w800))]),
        ])),
        const SizedBox(height: 14), Text(_now.difference(_breakStarted!).inSeconds >= _minutes * 60 ? 'Time is up. Finish safely.' : 'Leave this screen open, then put your phone away.', style: const TextStyle(color: _muted, fontSize: 12), textAlign: TextAlign.center),
      ])), const SizedBox(height: 14), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _completeBreak, icon: const Icon(Icons.check_circle_outline_rounded), label: const Text("I'm back from my break")))],
      if (_breakCompleted != null) ...[const SizedBox(height: 10), const Text('Break marked complete. What did you notice?', style: TextStyle(color: _green)), const SizedBox(height: 10), TextField(controller: _observation, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'One thing I noticed', hintText: 'A sound, a leaf pattern, the sky…')), const SizedBox(height: 10), SizedBox(width: double.infinity, child: FilledButton(onPressed: _saveObservation, child: const Text('Save to my nature journal')))],
    ]))],
  ]));

  String get _timerText {
    if (_breakStarted == null) return '00:00';
    final left = (_minutes * 60 - _now.difference(_breakStarted!).inSeconds).clamp(0, _minutes * 60);
    return '${(left ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}';
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: _muted)), const SizedBox(height: 6), DropdownButtonFormField<String>(initialValue: value, isExpanded: true, decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4)), items: options.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) onChanged(v); })]);

  Widget _buildJournalTab() => _page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle('Your nature journal', 'Little things you noticed, saved on this phone.'),
    if (_entries.isEmpty) _card(const Column(children: [Icon(Icons.menu_book, size: 42, color: _muted), SizedBox(height: 10), Text('No observations yet'), SizedBox(height: 5), Text('Complete a break and save one thing you noticed.', textAlign: TextAlign.center, style: TextStyle(color: _muted))]))
    else ..._entries.reversed.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Dismissible(key: ValueKey('${e.savedAt.toIso8601String()}-${e.observation}'), direction: DismissDirection.endToStart, background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 18), decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.delete_outline)), onDismissed: (_) => _deleteEntry(e), child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${_friendlyDate(e.savedAt)} · ${e.place}', style: const TextStyle(color: _green, fontWeight: FontWeight.w700)), const SizedBox(height: 10), Text(e.observation, style: const TextStyle(fontSize: 16)), const SizedBox(height: 8), Text(e.completed ? 'Break completed · ${e.elapsedMinutes.toStringAsFixed(1)} minutes' : 'Observation saved · break completion not recorded', style: const TextStyle(color: _muted, fontSize: 12)), const SizedBox(height: 8), ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('View mission'), children: [Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(e.mission)))])])))))
  ]));

  Widget _buildProgressTab() {
    final week = _weeklyMinutes;
    final maxValue = week.fold<double>(1, (m, v) => v > m ? v : m);
    final dayNames = ['M','T','W','T','F','S','S'];
    return _page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Your progress', 'Every completed break is a little win.'),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6, children: [
        _stat('Journal entries', '${_entries.length}', Icons.book_outlined), _stat('Breaks completed', '${_completed.length}', Icons.check_circle_outline), _stat('Minutes outside', '${_totalMinutes.round()}', Icons.timer_outlined), _stat('Day streak', '$_streak', Icons.local_fire_department_outlined),
      ]),
      const SizedBox(height: 16),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Last 7 days', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final day = DateTime.now().subtract(Duration(days: 6 - i));
              final barHeight = (week[i] / maxValue * 115).clamp(4.0, 115.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(week[i] == 0 ? '' : week[i].toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: _muted)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      height: barHeight,
                      decoration: BoxDecoration(color: week[i] > 0 ? _green : Colors.white12, borderRadius: BorderRadius.circular(7)),
                    ),
                    const SizedBox(height: 8),
                    Text(dayNames[day.weekday - 1], style: const TextStyle(fontSize: 11, color: _muted)),
                  ]),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text('${week.fold<double>(0, (a, b) => a + b).round()} minutes recorded this week', style: const TextStyle(color: _muted, fontSize: 12)),
      ])),
      const SizedBox(height: 12), _card(const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lock_outline, color: _green), SizedBox(width: 10), Expanded(child: Text('Progress is calculated from breaks you marked complete and observations you saved. The app does not use GPS or track your location.'))])),
    ]));
  }

  Widget _stat(String label, String value, IconData icon) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: .07))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: _green, size: 20), Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(fontSize: 12, color: _muted))]));

  Widget _buildSettingsTab() => _page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle('Settings', 'Your model, your journal, your device.'),
    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('On-device AI model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Choose a GGUF model file stored on your phone. For a low-memory phone, start with a small Q4 quantized model. Model download is separate from the APK.', style: TextStyle(color: _muted, height: 1.45)), const SizedBox(height: 12), Text(_modelPath == null ? 'No model selected' : 'Selected: ${_modelPath!.split('/').last}', style: const TextStyle(fontSize: 12)), const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _chooseModel, icon: const Icon(Icons.folder_open), label: const Text('Choose .gguf model'))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy || _modelPath == null ? null : _loadModel, icon: const Icon(Icons.memory), label: Text(_busy ? 'Please wait…' : _modelLoaded ? 'Reload local model' : 'Load model'))), const SizedBox(height: 12), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)), child: Text(_status, style: const TextStyle(color: _muted, fontSize: 12))), if (_modelLoaded) TextButton.icon(onPressed: () async { await _controller?.dispose(); setState(() { _controller = null; _modelLoaded = false; _status = 'Model unloaded to free memory.'; }); }, icon: const Icon(Icons.memory_outlined), label: const Text('Unload model and free memory'))])),
    const SizedBox(height: 12), _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Data and privacy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Journal: private app storage on this phone.\nAI: inference happens on this phone after the model is installed.\nNetwork: the app does not request internet permission.\nLocation: no GPS access.', style: TextStyle(color: _muted, height: 1.6)), const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _entries.isEmpty ? null : _exportJournal, icon: const Icon(Icons.ios_share), label: const Text('Export journal JSON'))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _importJournal, icon: const Icon(Icons.file_open), label: const Text('Import existing journal JSON')))])),
    const SizedBox(height: 12), _card(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('About Offscreen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 8), Text('A student-built open-weight AI experiment that turns a short prompt into a safe outdoor activity. Python used to format missions in the desktop prototype; this Android version uses Flutter and llama.cpp to run GGUF models on-device.', style: TextStyle(color: _muted, height: 1.5)), SizedBox(height: 8), Text('Safety: use familiar public areas, watch traffic, and do not touch, eat, collect, or disturb unknown plants or wildlife.', style: TextStyle(height: 1.5)), SizedBox(height: 12), Text('Created by @ouuwz', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 4), SelectableText('GitHub: github.com/ouuwz\nTelegram: t.me/ouuwz', style: TextStyle(color: _green, height: 1.5))])),
  ]));
}
