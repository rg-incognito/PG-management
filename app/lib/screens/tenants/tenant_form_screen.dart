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
