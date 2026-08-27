import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bed.dart';
import '../../models/flat.dart';
import '../../models/room.dart';
import '../../models/room_type.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';

class TenantFormScreen extends ConsumerStatefulWidget {
  final String pgId;
  final String? tenantId;
  const TenantFormScreen({super.key, required this.pgId, this.tenantId});

  @override
  ConsumerState<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends ConsumerState<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _provisioningLogin = false;
  String? _selectedBedId;
  String? _originalBedId;

  // Fields this form doesn't expose UI for, but must carry forward on save
  // so editing basic details doesn't wipe them.
  TenantStatus _existingStatus = TenantStatus.active;
  List<TenantDocument> _existingDocuments = const [];
  VerificationStatus _existingVerificationStatus = VerificationStatus.notSubmitted;
  String? _existingVerificationNote;
  String? _existingPhotoUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.tenantId != null) {
      final tenant = await ref.read(firestoreServiceProvider).getTenant(widget.tenantId!);
      if (tenant != null) {
        _nameController.text = tenant.name;
        _mobileController.text = tenant.mobile;
        _emailController.text = tenant.email;
        _rentController.text = tenant.rentAmount.toStringAsFixed(0);
        _depositController.text = tenant.depositAmount.toStringAsFixed(0);
        _emergencyNameController.text = tenant.emergencyContactName ?? '';
        _emergencyPhoneController.text = tenant.emergencyContactPhone ?? '';
        _selectedBedId = tenant.bedId;
        _originalBedId = tenant.bedId;
        _existingStatus = tenant.status;
        _existingDocuments = tenant.documents;
        _existingVerificationStatus = tenant.verificationStatus;
        _existingVerificationNote = tenant.verificationNote;
        _existingPhotoUrl = tenant.photoUrl;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final isNew = widget.tenantId == null;
      final tenant = Tenant(
        id: widget.tenantId ?? '',
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        photoUrl: _existingPhotoUrl,
        pgId: widget.pgId,
        bedId: _selectedBedId ?? '',
        rentAmount: double.tryParse(_rentController.text) ?? 0,
        depositAmount: double.tryParse(_depositController.text) ?? 0,
        joinDate: isNew ? DateTime.now() : null,
        status: isNew ? TenantStatus.active : _existingStatus,
        documents: _existingDocuments,
        verificationStatus: _existingVerificationStatus,
        verificationNote: _existingVerificationNote,
        emergencyContactName:
            _emergencyNameController.text.trim().isEmpty ? null : _emergencyNameController.text.trim(),
        emergencyContactPhone:
            _emergencyPhoneController.text.trim().isEmpty ? null : _emergencyPhoneController.text.trim(),
      );
      final savedId = await ref.read(firestoreServiceProvider).upsertTenant(tenant);

      if (_selectedBedId != _originalBedId) {
        await ref.read(firestoreServiceProvider).changeTenantBed(
              oldBedId: _originalBedId,
              newBedId: _selectedBedId,
              tenantId: savedId,
            );
      }

      if (isNew && tenant.email.isNotEmpty) {
        await _provisionLogin(savedId, showErrors: false);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _provisionLogin(String tenantId, {bool showErrors = true}) async {
    setState(() => _provisioningLogin = true);
    try {
      final login = await ref.read(functionsServiceProvider).provisionTenantLogin(tenantId);
      if (mounted) await _showCredentialsDialog(login.email, login.password);
    } catch (e) {
      if (mounted && showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create login: $e')));
      }
    } finally {
      if (mounted) setState(() => _provisioningLogin = false);
    }
  }

  Future<void> _exitTenant() async {
    final result = await showDialog<_ExitResult>(
      context: context,
      builder: (context) => _ExitTenantDialog(defaultDeposit: double.tryParse(_depositController.text) ?? 0),
    );
    if (result == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).exitTenant(
            tenantId: widget.tenantId!,
            bedId: _originalBedId ?? '',
            exitDate: result.exitDate,
            depositRefunded: result.depositRefunded,
            notes: result.notes,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not check out tenant: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCredentialsDialog(String email, String password) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tenant login created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share these with the tenant now — the password cannot be shown again.'),
            const SizedBox(height: 16),
            SelectableText('Email: $email'),
            SelectableText('Password: $password'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Email: $email\nPassword: $password'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
            },
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
  }

  void _onBedSelected(_BedOption? option) {
    if (option == null) return;
    setState(() {
      _selectedBedId = option.bed.id;
      _rentController.text = option.roomType.defaultRent.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isEditing = widget.tenantId != null;
    final flatsAsync = ref.watch(flatsProvider(widget.pgId));
    final roomsAsync = ref.watch(roomsProvider(widget.pgId));
    final bedsAsync = ref.watch(bedsProvider(widget.pgId));
    final typesAsync = ref.watch(roomTypesProvider(widget.pgId));

    final bedOptions = _buildBedOptions(
      flats: flatsAsync.value ?? [],
      rooms: roomsAsync.value ?? [],
      beds: bedsAsync.value ?? [],
      types: typesAsync.value ?? [],
    );
    final selectedOption = bedOptions.where((o) => o.bed.id == _selectedBedId);
    final currentSelection = selectedOption.isEmpty ? null : selectedOption.first;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit tenant' : 'Add tenant')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                helperText: 'Used to create their tenant app login',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_BedOption>(
              initialValue: currentSelection,
              decoration: const InputDecoration(labelText: 'Bed'),
              isExpanded: true,
              items: bedOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o.label, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: _onBedSelected,
              validator: (v) => v == null ? 'Select a bed' : null,
            ),
            if (bedOptions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'No empty beds. Set up flats/rooms first from the Rooms screen.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rent amount'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _depositController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Deposit amount'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(labelText: 'Emergency contact name (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Emergency contact phone (optional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: _provisioningLogin
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.key),
                label: const Text('Generate / reset app login'),
                onPressed: (_provisioningLogin || _emailController.text.trim().isEmpty)
                    ? null
                    : () => _provisionLogin(widget.tenantId!),
              ),
              if (_existingStatus == TenantStatus.active) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.logout),
                  label: const Text('Exit tenant / checkout'),
                  onPressed: _saving ? null : _exitTenant,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<_BedOption> _buildBedOptions({
    required List<Flat> flats,
    required List<Room> rooms,
    required List<Bed> beds,
    required List<RoomType> types,
  }) {
    final options = <_BedOption>[];
    for (final bed in beds) {
      final isSelectable = !bed.isOccupied || bed.id == _originalBedId;
      if (!isSelectable) continue;

      final roomMatches = rooms.where((r) => r.id == bed.roomId);
      if (roomMatches.isEmpty) continue;
      final room = roomMatches.first;

      final typeMatches = types.where((t) => t.id == room.roomTypeId);
      if (typeMatches.isEmpty) continue;
      final roomType = typeMatches.first;

      final flatMatches = flats.where((f) => f.id == bed.flatId);
      final flatName = flatMatches.isEmpty ? '?' : flatMatches.first.name;

      options.add(_BedOption(
        bed: bed,
        roomType: roomType,
        label: '$flatName · Room ${room.roomNumber} (${roomType.name}) · ${bed.bedLabel}'
            ' — ₹${roomType.defaultRent.toStringAsFixed(0)}',
      ));
    }
    return options;
  }
}

class _BedOption {
  final Bed bed;
  final RoomType roomType;
  final String label;
  _BedOption({required this.bed, required this.roomType, required this.label});
}

class _ExitResult {
  final DateTime exitDate;
  final double depositRefunded;
  final String? notes;
  _ExitResult({required this.exitDate, required this.depositRefunded, this.notes});
}

class _ExitTenantDialog extends StatefulWidget {
  final double defaultDeposit;
  const _ExitTenantDialog({required this.defaultDeposit});

  @override
  State<_ExitTenantDialog> createState() => _ExitTenantDialogState();
}

class _ExitTenantDialogState extends State<_ExitTenantDialog> {
  late final TextEditingController _refundController =
      TextEditingController(text: widget.defaultDeposit.toStringAsFixed(0));
  final TextEditingController _notesController = TextEditingController();
  DateTime _exitDate = DateTime.now();

  @override
  void dispose() {
    _refundController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _exitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _exitDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exit tenant / checkout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This frees their bed and marks them as exited. This cannot be undone from here.'),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Exit date'),
            subtitle: Text('${_exitDate.year}-${_exitDate.month.toString().padLeft(2, '0')}-${_exitDate.day.toString().padLeft(2, '0')}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          TextField(
            controller: _refundController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Deposit refunded'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(_ExitResult(
            exitDate: _exitDate,
            depositRefunded: double.tryParse(_refundController.text) ?? 0,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          )),
          child: const Text('Confirm exit'),
        ),
      ],
    );
  }
}
