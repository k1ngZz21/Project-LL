import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../features/content/local_vocabulary.dart';

/// The offline word-list PDF (learnlite.mdc Module A, "Dictionary PDF").
///
/// It is built on the device from the bundled workbook entries, so it needs
/// no download and adds nothing: every row shows the workbook's own text and
/// review status. Entries without a Subanen form are listed separately as
/// still needed, never filled in.
const vocabularyPdfPackId = 'vocabulary-pdf';
const vocabularyPdfResourceKey = 'learnlite-subanen-word-list.pdf';
const vocabularyPdfTitle = 'Subanen word list (PDF)';

/// The entries the PDF lists: those with a Subanen form (sorted by it), and
/// those the workbooks still need a form for.
({List<LocalVocabularyEntry> withForm, List<LocalVocabularyEntry> stillNeeded})
vocabularyPdfSections(LocalVocabularyCatalog catalog) {
  final all = [
    ...catalog.vocabulary,
    ...catalog.starterList,
    ...catalog.stillNeeded,
  ];
  return (
    withForm: all.where((entry) => !entry.needsSubanenForm).toList()
      ..sort(
        (a, b) => a.subanen.toLowerCase().compareTo(b.subanen.toLowerCase()),
      ),
    stillNeeded: all.where((entry) => entry.needsSubanenForm).toList(),
  );
}

Future<Uint8List> buildVocabularyPdf(
  LocalVocabularyCatalog catalog, {
  DateTime? generatedAt,
}) async {
  final date = (generatedAt ?? DateTime.now()).toLocal();
  final dateText =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final (:withForm, :stillNeeded) = vocabularyPdfSections(catalog);

  final verifiedCount = withForm
      .where((entry) => entry.reviewStatus.toLowerCase() == 'verified')
      .length;

  final document = pw.Document(
    title: 'LearnLite Subanen word list',
    author: 'LearnLite',
    subject: 'Workbook vocabulary, pending review',
  );
  const header = pw.TextStyle(fontSize: 9, color: PdfColors.white);
  const cell = pw.TextStyle(fontSize: 8.5);
  final accent = PdfColor.fromHex('#B3202A');

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Text(
              'LearnLite · Subanen word list (pending review)',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Text(
          'LearnLite Subanen word list',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Made on this device on $dateText from the LearnLite workbooks: '
          '${withForm.length} entries with a Subanen form, '
          '$verifiedCount verified.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: accent, width: 0.8),
          ),
          child: pw.Text(
            'Entries marked "Pending review" have not yet been checked by a '
            'fluent Subanen speaker. Use them for study, not as verified '
            'translations. Forms and dialects are given as recorded in the '
            'workbooks.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Subanen',
            'English',
            'Cebuano / Bisaya',
            'Topic',
            'Status',
          ],
          data: [
            for (final entry in withForm)
              [
                entry.alternateForms.trim().isEmpty
                    ? entry.subanen.trim()
                    : '${entry.subanen.trim()} (also: '
                          '${entry.alternateForms.trim()})',
                entry.english.trim(),
                entry.bisaya.trim(),
                entry.category,
                entry.reviewStatus.trim().isEmpty
                    ? 'Pending review'
                    : entry.reviewStatus.trim(),
              ],
          ],
          headerStyle: header,
          headerDecoration: pw.BoxDecoration(color: accent),
          cellStyle: cell,
          cellAlignment: pw.Alignment.topLeft,
          headerAlignment: pw.Alignment.centerLeft,
          columnWidths: const {
            0: pw.FlexColumnWidth(2.2),
            1: pw.FlexColumnWidth(2.2),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FlexColumnWidth(1.6),
            4: pw.FlexColumnWidth(1.2),
          },
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
          ),
        ),
        if (stillNeeded.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          pw.Text(
            'Still needed (${stillNeeded.length})',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'The workbooks list these meanings without a Subanen form yet. '
            'They are left blank on purpose.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['English', 'Cebuano / Bisaya', 'Topic'],
            data: [
              for (final entry in stillNeeded)
                [entry.english.trim(), entry.bisaya.trim(), entry.category],
            ],
            headerStyle: header,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
            cellStyle: cell,
            cellAlignment: pw.Alignment.topLeft,
            headerAlignment: pw.Alignment.centerLeft,
          ),
        ],
        pw.SizedBox(height: 14),
        pw.Text(
          'Sources: LearnLite-Subanen-Vocabulary.xlsx and '
          'Subanen_Vocabulary_Starter_List.xlsx (project workbooks).',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ),
  );
  return document.save();
}
