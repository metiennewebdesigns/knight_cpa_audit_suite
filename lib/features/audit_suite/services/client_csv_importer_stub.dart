// lib/features/audit_suite/services/client_csv_importer_stub.dart

class ClientCsvRow {
  final String name;
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String zip;

  const ClientCsvRow({
    required this.name,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.zip,
  });
}

class ClientCsvImporter {
  static List<ClientCsvRow> parse(String csvText) {
    final lines = csvText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return const [];

    final first = _parseCsvLine(lines.first);
    final hasHeader = first.map((s) => s.toLowerCase()).contains('name');

    int idxName = 0, idxLine1 = 1, idxLine2 = 2, idxCity = 3, idxState = 4, idxZip = 5;

    int startRow = 0;
    if (hasHeader) {
      final header = first.map((s) => s.toLowerCase().trim()).toList();
      idxName = header.indexOf('name');
      idxLine1 = header.indexOf('line1');
      idxLine2 = header.indexOf('line2');
      idxCity = header.indexOf('city');
      idxState = header.indexOf('state');
      idxZip = header.indexOf('zip');

      if (idxLine1 < 0) idxLine1 = header.indexOf('address1');
      if (idxLine2 < 0) idxLine2 = header.indexOf('address2');
      if (idxZip < 0) idxZip = header.indexOf('postal');
      if (idxZip < 0) idxZip = header.indexOf('zipcode');

      startRow = 1;
    }

    String col(List<String> row, int idx) {
      if (idx < 0 || idx >= row.length) return '';
      return row[idx].trim();
    }

    final out = <ClientCsvRow>[];
    for (int i = startRow; i < lines.length; i++) {
      final row = _parseCsvLine(lines[i]);
      if (row.isEmpty) continue;

      final name = col(row, idxName);
      if (name.isEmpty) continue;

      out.add(
        ClientCsvRow(
          name: name,
          line1: col(row, idxLine1),
          line2: col(row, idxLine2),
          city: col(row, idxCity),
          state: col(row, idxState),
          zip: col(row, idxZip),
        ),
      );
    }

    return out;
  }

  static List<String> _parseCsvLine(String line) {
    final out = <String>[];
    final b = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          b.write('"');
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }

      if (ch == ',' && !inQuotes) {
        out.add(b.toString());
        b.clear();
        continue;
      }

      b.write(ch);
    }

    out.add(b.toString());
    return out;
  }

  static Future<String> readFileText(String path) async {
    throw UnsupportedError('CSV file reading is disabled on web demo.');
  }
}