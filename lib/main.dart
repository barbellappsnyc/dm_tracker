import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(const DMTrackerApp());
}

class DMTrackerApp extends StatelessWidget {
  const DMTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cold DM Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'SF Pro',
        fontFamilyFallback: const [
          '.AppleSystemUIFont',
          'SF Pro Text',
          'SF Pro Display',
          'Helvetica Neue',
          'sans-serif',
        ],
        scaffoldBackgroundColor: const Color(
          0xFFFDF7E3,
        ), // Classic iOS Notes Yellow
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8C8C8C),
          secondary: Color(0xFF5C5C5C),
          surface: Color(0xFFFDF7E3),
        ),
        cardTheme: CardThemeData(
          color: const Color(
            0xFFFFFBEA,
          ), // Slightly lighter yellow for note cards
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFFE2D9B3),
              width: 1,
            ), // Subtle notepad line
          ),
          elevation: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.65),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4C894)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4C894)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
          bodyLarge: TextStyle(color: Colors.black87),
        ),
      ),
      home: const TrackerHome(),
    );
  }
}

class OpenerItem {
  String id;
  String text;
  int timesUsed;
  int timesOpened;

  OpenerItem({
    required this.id,
    required this.text,
    this.timesUsed = 0,
    this.timesOpened = 0,
  });

  double get successRate =>
      timesUsed == 0 ? 0.0 : (timesOpened / timesUsed) * 100;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'timesUsed': timesUsed,
    'timesOpened': timesOpened,
  };

  factory OpenerItem.fromJson(Map<String, dynamic> json) => OpenerItem(
    id: json['id'],
    text: json['text'] ?? '',
    timesUsed: json['timesUsed'] ?? 0,
    timesOpened: json['timesOpened'] ?? 0,
  );
}

class ProfileItem {
  String id;
  String username;
  String lastDmDate;
  String? openerId;
  bool isOpened;
  String notes;

  ProfileItem({
    required this.id,
    this.username = '',
    required this.lastDmDate,
    this.openerId,
    this.isOpened = false,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'lastDmDate': lastDmDate,
    'openerId': openerId,
    'isOpened': isOpened,
    'notes': notes,
  };

  factory ProfileItem.fromJson(Map<String, dynamic> json) => ProfileItem(
    id: json['id'],
    username: json['username'] ?? '',
    lastDmDate: json['lastDmDate'] ?? '',
    openerId: json['openerId'],
    isOpened: json['isOpened'] ?? false,
    notes: json['notes'] ?? '',
  );
}

class TrackerHome extends StatefulWidget {
  const TrackerHome({super.key});

  @override
  State<TrackerHome> createState() => _TrackerHomeState();
}

class _TrackerHomeState extends State<TrackerHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OpenerItem> openers = [];
  List<ProfileItem> profiles = [];
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  File get _storageFile {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return File('$home/.dm_tracker_data.json');
  }

  Future<void> _loadData() async {
    try {
      final file = _storageFile;
      if (await file.exists()) {
        final raw = await file.readAsString();
        final data = jsonDecode(raw);
        setState(() {
          openers = (data['openers'] as List? ?? [])
              .map((e) => OpenerItem.fromJson(e))
              .toList();
          profiles = (data['profiles'] as List? ?? [])
              .map((e) => ProfileItem.fromJson(e))
              .toList();
          _isLoaded = true;
        });
      } else {
        setState(() => _isLoaded = true);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoaded = true);
    }
  }

