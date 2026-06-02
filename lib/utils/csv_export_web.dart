// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> exportCsvFile(String filename, List<int> bytes) async {
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
