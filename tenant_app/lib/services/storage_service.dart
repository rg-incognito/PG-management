import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadReceipt(String pgId, String tenantId, String month, File file) async {
    final ref = _storage.ref('payment_claim_receipts/$pgId/$tenantId/$month-${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<String> uploadTenantDocument(String pgId, String tenantId, File file) async {
    final ref = _storage.ref('tenant_docs/$pgId/$tenantId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
