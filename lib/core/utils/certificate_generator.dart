import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class CertificateGenerator {
  static Future<File> generateDonorCertificate({
    required String donorName,
    required String bloodGroup,
    required int donationCount,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900, width: 10),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'LifeStream AI',
                  style: pw.TextStyle(
                    fontSize: 40,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'CERTIFICATE OF HEROISM',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'This is to proudly certify that',
                  style: const pw.TextStyle(fontSize: 18),
                ),
                pw.SizedBox(height: 15),
                pw.Text(
                  donorName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Text(
                  'has successfully donated blood and helped save lives.',
                  style: const pw.TextStyle(fontSize: 18),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('Blood Group: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text(bloodGroup, style: const pw.TextStyle(fontSize: 16, color: PdfColors.red800)),
                    pw.SizedBox(width: 40),
                    pw.Text('Total Donations: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('$donationCount', style: const pw.TextStyle(fontSize: 16)),
                  ],
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 14)),
                        pw.Container(width: 150, height: 1, color: PdfColors.black),
                        pw.Text('Date', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('LifeStream AI Board', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 14)),
                        pw.Container(width: 150, height: 1, color: PdfColors.black),
                        pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('\${output.path}/LifeStream_Hero_Certificate.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
