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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141416),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E1E22),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF2E2E34), width: 1),
          ),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF141416),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2E2E34)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2E2E34)),
          ),
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
          backgroundColor: const Color(0xFF1E1E22),
          title: const Text('Create New Opener'),
          content: TextField(
            controller: controller,
            autofocus: true,
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
        backgroundColor: const Color(0xFF1E1E22),
        elevation: 0,
        title: const Text(
          'Cold DM Tracker',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        onPressed: _tabController.index == 0
            ? _addEmptyOpener
            : _addEmptyProfile,
        tooltip: _tabController.index == 0 ? 'Add Opener' : 'Add Profile',
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- TAB 1: OPENERS ---
  Widget _buildOpenersTab() {
    if (openers.isEmpty) {
      return const Center(
        child: Text(
          'No openers yet. Click + in the corner to add your first opener.',
          style: TextStyle(color: Colors.white54),
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
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 1. Line Content
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    initialValue: opener.text,
                    decoration: const InputDecoration(
                      labelText: 'Opener Line',
                      hintText: 'Type your cold DM opener...',
                    ),
                    onChanged: (val) {
                      opener.text = val;
                      _saveData();
                    },
                  ),
                ),
                const SizedBox(width: 20),

                // 2. Times Used Counter
                _buildCounterBox(
                  label: 'Times Used',
                  value: opener.timesUsed,
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
                const SizedBox(width: 20),

                // 3. Times Opened Counter
                _buildCounterBox(
                  label: 'Times Opened',
                  value: opener.timesOpened,
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
                const SizedBox(width: 24),

                // 4. Success Rate %
                SizedBox(
                  width: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Success Rate',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${opener.successRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: opener.successRate >= 30
                              ? const Color(0xFF10B981)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white38,
                    size: 20,
                  ),
                  tooltip: 'Delete Opener',
                  onPressed: () => _deleteOpener(opener),
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
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2E2E34)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 15),
                visualDensity: VisualDensity.compact,
                onPressed: onDecrement,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 15),
                visualDensity: VisualDensity.compact,
                onPressed: onIncrement,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 2: PROFILES ---
  Widget _buildProfilesTab() {
    if (profiles.isEmpty) {
      return const Center(
        child: Text(
          'No profiles tracked yet. Click + in the corner to add a recipient.',
          style: TextStyle(color: Colors.white54),
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
          margin: const EdgeInsets.only(bottom: 10),
          color: profile.isOpened
              ? const Color(0xFF0F291E) // Turns green when opened is toggled on
              : const Color(0xFF1E1E22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: profile.isOpened
                  ? const Color(0xFF10B981)
                  : const Color(0xFF2E2E34),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Username + Clickable Profile/DM Links
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: profile.username,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'e.g. johndoe',
                          prefixText: '@',
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
                            InkWell(
                              onTap: () => _openUrl(
                                'https://www.instagram.com/$cleanHandle/',
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.open_in_new,
                                    size: 12,
                                    color: Color(0xFF818CF8),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Profile',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF818CF8),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () =>
                                  _openUrl('https://ig.me/m/$cleanHandle'),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.send_outlined,
                                    size: 12,
                                    color: Color(0xFF34D399),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Direct DM',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF34D399),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Last DM Date (Clickable Date Picker)
                SizedBox(
                  width: 130,
                  child: InkWell(
                    onTap: () => _pickDate(profile),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Last DM Sent',
                        suffixIcon: Icon(Icons.calendar_today, size: 14),
                      ),
                      child: Text(
                        profile.lastDmDate,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Opener Used Dropdown (Linked to Tab 1 + Create New option)
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('${profile.id}_$validOpenerId'),
                    initialValue: validOpenerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Opener Used'),
                    dropdownColor: const Color(0xFF1E1E22),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'None',
                          style: TextStyle(color: Colors.white54),
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
                            color: Color(0xFF818CF8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => _linkOpenerToProfile(profile, val),
                  ),
                ),
                const SizedBox(width: 12),

                // 4. Opened Toggle (Turns Row Green + Increments Opener Success)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Opened',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    Checkbox(
                      value: profile.isOpened,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => _toggleProfileOpened(profile, val),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // 5. Feed / Person Notes Field
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    initialValue: profile.notes,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'Feed / Person Notes',
                      hintText:
                          'What is their feed like? Niche, vibe, mutuals...',
                    ),
                    onChanged: (val) {
                      profile.notes = val;
                      _saveData();
                    },
                  ),
                ),
                const SizedBox(width: 6),

                // Delete Row Button
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white38,
                    size: 20,
                  ),
                  tooltip: 'Delete Profile',
                  onPressed: () => _deleteProfile(profile),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
