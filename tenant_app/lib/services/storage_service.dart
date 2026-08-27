import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Explicit contentType, since automatic detection from the file extension
  // isn't always reliable — and the security rules check contentType, so an
  // ambiguous one silently fails as "unauthorized" rather than a clear error.
  static final _imageMetadata = SettableMetadata(contentType: 'image/jpeg');

  // putData (raw bytes) instead of putFile: putFile drives Storage's
  // resumable-upload protocol, which on some devices got stuck reusing a
  // dead upload session and kept failing with a permission error even
  // against wide-open rules. putData uses the simpler direct-upload path
  // for files this size, sidestepping that.
  Future<String> uploadReceipt(String pgId, String tenantId, String month, File file) async {
    final ref = _storage.ref('payment_claim_receipts/$pgId/$tenantId/$month-${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(await file.readAsBytes(), _imageMetadata);
    return ref.getDownloadURL();
  }

  Future<String> uploadTenantDocument(String pgId, String tenantId, File file) async {
    final ref = _storage.ref('tenant_docs/$pgId/$tenantId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(await file.readAsBytes(), _imageMetadata);
    return ref.getDownloadURL();
  }
}