  Future<void> _saveData() async {
    try {
      final data = jsonEncode({
        'openers': openers.map((e) => e.toJson()).toList(),
        'profiles': profiles.map((e) => e.toJson()).toList(),
      });
      await _storageFile.writeAsString(data);
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  void _openUrl(String url) {
    Process.run('open', [url]);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // --- OPENER LOGIC ---
  void _addEmptyOpener() {
    setState(() {
      openers.insert(
        0,
        OpenerItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: '',
        ),
      );
    });
    _saveData();
  }

  Future<OpenerItem?> _promptCreateOpenerDialog() async {
    final controller = TextEditingController();
    try {
      return await showDialog<OpenerItem>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFFFBEA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2D9B3)),
          ),
          title: const Text(
            'Create New Opener',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(hintText: 'Enter opener line...'),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                final newOpener = OpenerItem(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  text: val.trim(),
                );
                Navigator.of(context).pop(newOpener);
              }
            },
          ),
          actions: [
            Thick3DButton(
              depth: 3.0,
              borderRadius: 10.0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFFFFDF5),
              shadowColor: const Color(0xFFC7B988),
              borderColor: const Color(0xFFD4C894),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Thick3DButton(
              depth: 3.5,
              borderRadius: 10.0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF2E2E34),
              shadowColor: const Color(0xFF141416),
              borderColor: const Color(0xFF4B4B55),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  final newOpener = OpenerItem(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    text: controller.text.trim(),
                  );
                  Navigator.of(context).pop(newOpener);
                }
              },
              child: const Text(
                'Create & Link',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _deleteOpener(OpenerItem item) {
    setState(() {
      for (var p in profiles) {
        if (p.openerId == item.id) {
          p.openerId = null;
        }
      }
      openers.removeWhere((o) => o.id == item.id);
    });
    _saveData();
  }

  // --- PROFILE & CROSS-TAB SYNC LOGIC ---
  void _addEmptyProfile() {
    setState(() {
      profiles.insert(
        0,
        ProfileItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          lastDmDate: _todayString(),
        ),
      );
    });
    _saveData();
  }

  void _linkOpenerToProfile(ProfileItem profile, String? newOpenerId) async {
    if (newOpenerId == '__CREATE_NEW__') {
      final created = await _promptCreateOpenerDialog();
      if (created == null) {
        setState(() {});
        return;
      }
      setState(() {
        openers.insert(0, created);
      });
      newOpenerId = created.id;
    }

    if (profile.openerId == newOpenerId) return;

    setState(() {
      // 1. Revert stats on previously linked opener if any
      if (profile.openerId != null) {
        final oldOpener = openers
            .where((o) => o.id == profile.openerId)
            .firstOrNull;
        if (oldOpener != null) {
          if (oldOpener.timesUsed > 0) oldOpener.timesUsed--;
          if (profile.isOpened && oldOpener.timesOpened > 0) {
            oldOpener.timesOpened--;
          }
        }
      }

      // 2. Assign new opener and bump its stats
      profile.openerId = newOpenerId;
      if (newOpenerId != null) {
        final newOpener = openers.where((o) => o.id == newOpenerId).firstOrNull;
        if (newOpener != null) {
          newOpener.timesUsed++;
          if (profile.isOpened) {
            newOpener.timesOpened++;
          }
        }
      }
    });
    _saveData();
  }

  void _toggleProfileOpened(ProfileItem profile, bool? val) {
    final newStatus = val ?? false;
    if (profile.isOpened == newStatus) return;

    setState(() {
      profile.isOpened = newStatus;
      if (profile.openerId != null) {
        final linked = openers
            .where((o) => o.id == profile.openerId)
            .firstOrNull;
        if (linked != null) {
          if (newStatus) {
            linked.timesOpened++;
          } else if (linked.timesOpened > 0) {
            linked.timesOpened--;
          }
        }
      }
    });
    _saveData();
  }

  void _deleteProfile(ProfileItem profile) {
    setState(() {
      profiles.removeWhere((p) => p.id == profile.id);
    });
    _saveData();
  }

  Future<void> _pickDate(ProfileItem profile) async {
    DateTime initial = DateTime.tryParse(profile.lastDmDate) ?? DateTime.now();
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2035);
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        profile.lastDmDate =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(
          0xFFF6EAA0,
        ), // Darker yellow leather/header vibe
        elevation: 1,
        title: const Text(
          'Cold DM Tracker',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF4B4B55),
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'Openers (${openers.length})'),
            Tab(text: 'Profiles (${profiles.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOpenersTab(), _buildProfilesTab()],
      ),
      floatingActionButton: Retro3DButton(
        onPressed: _tabController.index == 0
            ? _addEmptyOpener
            : _addEmptyProfile,
        child: const Icon(Icons.add, size: 22, color: Colors.black87),
      ),
    );
  }

  // --- TAB 1: OPENERS ---
  Widget _buildOpenersTab() {
    if (openers.isEmpty) {
      return const Center(
        child: Text(
          'No openers yet. Click + to add your first template.',
          style: TextStyle(fontFamily: 'SF Pro', color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: openers.length,
      itemBuilder: (context, index) {
        final opener = openers[index];
        const labelBg = Color(0xFFFBBF24);
        const valueBg = Color(0xFFFDE68A);
        const dividerColor = Color(0xFF4B5563);
        const labelStyle = TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: Color(0xFF374151),
        );

        Widget tableRow({
          required String label,
          required Widget right,
          bool isLast = false,
          Color rightBg = valueBg,
        }) {
          return Container(
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: dividerColor, width: 1),
                    ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 120,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: labelBg,
                      border: Border(
                        right: BorderSide(color: dividerColor, width: 1),
                      ),
                    ),
                    child: Center(child: Text(label, style: labelStyle)),
                  ),
                  Expanded(
                    child: Container(
                      color: rightBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: right,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ClipRRect(
          key: ValueKey(opener.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Row 1 — Header
                Container(
                  color: labelBg,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Text(
                            'Opener',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        tooltip: 'Delete Opener',
                        onPressed: () => _deleteOpener(opener),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: dividerColor),

                // Row 2 — Text
                tableRow(
                  label: 'Text',
                  right: TextFormField(
                    initialValue: opener.text,
                    maxLines: 3,
                    minLines: 1,
                    style: const TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Type your cold DM opener here...',
                      hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    onChanged: (val) {
                      opener.text = val;
                      _saveData();
                    },
                  ),
                ),

                // Row 3 — Times Used
                tableRow(
                  label: 'Times used',
                  right: Row(
                    children: [
                      Retro3DButton(
                        onPressed: () {
                          if (opener.timesUsed > 0) {
                            setState(() => opener.timesUsed--);
                            _saveData();
                          }
                        },
                        child: const Icon(
                          Icons.remove,
                          size: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${opener.timesUsed}',
                        style: const TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Retro3DButton(
                        onPressed: () {
                          setState(() => opener.timesUsed++);
                          _saveData();
                        },
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // Row 4 — Success
                tableRow(
                  label: 'Success',
                  isLast: true,
                  right: Row(
                    children: [
                      Retro3DButton(
                        onPressed: () {
                          if (opener.timesOpened > 0) {
                            setState(() => opener.timesOpened--);
                            _saveData();
                          }
                        },
                        child: const Icon(
                          Icons.remove,
                          size: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${opener.timesOpened}',
                        style: const TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Retro3DButton(
                        onPressed: () {
                          setState(() => opener.timesOpened++);
                          _saveData();
                        },
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${opener.successRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: opener.successRate >= 30
                              ? const Color(0xFF047857)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 2: PROFILES ---
  Widget _buildProfilesTab() {
    if (profiles.isEmpty) {
      return const Center(
        child: Text(
          'No profiles tracked yet. Click + to add a contact.',
          style: TextStyle(fontFamily: 'SF Pro', color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        final cleanHandle = profile.username.trim().replaceAll('@', '');
        final validOpenerId = openers.any((o) => o.id == profile.openerId)
            ? profile.openerId
            : null;

        const labelBg = Color(0xFFFBBF24);
        const valueBg = Color(0xFFFDE68A);
        const dividerColor = Color(0xFF4B5563);
        const labelStyle = TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: Color(0xFF374151),
        );

        Widget tableRow({
          required String label,
          required Widget right,
          bool isLast = false,
          Color rightBg = valueBg,
        }) {
          return Container(
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(
                      bottom: BorderSide(color: dividerColor, width: 1),
                    ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 120,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: labelBg,
                      border: Border(
                        right: BorderSide(color: dividerColor, width: 1),
                      ),
                    ),
                    child: Center(child: Text(label, style: labelStyle)),
                  ),
                  Expanded(
                    child: Container(
                      color: rightBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: right,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ClipRRect(
          key: ValueKey(profile.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Row 1 — Header
                Container(
                  color: labelBg,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Text(
                            'Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        tooltip: 'Delete Profile',
                        onPressed: () => _deleteProfile(profile),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: dividerColor),

                // Row 2 — Username
                tableRow(
                  label: 'Username',
                  right: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: profile.username,
                        style: const TextStyle(
                          fontFamily: 'Helvetica',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF374151),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. johndoe',
                          prefixText: '@',
                          prefixStyle: TextStyle(
                            fontFamily: 'Helvetica',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        onChanged: (val) {
                          setState(() => profile.username = val);
                          _saveData();
                        },
                      ),
                      if (cleanHandle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildPillActionButton(
                              label: 'Profile',
                              icon: Icons.open_in_new_rounded,
                              color: const Color(0xFFEEF2FF),
                              shadowColor: const Color(0xFFA5B4FC),
                              borderColor: const Color(0xFF818CF8),
                              textColor: const Color(0xFF4338CA),
                              onTap: () => _openUrl(
                                'https://www.instagram.com/$cleanHandle/',
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildPillActionButton(
                              label: 'Direct DM',
                              icon: Icons.send_rounded,
                              color: const Color(0xFFECFDF5),
                              shadowColor: const Color(0xFF6EE7B7),
                              borderColor: const Color(0xFF34D399),
                              textColor: const Color(0xFF047857),
                              onTap: () =>
                                  _openUrl('https://ig.me/m/$cleanHandle'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Row 3 — Last DM
                tableRow(
                  label: 'Last DM',
                  right: InkWell(
                    onTap: () => _pickDate(profile),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          profile.lastDmDate.isEmpty
                              ? 'Pick a date'
                              : profile.lastDmDate,
                          style: const TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Row 4 — Opener
                tableRow(
                  label: 'Opener',
                  right: DropdownButtonFormField<String>(
                    key: ValueKey('${profile.id}_$validOpenerId'),
                    initialValue: validOpenerId,
                    isExpanded: true,
                    style: const TextStyle(
                      fontFamily: 'Helvetica',
                      color: Color(0xFF374151),
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    dropdownColor: const Color(0xFFFDE68A),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'None',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      ...openers.map(
                        (o) => DropdownMenuItem<String>(
                          value: o.id,
                          child: Text(
                            o.text.isEmpty ? '(Untitled Opener)' : o.text,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Helvetica',
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: '__CREATE_NEW__',
                        child: Text(
                          '+ Create New Opener...',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => _linkOpenerToProfile(profile, val),
                  ),
                ),

                // Row 5 — Opened (green background when checked)
                tableRow(
                  label: 'Opened',
                  rightBg: profile.isOpened
                      ? const Color(0xFFD1FAE5)
                      : valueBg,
                  right: Row(
                    children: [
                      Checkbox(
                        value: profile.isOpened,
                        activeColor: const Color(0xFF10B981),
                        onChanged: (val) =>
                            _toggleProfileOpened(profile, val),
                      ),
                      Text(
                        profile.isOpened ? 'Yes — opened!' : 'Not yet',
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 14,
                          color: profile.isOpened
                              ? const Color(0xFF047857)
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Row 6 — Notes
                tableRow(
                  label: 'Notes',
                  isLast: true,
                  right: TextFormField(
                    initialValue: profile.notes,
                    maxLines: 3,
                    minLines: 2,
                    style: const TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 13,
                      color: Color(0xFF374151),
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Feed, niche, vibe, mutuals, talking points...',
                      hintStyle: TextStyle(
                        color: Colors.black38,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    onChanged: (val) {
                      profile.notes = val;
                      _saveData();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- BUTTON & CONTROL HELPERS (PRETTY 3D) ---
  Widget _buildPillActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color shadowColor,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Thick3DButton(
      depth: 3.0,
      borderRadius: 16.0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: color,
      shadowColor: shadowColor,
      borderColor: borderColor,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// --- BEAUTIFUL TACTILE 3D BUTTON COMPONENT ---
class Thick3DButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final Color shadowColor;
  final Color? borderColor;
  final double depth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isCircle;

  const Thick3DButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color = const Color(0xFFF3ECCC),
    this.shadowColor = const Color(0xFFC7B988),
    this.borderColor,
    this.depth = 4.0,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.isCircle = false,
  });

  @override
  State<Thick3DButton> createState() => _Thick3DButtonState();
}

class _Thick3DButtonState extends State<Thick3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        widget.borderColor ?? widget.shadowColor.withValues(alpha: 0.8);

    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(
          top: _isPressed ? widget.depth : 0.0,
          bottom: _isPressed ? 0.0 : widget.depth,
        ),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color,
          shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: effectiveBorderColor, width: 1.2),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: widget.shadowColor,
                    offset: Offset(0, widget.depth),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}

// --- RETRO ROUND 3D BUTTON (round grey + button, used in counters & FAB) ---
class Retro3DButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const Retro3DButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<Retro3DButton> createState() => _Retro3DButtonState();
}

class _Retro3DButtonState extends State<Retro3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(
          top: _isPressed ? 3.5 : 0.0,
          bottom: _isPressed ? 0.0 : 3.5,
        ),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFD1D5DB),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
          boxShadow: _isPressed
              ? []
              : const [
                  BoxShadow(
                    color: Color(0xFF9CA3AF),
                    offset: Offset(0, 3.5),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}
