import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_aepcore/flutter_aepcore.dart';
import 'package:flutter_aepcore/flutter_aepidentity.dart';
import 'package:flutter_aepuserprofile/flutter_aepuserprofile.dart';

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity & Tracking'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Identity'),
            Tab(icon: Icon(Icons.track_changes), text: 'Track'),
            Tab(icon: Icon(Icons.manage_accounts), text: 'Profile'),
            Tab(icon: Icon(Icons.privacy_tip), text: 'PII'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _IdentityTab(),
          _TrackTab(),
          _ProfileTab(),
          _PiiTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: Identity (email + lumaCRMId)
// ─────────────────────────────────────────────────────────────────────────────

class _IdentityTab extends StatefulWidget {
  const _IdentityTab();

  @override
  State<_IdentityTab> createState() => _IdentityTabState();
}

class _IdentityTabState extends State<_IdentityTab> {
  final _emailCtrl = TextEditingController();
  final _crmCtrl = TextEditingController();
  String _ecid = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadEcid();
  }

  Future<void> _loadEcid() async {
    try {
      final ecid = await Identity.experienceCloudId;
      setState(() => _ecid = ecid);
    } catch (_) {}
  }

  Future<void> _syncIdentifiers() async {
    if (_emailCtrl.text.isEmpty && _crmCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      // syncIdentifiersWithAuthState รับ Map ทั้งหมดพร้อมกัน
      final ids = <String, String>{};
      if (_emailCtrl.text.isNotEmpty) ids['Email'] = _emailCtrl.text.trim();
      if (_crmCtrl.text.isNotEmpty) ids['lumaCRMId'] = _crmCtrl.text.trim();
      if (ids.isNotEmpty) {
        await Identity.syncIdentifiersWithAuthState(
          ids,
          MobileVisitorAuthenticationState.authenticated,
        );
      }
      _snack('Identifiers synced ✓');
    } catch (e) {
      _snack('Error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _getIdentifiers() async {
    try {
      final ids = await Identity.identifiers;
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Current Identifiers'),
          content: SingleChildScrollView(
            child: Text(ids.map((i) => '${i.idType}: ${i.identifier}').join('\n')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      _snack('Error: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Experience Cloud ID',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _ecid.isEmpty ? 'กำลังโหลด...' : _ecid,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEcid),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Sync Identifiers',
          child: Column(
            children: [
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _crmCtrl,
                decoration: const InputDecoration(
                  labelText: 'lumaCRMId',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _syncIdentifiers,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync),
                      label: const Text('Sync'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.indigo[700]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _getIdentifiers,
                    icon: const Icon(Icons.list),
                    label: const Text('Get All'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: Track Action / Track State
// ─────────────────────────────────────────────────────────────────────────────

class _TrackTab extends StatefulWidget {
  const _TrackTab();

  @override
  State<_TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends State<_TrackTab> {
  final _actionCtrl = TextEditingController(text: 'button_tap');
  final _stateCtrl = TextEditingController(text: 'home_screen');
  final _dataCtrl = TextEditingController(text: '{"key": "value"}');
  final List<String> _log = [];

  Map<String, String> _parseData() {
    try {
      final m = jsonDecode(_dataCtrl.text) as Map;
      return m.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _trackAction() async {
    try {
      await MobileCore.trackAction(_actionCtrl.text, data: _parseData());
      _addLog('trackAction: "${_actionCtrl.text}"');
    } catch (e) {
      _addLog('Error: $e');
    }
  }

  Future<void> _trackState() async {
    try {
      await MobileCore.trackState(_stateCtrl.text, data: _parseData());
      _addLog('trackState: "${_stateCtrl.text}"');
    } catch (e) {
      _addLog('Error: $e');
    }
  }

  void _addLog(String msg) {
    setState(() => _log.insert(0, '[${TimeOfDay.now().format(context)}] $msg'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Track Action',
          child: Column(
            children: [
              TextField(
                controller: _actionCtrl,
                decoration: const InputDecoration(labelText: 'Action name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dataCtrl,
                decoration: const InputDecoration(labelText: 'Context data (JSON)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _trackAction,
                      icon: const Icon(Icons.bolt),
                      label: const Text('Track Action'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.indigo[700]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _trackState,
                      icon: const Icon(Icons.pageview),
                      label: const Text('Track State'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.teal[700]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          title: 'Track State name',
          child: TextField(
            controller: _stateCtrl,
            decoration: const InputDecoration(labelText: 'State name', border: OutlineInputBorder()),
          ),
        ),
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Log',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _log.take(10).map((l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              )).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: User Profile
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _keyCtrl = TextEditingController(text: 'membershipTier');
  final _valueCtrl = TextEditingController(text: 'gold');
  final _getKeyCtrl = TextEditingController(text: 'membershipTier');
  String _result = '';

  Future<void> _updateAttribute() async {
    if (_keyCtrl.text.isEmpty) return;
    try {
      await UserProfile.updateUserAttributes({_keyCtrl.text: _valueCtrl.text});
      _snack('Updated: ${_keyCtrl.text} = ${_valueCtrl.text} ✓');
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _getAttribute() async {
    if (_getKeyCtrl.text.isEmpty) return;
    try {
      final raw = await UserProfile.getUserAttributes([_getKeyCtrl.text]);
      final map = raw.isNotEmpty ? jsonDecode(raw) as Map : {};
      setState(() => _result = map.isEmpty ? '(empty)' : map.entries.map((e) => '${e.key}: ${e.value}').join('\n'));
    } catch (e) {
      setState(() => _result = 'Error: $e');
    }
  }

  Future<void> _removeAttribute() async {
    if (_keyCtrl.text.isEmpty) return;
    try {
      await UserProfile.removeUserAttributes([_keyCtrl.text]);
      _snack('Removed: ${_keyCtrl.text} ✓');
    } catch (e) {
      _snack('Error: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Update Attribute',
          child: Column(
            children: [
              TextField(
                controller: _keyCtrl,
                decoration: const InputDecoration(labelText: 'Key', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _valueCtrl,
                decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _updateAttribute,
                      icon: const Icon(Icons.save),
                      label: const Text('Update'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.indigo[700]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _removeAttribute,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Get Attribute',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _getKeyCtrl,
                      decoration: const InputDecoration(labelText: 'Key', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _getAttribute,
                    style: FilledButton.styleFrom(backgroundColor: Colors.teal[700]),
                    child: const Text('Get'),
                  ),
                ],
              ),
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Text(_result, style: const TextStyle(fontFamily: 'monospace')),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4: Collect PII
// ─────────────────────────────────────────────────────────────────────────────

class _PiiTab extends StatefulWidget {
  const _PiiTab();

  @override
  State<_PiiTab> createState() => _PiiTabState();
}

class _PiiTabState extends State<_PiiTab> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  Future<void> _collectPii() async {
    final data = <String, String>{};
    if (_firstNameCtrl.text.isNotEmpty) data['firstName'] = _firstNameCtrl.text;
    if (_lastNameCtrl.text.isNotEmpty) data['lastName'] = _lastNameCtrl.text;
    if (_emailCtrl.text.isNotEmpty) data['email'] = _emailCtrl.text;
    if (_phoneCtrl.text.isNotEmpty) data['phone'] = _phoneCtrl.text;

    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลอย่างน้อย 1 ช่อง')));
      return;
    }
    try {
      await MobileCore.collectPii(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PII sent to Adobe ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('ต้องตั้งค่า PII callback ใน Adobe Launch ก่อนใช้งาน', style: TextStyle(fontSize: 13))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Collect PII',
          child: Column(
            children: [
              TextField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _collectPii,
                  icon: const Icon(Icons.send),
                  label: const Text('Collect PII'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepOrange[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widget
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo[800])),
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
