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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  final newOpener = OpenerItem(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    text: controller.text.trim(),
                  );
                  Navigator.of(context).pop(newOpener);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E2E34),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Create & Link'),
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF8C8C8C),
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
      floatingActionButton: FloatingActionButton.extended(
        elevation: 2,
        backgroundColor: const Color(0xFF2E2E34),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _tabController.index == 0
            ? _addEmptyOpener
            : _addEmptyProfile,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          _tabController.index == 0 ? 'New Opener' : 'New Profile',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  // --- TAB 1: OPENERS ---
  Widget _buildOpenersTab() {
    if (openers.isEmpty) {
      return const Center(
        child: Text(
          'No openers yet. Click New Opener to add your first template.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: openers.length,
      itemBuilder: (context, index) {
        final opener = openers[index];
        return Card(
          key: ValueKey(opener.id),
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2D9B3), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Opener title + Success Rate pill + Delete Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.format_quote_rounded,
                          size: 16,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Opener #${openers.length - index}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Success Rate Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: opener.successRate >= 30
                                ? const Color(0xFFD1FAE5)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: opener.successRate >= 30
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFD4C894),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                size: 14,
                                color: opener.successRate >= 30
                                    ? const Color(0xFF059669)
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${opener.successRate.toStringAsFixed(1)}% success',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: opener.successRate >= 30
                                      ? const Color(0xFF047857)
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildDeleteButton(
                          tooltip: 'Delete Opener',
                          onPressed: () => _deleteOpener(opener),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Opener Line (Vertically stacked, multiline support)
                TextFormField(
                  initialValue: opener.text,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Opener Script',
                    hintText: 'Type your cold DM opener line here...',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (val) {
                    opener.text = val;
                    _saveData();
                  },
                ),
                const SizedBox(height: 12),

                // 3. Stats & Counters Row (Vertically stacked underneath)
                Row(
                  children: [
                    Expanded(
                      child: _buildCounterBox(
                        label: 'Times Used',
                        value: opener.timesUsed,
                        icon: Icons.send_rounded,
                        onDecrement: () {
                          if (opener.timesUsed > 0) {
                            setState(() => opener.timesUsed--);
                            _saveData();
                          }
                        },
                        onIncrement: () {
                          setState(() => opener.timesUsed++);
                          _saveData();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCounterBox(
                        label: 'Times Opened',
                        value: opener.timesOpened,
                        icon: Icons.mark_email_read_rounded,
                        onDecrement: () {
                          if (opener.timesOpened > 0) {
                            setState(() => opener.timesOpened--);
                            _saveData();
                          }
                        },
                        onIncrement: () {
                          setState(() => opener.timesOpened++);
                          _saveData();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCounterBox({
    required String label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2D9B3)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.black45),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          _buildMiniButton(
            icon: Icons.remove_rounded,
            onPressed: onDecrement,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          _buildMiniButton(
            icon: Icons.add_rounded,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }

  // --- TAB 2: PROFILES ---
  Widget _buildProfilesTab() {
    if (profiles.isEmpty) {
      return const Center(
        child: Text(
          'No profiles tracked yet. Click New Profile to add a contact.',
          style: TextStyle(color: Colors.black54),
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

        return Card(
          key: ValueKey(profile.id),
          margin: const EdgeInsets.only(bottom: 14),
          color: profile.isOpened
              ? const Color(0xFFECFDF5) // Soft mint green when opened
              : const Color(0xFFFFFBEA), // Light notepad yellow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: profile.isOpened
                  ? const Color(0xFF10B981)
                  : const Color(0xFFE2D9B3),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Field 1: Top Bar (Username + Quick Action Links + Opened Toggle + Delete)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        initialValue: profile.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'e.g. johndoe',
                          prefixText: '@',
                          prefixStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => profile.username = val);
                          _saveData();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Quick Action Buttons
                    if (cleanHandle.isNotEmpty) ...[
                      _buildPillActionButton(
                        label: 'Profile',
                        icon: Icons.open_in_new_rounded,
                        bgColor: const Color(0xFFEEF2FF),
                        borderColor: const Color(0xFFC7D2FE),
                        textColor: const Color(0xFF4338CA),
                        onTap: () => _openUrl(
                          'https://www.instagram.com/$cleanHandle/',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPillActionButton(
                        label: 'Direct DM',
                        icon: Icons.send_rounded,
                        bgColor: const Color(0xFFECFDF5),
                        borderColor: const Color(0xFFA7F3D0),
                        textColor: const Color(0xFF047857),
                        onTap: () =>
                            _openUrl('https://ig.me/m/$cleanHandle'),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Opened Status Pill Toggle Button
                    _buildOpenedStatusToggle(profile),

                    const SizedBox(width: 8),

                    // Delete Profile Button
                    _buildDeleteButton(
                      tooltip: 'Delete Profile',
                      onPressed: () => _deleteProfile(profile),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Field 2: Details Row (Opener Dropdown + Last DM Date)
                Row(
                  children: [
                    // Opener Dropdown
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('${profile.id}_$validOpenerId'),
                        initialValue: validOpenerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Opener Used',
                          prefixIcon: Icon(
                            Icons.forum_outlined,
                            size: 16,
                            color: Colors.black45,
                          ),
                        ),
                        dropdownColor: const Color(0xFFFFFBEA),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'None',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          ...openers.map(
                            (o) => DropdownMenuItem<String>(
                              value: o.id,
                              child: Text(
                                o.text.isEmpty ? '(Untitled Opener)' : o.text,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const DropdownMenuItem<String>(
                            value: '__CREATE_NEW__',
                            child: Text(
                              '+ Create New Opener...',
                              style: TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) => _linkOpenerToProfile(profile, val),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Last DM Sent Date Picker
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () => _pickDate(profile),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Last DM Sent',
                            prefixIcon: Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: Colors.black45,
                            ),
                          ),
                          child: Text(
                            profile.lastDmDate,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Field 3: Feed / Person Notes
                TextFormField(
                  initialValue: profile.notes,
                  maxLines: 2,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Feed / Person Notes',
                    hintText:
                        'What is their feed like? Niche, vibe, mutuals, talking points...',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (val) {
                    profile.notes = val;
                    _saveData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- BUTTON & CONTROL HELPERS ---
  Widget _buildMiniButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFF3ECCC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD4C894)),
        ),
        child: Icon(icon, size: 14, color: Colors.black87),
      ),
    );
  }

  Widget _buildDeleteButton({
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            size: 16,
            color: Color(0xFFDC2626),
          ),
        ),
      ),
    );
  }

  Widget _buildPillActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenedStatusToggle(ProfileItem profile) {
    return InkWell(
      onTap: () => _toggleProfileOpened(profile, !profile.isOpened),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: profile.isOpened
              ? const Color(0xFF10B981)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: profile.isOpened
                ? const Color(0xFF059669)
                : const Color(0xFFD4C894),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              profile.isOpened
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 15,
              color: profile.isOpened ? Colors.white : Colors.black45,
            ),
            const SizedBox(width: 6),
            Text(
              profile.isOpened ? 'Opened' : 'Unopened',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: profile.isOpened ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
