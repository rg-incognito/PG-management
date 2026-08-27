import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // putData (raw bytes) instead of putFile — putFile drives Storage's
  // resumable-upload protocol, which got stuck on some devices reusing a
  // dead upload session and kept failing with a permission error even
  // against wide-open rules. putData uses the simpler direct-upload path.
  Future<String> uploadPgQr(String pgId, File file) async {
    final ref = _storage.ref('pg_qr/$pgId/qr.jpg');
    await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
