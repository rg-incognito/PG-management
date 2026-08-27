import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Explicit contentType, since automatic detection from the file extension
  // isn't always reliable — and the security rules check contentType, so an
  // ambiguous one silently fails as "unauthorized" rather than a clear error.
  static final _imageMetadata = SettableMetadata(contentType: 'image/jpeg');

  Future<String> uploadReceipt(String pgId, String tenantId, String month, File file) async {
    final ref = _storage.ref('payment_claim_receipts/$pgId/$tenantId/$month-${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file, _imageMetadata);
    return ref.getDownloadURL();
  }

  Future<String> uploadTenantDocument(String pgId, String tenantId, File file) async {
    final ref = _storage.ref('tenant_docs/$pgId/$tenantId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file, _imageMetadata);
    return ref.getDownloadURL();
  }
}
