import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/receipt_data.dart';

enum ReceiptTemplate { classic, minimal, modern, compact, statement }

extension ReceiptTemplateInfo on ReceiptTemplate {
  String get label => switch (this) {
        ReceiptTemplate.classic => 'Classic',
        ReceiptTemplate.minimal => 'Minimal',
        ReceiptTemplate.modern => 'Modern',
        ReceiptTemplate.compact => 'Compact slip',
        ReceiptTemplate.statement => 'Statement',
      };

  String get description => switch (this) {
        ReceiptTemplate.classic => 'Bordered, formal layout with a signatory line.',
        ReceiptTemplate.minimal => 'Clean text-only layout, quick to read and share.',
        ReceiptTemplate.modern => 'Bold colored header banner.',
        ReceiptTemplate.compact => 'Narrow slip, like a printed till receipt.',
        ReceiptTemplate.statement => 'Detailed two-column statement with an itemized table.',
      };
}

// The base14 Helvetica font this package defaults to doesn't cover the ₹
// glyph, so amounts use "Rs." instead of ₹ to avoid it rendering as a blank
// box in the generated PDF.
String _money(double amount) => 'Rs. ${amount.toStringAsFixed(0)}';

class ReceiptBuilder {
  static Future<Uint8List> build(ReceiptTemplate template, ReceiptData data) async {
    final doc = pw.Document();
    switch (template) {
      case ReceiptTemplate.classic:
        doc.addPage(_classic(data));
      case ReceiptTemplate.minimal:
        doc.addPage(_minimal(data));
      case ReceiptTemplate.modern:
        doc.addPage(_modern(data));
      case ReceiptTemplate.compact:
        doc.addPage(_compact(data));
      case ReceiptTemplate.statement:
        doc.addPage(_statement(data));
    }
    return doc.save();
  }

  static pw.Page _classic(ReceiptData d) {
    return pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 1.2)),
        padding: const pw.EdgeInsets.all(20),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(d.pgName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(d.pgAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 10),
                  pw.Text('RENT RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Receipt No: ${d.receiptNumber}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Date: ${_fmtDate(d.paidDate)}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Divider(color: PdfColors.grey400),
            _classicRow('Received from', d.tenantName),
            _classicRow('Room / Bed', d.roomLabel),
            _classicRow('For the month of', d.monthLabel),
            _classicRow('Payment mode', d.paymentMode),
            if (d.penaltyApplied > 0) _classicRow('Late penalty', _money(d.penaltyApplied)),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total paid', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text(_money(d.total), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey700),
                    pw.SizedBox(height: 4),
                    pw.Text(d.ownerName ?? 'Authorized Signatory', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _classicRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Page _minimal(ReceiptData d) {
    return pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(d.pgName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(d.pgAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 24),
          pw.Text('Payment receipt', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(_money(d.total), style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 24),
          _minimalLine('Tenant', d.tenantName),
          _minimalLine('Room', d.roomLabel),
          _minimalLine('Month', d.monthLabel),
          _minimalLine('Mode', d.paymentMode),
          _minimalLine('Date', _fmtDate(d.paidDate)),
          _minimalLine('Receipt No.', d.receiptNumber),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            d.ownerName != null ? 'Issued by ${d.ownerName}' : 'Issued by ${d.pgName}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _minimalLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 90, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Page _modern(ReceiptData d) {
    return pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            color: PdfColors.indigo700,
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(d.pgName,
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text(d.pgAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.indigo100)),
                pw.SizedBox(height: 10),
                pw.Text('Rent Receipt', style: const pw.TextStyle(fontSize: 12, color: PdfColors.indigo100)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(d.tenantName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_money(d.total),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                  ],
                ),
                pw.SizedBox(height: 14),
                _modernChip('Room', d.roomLabel),
                _modernChip('Month', d.monthLabel),
                _modernChip('Mode', d.paymentMode),
                _modernChip('Date', _fmtDate(d.paidDate)),
                if (d.penaltyApplied > 0) _modernChip('Late penalty', _money(d.penaltyApplied)),
                pw.SizedBox(height: 20),
                pw.Text('Receipt No: ${d.receiptNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                if (d.ownerName != null)
                  pw.Text('Issued by: ${d.ownerName}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _modernChip(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Container(
            width: 6,
            height: 6,
            decoration: const pw.BoxDecoration(color: PdfColors.indigo700, shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 8),
          pw.Text('$label: ', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // Narrow, till-slip style — 80mm wide, height grows to fit content.
  static pw.Page _compact(ReceiptData d) {
    return pw.Page(
      pageFormat: const PdfPageFormat(226, double.infinity, marginAll: 12),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(d.pgName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          pw.Text(d.pgAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 8),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          pw.Text('RENT RECEIPT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          _compactLine('Tenant', d.tenantName),
          _compactLine('Room', d.roomLabel),
          _compactLine('Month', d.monthLabel),
          _compactLine('Mode', d.paymentMode),
          _compactLine('Date', _fmtDate(d.paidDate)),
          if (d.penaltyApplied > 0) _compactLine('Penalty', _money(d.penaltyApplied)),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.SizedBox(height: 6),
          pw.Text('TOTAL: ${_money(d.total)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('No. ${d.receiptNumber}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          if (d.ownerName != null)
            pw.Text(d.ownerName!, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _compactLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _dashedDivider() {
    return pw.Row(
      children: List.generate(
        30,
        (i) => pw.Expanded(child: pw.Container(height: 1, color: i.isEven ? PdfColors.grey500 : PdfColors.white)),
      ),
    );
  }

  static pw.Page _statement(ReceiptData d) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(d.pgName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(d.pgAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  if (d.ownerPhone != null)
                    pw.Text('Ph: ${d.ownerPhone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('RECEIPT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('No: ${d.receiptNumber}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Date: ${_fmtDate(d.paidDate)}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Tenant', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text(d.tenantName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Room / Bed', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text(d.roomLabel, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
            children: [
              _statementHeaderRow(),
              _statementRow('Rent for ${d.monthLabel} (${d.paymentMode})', _money(d.amount)),
              if (d.penaltyApplied > 0) _statementRow('Late payment penalty', _money(d.penaltyApplied)),
              _statementRow('Total', _money(d.total), bold: true),
            ],
          ),
          pw.SizedBox(height: 50),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'This is a computer-generated receipt.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.grey700),
                  pw.SizedBox(height: 4),
                  pw.Text(d.ownerName ?? 'Authorized Signatory', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.TableRow _statementHeaderRow() {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text('Description', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text('Amount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  static pw.TableRow _statementRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(label, style: style)),
        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(value, style: style)),
      ],
    );
  }

  static String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
