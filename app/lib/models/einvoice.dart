class EinvoiceImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const EinvoiceImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });

  factory EinvoiceImportResult.fromJson(Map<String, dynamic> json) => EinvoiceImportResult(
        imported: json['imported'] as int,
        skipped: json['skipped'] as int,
        errors: (json['errors'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      );
}
