import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class PdfActions {
  static Future<void> viewPdfFromUrl(String url) async {
    final bytes = await _fetchPdfBytes(url);
    await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
  }

  static Future<String> downloadPdfFromUrl({
    required String url,
    required String fileName,
  }) async {
    final bytes = await _fetchPdfBytes(url);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<List<int>> _fetchPdfBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch PDF (status: ${response.statusCode})');
    }
    return response.bodyBytes;
  }
}
