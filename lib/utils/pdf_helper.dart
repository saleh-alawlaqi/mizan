import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// ملف مشترك لتوليد ملفات PDF بستايل موحّد لكل شاشات التطبيق
/// (نفس الألوان، نفس شكل الجداول، نفس الترويسة والتذييل)
class PdfHelper {
  static final PdfColor headerColor = PdfColor.fromInt(0xFF086591);
  static final PdfColor altRowColor = PdfColor.fromInt(0xFFF3F6F9);
  static final PdfColor lightBgColor = PdfColor.fromInt(0xFFE6F2F8);

  static Future<pw.Font> regularFont() => PdfGoogleFonts.cairoRegular();
  static Future<pw.Font> boldFont() => PdfGoogleFonts.cairoBold();

  /// جدول موحّد الستايل: رأس أزرق، صفوف متناوبة، حدود رفيعة
  static pw.Widget table({
    required pw.Font font,
    required pw.Font fontBold,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle:
          pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: headerColor),
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      oddRowDecoration: pw.BoxDecoration(color: altRowColor),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  /// كرت ملخص صغير (رقم + تسمية) يُستخدم أعلى أي تقرير
  static pw.Widget summaryCard(
      pw.Font font, pw.Font fontBold, String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
          color: lightBgColor, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text(value,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 14, color: headerColor)),
        ],
      ),
    );
  }

  /// يبني ملف PDF كامل بترويسة موحّدة وتذييل مرقّم، ويطبعه مباشرة
  static Future<void> buildAndPrint({
    required String title,
    required String fileName,
    required List<pw.Widget> Function(pw.Font font, pw.Font fontBold) content,
  }) async {
    final pdf = pw.Document();
    final font = await regularFont();
    final fontBold = await boldFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 18, color: headerColor)),
                  pw.Text(DateTime.now().toString().substring(0, 10),
                      style: pw.TextStyle(
                          font: font, fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
              pw.Divider(color: headerColor, thickness: 1.2),
            ],
          ),
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: content(font, fontBold)),
          ),
        ],
        footer: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
                'تطبيق ميزان - صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: pw.TextStyle(
                    font: font, fontSize: 9, color: PdfColors.grey600)),
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(), name: fileName);
  }
}
