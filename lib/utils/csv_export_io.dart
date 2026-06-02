import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> exportCsvFile(String filename, List<int> bytes) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'CSV 저장',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['csv'],
    bytes: Uint8List.fromList(bytes),
  );
}
