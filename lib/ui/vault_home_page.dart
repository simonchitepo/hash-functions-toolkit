import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/security_copy.dart';
import '../models/vault_record.dart';
import '../services/export_service.dart';
import '../services/vault_crypto.dart';
import '../services/vault_store.dart';
import '../utils/masking.dart';

/// ----------------------------
/// UI
/// ----------------------------

class VaultHomePage extends StatefulWidget {
  const VaultHomePage({super.key});

  @override
  State<VaultHomePage> createState() => _VaultHomePageState();
}

class _VaultHomePageState extends State<VaultHomePage> {
  final _store = VaultStore();
  final _crypto = VaultCrypto();

  List<VaultRecord> _records = [];

  static const int maxAttempts = 3;
  final Map<String, int> _attemptsRemaining = {};

  @override
  void initState() {
    super.initState();
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSecurityModal());
  }

  void _refresh() {
    setState(() => _records = _store.getAll());
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _maybeShowSecurityModal() async {
    final prefs = Hive.box(VaultStore.prefsBoxName);
    final seen = prefs.get('seen_security_modal', defaultValue: false) as bool;
    if (seen) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SecurityDialog(),
    );

    await prefs.put('seen_security_modal', true);
  }

  Future<void> _openSecurityModal() async {
    await showDialog<void>(context: context, builder: (_) => const _SecurityDialog());
  }

  Future<void> _createNew() async {
    final result = await showDialog<_NewRecordInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NewRecordDialog(),
    );
    if (result == null) return;

    if (!isValidPin(result.pin)) {
      _toast("PIN must be exactly 6 digits.");
      return;
    }
    if (result.title.trim().isEmpty) {
      _toast("Title is required.");
      return;
    }
    if (result.data.trim().isEmpty) {
      _toast("Sensitive data is required.");
      return;
    }
    if (result.unmaskedLength < 0) {
      _toast("Unmasked length must be 0 or greater.");
      return;
    }

    final maskChar = result.maskChar.isEmpty ? "*" : result.maskChar.characters.first;

    final record = await _crypto.encryptToRecord(
      title: result.title.trim(),
      plaintext: result.data,
      pin: result.pin,
      unmaskedLength: result.unmaskedLength,
      maskChar: maskChar,
    );

    await _store.put(record);
    _refresh();
    _toast("Saved encrypted record.");
  }

  Future<void> _deleteRecord(VaultRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete record?"),
        content: Text("This deletes “${record.title}” from this browser storage."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    if (ok != true) return;

    await _store.delete(record.id);
    _refresh();
    _toast("Deleted.");
  }

  Future<void> _exportRecord(VaultRecord record) async {
    final export = ExportService.buildRecordExport(record);
    await ExportService.shareOrDownloadJson(fileName: export.fileName, bytes: export.bytes);
    _toast("Exported encrypted JSON.");
  }

  Future<void> _shareRecord(VaultRecord record) async {
    final export = ExportService.buildRecordExport(record);
    await ExportService.shareOrDownloadJson(fileName: export.fileName, bytes: export.bytes);
    _toast("Share invoked (encrypted payload).");
  }


  Future<void> _importRecords() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["json"],
      allowMultiple: true,
      withData: true,
    );

    if (res == null || res.files.isEmpty) return;

    final imported = <VaultRecord>[];

    for (final f in res.files) {
      try {
        final data = f.bytes;
        if (data == null) continue;

        final text = utf8.decode(data);
        final decoded = jsonDecode(text);

        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey("record") && decoded["record"] is Map) {
            imported.add(VaultRecord.fromJson((decoded["record"] as Map).cast<String, dynamic>()));
          } else {
            imported.add(VaultRecord.fromJson(decoded));
          }
        } else if (decoded is Map) {
          final m = decoded.cast<String, dynamic>();
          if (m.containsKey("record") && m["record"] is Map) {
            imported.add(VaultRecord.fromJson((m["record"] as Map).cast<String, dynamic>()));
          } else {
            imported.add(VaultRecord.fromJson(m));
          }
        } else if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              imported.add(VaultRecord.fromJson(item));
            } else if (item is Map) {
              imported.add(VaultRecord.fromJson(item.cast<String, dynamic>()));
            }
          }
        }
      } catch (_) {}
    }

    if (imported.isEmpty) {
      _toast("No valid vault records found in selected file(s).");
      return;
    }

    final count = await _store.importMany(imported);
    _refresh();
    _toast("Imported $count record(s).");
  }

  Future<void> _openRecord(VaultRecord record) async {
    _attemptsRemaining.putIfAbsent(record.id, () => maxAttempts);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _RecordViewerSheet(
        record: record,
        crypto: _crypto,
        attemptsRemaining: _attemptsRemaining[record.id] ?? maxAttempts,
        onAttemptsUpdate: (v) => setState(() => _attemptsRemaining[record.id] = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final narrow = isNarrowLayout(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // Responsive header block
                if (narrow)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        title: "Data Masking Vault",
                        subtitle:
                        "Encrypted, persistent storage in your browser. Export/import encrypted JSON for download, sharing, and portability.",
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _openSecurityModal,
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text("Security"),
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _Header(
                          title: "Data Masking Vault",
                          subtitle:
                          "Encrypted, persistent storage in your browser. Export/import encrypted JSON for download, sharing, and portability.",
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _openSecurityModal,
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text("Security"),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Responsive action bar (Wrap avoids overflow)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _createNew,
                      icon: const Icon(Icons.add),
                      label: const Text("New record"),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importRecords,
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Import"),
                    ),
                    if (!narrow)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text("${_records.length} record(s)", style: text.bodySmall),
                      ),
                  ],
                ),

                if (narrow) ...[
                  const SizedBox(height: 8),
                  Text("${_records.length} record(s)", style: text.bodySmall, textAlign: TextAlign.right),
                ],

                const SizedBox(height: 12),

                Expanded(
                  child: _records.isEmpty
                      ? _EmptyState(onCreate: _createNew, onImport: _importRecords, onSecurity: _openSecurityModal)
                      : ListView.separated(
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = _records[i];
                      return _RecordTile(
                        record: r,
                        narrow: narrow,
                        onOpen: () => _openRecord(r),
                        onExport: () => _exportRecord(r),
                        onShare: () => _shareRecord(r),
                        onDelete: () => _deleteRecord(r),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                Text(SecurityCopy.shortFooter, style: text.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(SecurityCopy.storageNote.trim(), style: text.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final VaultRecord record;
  final bool narrow;
  final VoidCallback onOpen;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _RecordTile({
    required this.record,
    required this.narrow,
    required this.onOpen,
    required this.onExport,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.black),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.title, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      "Encrypted • mask='${record.maskChar}' • unmasked=${record.unmaskedLength} • AES-GCM",
                      style: text.bodySmall?.copyWith(fontFamily: "monospace"),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Updated: ${DateTime.fromMillisecondsSinceEpoch(record.updatedAtMs)}",
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Narrow screens: use a menu instead of 4 icon buttons
              if (narrow)
                PopupMenuButton<String>(
                  tooltip: "Actions",
                  onSelected: (v) {
                    switch (v) {
                      case "open":
                        onOpen();
                        break;
                      case "export":
                        onExport();
                        break;
                      case "share":
                        onShare();
                        break;
                      case "delete":
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: "open", child: Text("Open")),
                    PopupMenuItem(value: "export", child: Text("Export")),
                    PopupMenuItem(value: "share", child: Text("Share")),
                    PopupMenuDivider(),
                    PopupMenuItem(value: "delete", child: Text("Delete")),
                  ],
                )
              else
                Column(
                  children: [
                    IconButton(tooltip: "Open", onPressed: onOpen, icon: const Icon(Icons.open_in_new)),
                    IconButton(tooltip: "Export", onPressed: onExport, icon: const Icon(Icons.download)),
                    IconButton(tooltip: "Share", onPressed: onShare, icon: const Icon(Icons.share)),
                    IconButton(tooltip: "Delete", onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onImport;
  final VoidCallback onSecurity;

  const _EmptyState({
    required this.onCreate,
    required this.onImport,
    required this.onSecurity,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("No records yet", style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              "Create a record or import an encrypted JSON export.",
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Review the security disclaimer and best practices before storing real secrets.",
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text("New record")),
                OutlinedButton.icon(onPressed: onImport, icon: const Icon(Icons.upload_file), label: const Text("Import")),
                OutlinedButton.icon(onPressed: onSecurity, icon: const Icon(Icons.privacy_tip_outlined), label: const Text("Security")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.headlineMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// ----------------------------
/// Security dialog
/// ----------------------------

class _SecurityDialog extends StatelessWidget {
  const _SecurityDialog();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text(SecurityCopy.title)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(SecurityCopy.disclaimer.trim(), style: text.bodySmall),
              const SizedBox(height: 14),
              Text(SecurityCopy.bestPracticesTitle, style: text.titleMedium),
              const SizedBox(height: 8),
              Text(SecurityCopy.bestPractices.trim(), style: text.bodySmall),
              const SizedBox(height: 14),
              Text("Storage scope", style: text.titleMedium),
              const SizedBox(height: 8),
              Text(SecurityCopy.storageNote.trim(), style: text.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text("I understand")),
      ],
    );
  }
}

/// ----------------------------
/// New record dialog (responsive)
/// ----------------------------

class _NewRecordInput {
  final String title;
  final String data;
  final String pin;
  final int unmaskedLength;
  final String maskChar;

  _NewRecordInput({
    required this.title,
    required this.data,
    required this.pin,
    required this.unmaskedLength,
    required this.maskChar,
  });
}

class _NewRecordDialog extends StatefulWidget {
  const _NewRecordDialog();

  @override
  State<_NewRecordDialog> createState() => _NewRecordDialogState();
}

class _NewRecordDialogState extends State<_NewRecordDialog> {
  final _title = TextEditingController();
  final _data = TextEditingController();
  final _pin = TextEditingController();
  final _unmasked = TextEditingController(text: "4");
  final _maskChar = TextEditingController(text: "*");

  @override
  void dispose() {
    _title.dispose();
    _data.dispose();
    _pin.dispose();
    _unmasked.dispose();
    _maskChar.dispose();
    super.dispose();
  }

  int _unmaskedLen() => int.tryParse(_unmasked.text.trim()) ?? 4;

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowLayout(context);

    return AlertDialog(
      title: const Text("New encrypted record"),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: "Title", hintText: "e.g., Visa card, API key, SSN"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _data,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(labelText: "Sensitive data", hintText: "Stored encrypted (AES-GCM)."),
              ),
              const SizedBox(height: 10),

              // Responsive controls: stack on narrow screens
              if (narrow) ...[
                _PinField(controller: _pin, label: "6-digit PIN"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _unmasked,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Unmasked", hintText: "4"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _maskChar,
                        decoration: const InputDecoration(labelText: "Mask char", hintText: "*"),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _PinField(controller: _pin, label: "6-digit PIN")),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _unmasked,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Unmasked", hintText: "4"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _maskChar,
                        decoration: const InputDecoration(labelText: "Mask char", hintText: "*"),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Preview (local): ${maskData(
                    _data.text,
                    maskChar: _maskChar.text.isEmpty ? "*" : _maskChar.text.characters.first,
                    unmaskedLength: _unmaskedLen(),
                  )}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: "monospace"),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Reminder: masking is display-only; encryption strength depends on your PIN/passphrase.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _NewRecordInput(
                title: _title.text,
                data: _data.text,
                pin: _pin.text.trim(),
                unmaskedLength: _unmaskedLen(),
                maskChar: _maskChar.text,
              ),
            );
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}

/// A PIN input optimized for mobile: digits only, 6 max, centered.
class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _PinField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: "123456",
        counterText: "",
      ),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2),
    );
  }
}

/// ----------------------------
/// Record viewer sheet (responsive PIN entry)
/// ----------------------------

class _RecordViewerSheet extends StatefulWidget {
  final VaultRecord record;
  final VaultCrypto crypto;
  final int attemptsRemaining;
  final ValueChanged<int> onAttemptsUpdate;

  const _RecordViewerSheet({
    required this.record,
    required this.crypto,
    required this.attemptsRemaining,
    required this.onAttemptsUpdate,
  });

  @override
  State<_RecordViewerSheet> createState() => _RecordViewerSheetState();
}

class _RecordViewerSheetState extends State<_RecordViewerSheet> {
  final _pin = TextEditingController();
  String? _decrypted;
  String? _error;

  bool _locked = false;
  int _lockSeconds = 0;
  Timer? _timer;

  late int _attempts;

  @override
  void initState() {
    super.initState();
    _attempts = widget.attemptsRemaining;
  }

  @override
  void dispose() {
    _pin.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startLockout() {
    _timer?.cancel();
    setState(() {
      _locked = true;
      _lockSeconds = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _lockSeconds -= 1;
        if (_lockSeconds <= 0) {
          _locked = false;
          _attempts = 3;
          widget.onAttemptsUpdate(_attempts);
          _error = "Lockout ended. You may try again.";
          t.cancel();
        }
      });
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _decrypt() async {
    if (_locked) return;

    final pin = _pin.text.trim();
    if (!isValidPin(pin)) return _toast("PIN must be exactly 6 digits.");

    try {
      final clear = await widget.crypto.decryptRecord(record: widget.record, pin: pin);
      setState(() {
        _decrypted = clear;
        _error = null;
        _attempts = 3;
      });
      widget.onAttemptsUpdate(_attempts);
      _toast("Decrypted.");
    } catch (_) {
      setState(() {
        _decrypted = null;
        _attempts -= 1;
        _error = "Incorrect PIN or tampered data. Attempts remaining: $_attempts.";
      });
      widget.onAttemptsUpdate(_attempts);

      if (_attempts <= 0) {
        setState(() => _error = "Fail-safe triggered: too many incorrect attempts. Locked for 60 seconds.");
        _startLockout();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final text = Theme.of(context).textTheme;
    final narrow = isNarrowLayout(context);

    // Constrain width for tablets/desktop; use full width on phones.
    final maxWidth = narrow ? double.infinity : 720.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 14,
        bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.title, style: text.titleMedium)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Stored encrypted (AES-GCM). Mask policy: mask='${r.maskChar}', unmasked=${r.unmaskedLength}.",
                  style: text.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  "Reminder: masking is display-only; encryption strength depends on your PIN/passphrase.",
                  style: text.bodySmall,
                ),
                const SizedBox(height: 14),

                // PIN field optimized for mobile
                _PinField(controller: _pin, label: "Enter PIN to decrypt"),

                const SizedBox(height: 8),
                Text(
                  _locked ? "Locked: $_lockSeconds seconds remaining." : "Attempts remaining: $_attempts",
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _locked ? null : _decrypt,
                  child: const Text("Decrypt"),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: text.bodySmall, textAlign: TextAlign.center),
                ],

                if (_decrypted != null) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text("Masked", style: text.titleMedium),
                  const SizedBox(height: 8),
                  _OutputBox(
                    value: maskData(
                      _decrypted!,
                      maskChar: r.maskChar,
                      unmaskedLength: r.unmaskedLength,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("Unmasked", style: text.titleMedium),
                  const SizedBox(height: 8),
                  _OutputBox(value: _decrypted!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutputBox extends StatelessWidget {
  final String value;
  const _OutputBox({required this.value});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: SelectableText(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: "monospace"),
      ),
    );
  }
}
