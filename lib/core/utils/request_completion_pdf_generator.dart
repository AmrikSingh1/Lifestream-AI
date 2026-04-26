import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RequestCompletionPdfGenerator {
  static Future<List<int>> generateOfficialCompletionPdf({
    required String requestId,
    required String donorName,
    required String donorBloodGroup,
    required String recipientName,
    required String recipientPhone,
    required String bloodGroupRequested,
    required DateTime completedAt,
  }) async {
    final pdf = pw.Document();
    final dateText = DateFormat('dd MMM yyyy, hh:mm a').format(completedAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey900,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'LifeStream AI',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Blood Donation Verification Network',
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green700,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(4),
                          ),
                        ),
                        child: pw.Text(
                          'OFFICIAL RECORD',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Text(
                  'Official Donation Completion Record',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'This document certifies that a blood donation request has been completed and mutually confirmed by both donor and recipient.',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.blueGrey700),
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _row('Request ID', requestId),
                      _row('Completion Time', dateText),
                      _row('Status', 'Completed'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Donation Parties & Request Details',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 10),
                _row('Donor Name', donorName),
                _row('Donor Blood Group', donorBloodGroup),
                _row('Recipient Name', recipientName),
                _row('Recipient Phone', recipientPhone),
                _row('Requested Blood Group', bloodGroupRequested),
                pw.SizedBox(height: 18),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Compliance Note: This completion record is digitally generated by LifeStream AI and is intended for emergency-donation process documentation.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
                  ),
                ),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey500),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Issued by LifeStream AI',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.Text(
                          'Authorized Digital Certificate',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                        ),
                      ],
                    ),
                    pw.Text(
                      DateFormat('dd MMM yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }
}
