/// Best-effort parser for a photographed multi-employee shift roster
/// (排班表：日期欄 × 員工列的表格，格子是「0700-1500」這種時間區間，或「-」
/// 代表休假)。
///
/// 主要路徑用 ML Kit `RecognizedText` 裡每一行的座標（`TextLine.boundingBox`）
/// 重建表格的行列關係——實測發現 OCR 常常把表格每一格都拆成獨立一行，而且
/// 文字出現的順序是亂的（表頭 7 個日期可能各自一行、順序也不是由左到右），
/// 純文字猜測法在這種輸入上幾乎沒用。座標資訊是唯一還原得了「哪些格子在同
/// 一列、哪一欄對應哪個日期」的線索。
///
/// 完全找不到座標可用時（或座標分群找不到表頭）才退回 [parseRosterTable]
/// 這個純文字版本當備援。不管走哪條路徑，RosterReviewPage 都是正確性的
/// 最後防線——這裡只負責給一個「大概是這樣」的初始猜測，永遠要讓使用者能
/// 編輯校正，不能直接拿去寫入資料庫。
library;

import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

final _dateToken = RegExp(r'(\d{1,2})[/\-](\d{1,2})');
final _cellToken = RegExp(r'(\d{3,4})\s*[-–~]\s*(\d{3,4})|([-–—])');

const _stopWords = [
  '預估', 'PSD', '合計', '工時', '最低標準', '差異', '提醒',
  '角色', '員工姓名', '代班', '特休', '備註', '排班表', '核印',
];

class RosterRowGuess {
  final String employeeName;
  /// 一格對應一個日期欄：`null` 代表看起來是休假或沒抓到東西，
  /// 有值時是 "HHmm-HHmm" 格式的原始猜測，交給校正畫面顯示/編輯。
  final List<String?> cells;

  const RosterRowGuess({required this.employeeName, required this.cells});
}

class RosterTableGuess {
  final List<DateTime> dates;
  final List<RosterRowGuess> rows;

  const RosterTableGuess({required this.dates, required this.rows});
}

// ── 座標分群（主路徑）───────────────────────────────────────────────────────

class _PositionedLine {
  final String text;
  final Rect box;
  const _PositionedLine(this.text, this.box);
}

class _DateHit {
  final DateTime date;
  final Rect box;
  const _DateHit(this.date, this.box);
  double get x => box.center.dx;
}

/// 依 Y 軸區間是否重疊分群（同一列的姓名跟時間格常常因為字型高度/基準線
/// 不同而中心點對不齊，用區間重疊比固定容忍值的中心點距離穩）。輸入需先
/// 依 top 排序過。
List<List<T>> _clusterByYOverlap<T>(List<T> sortedByTop, Rect Function(T) boxOf) {
  final clusters = <List<T>>[];
  for (final item in sortedByTop) {
    if (clusters.isNotEmpty) {
      final cluster = clusters.last;
      final top = cluster.map((c) => boxOf(c).top).reduce((a, b) => a < b ? a : b);
      final bottom = cluster.map((c) => boxOf(c).bottom).reduce((a, b) => a > b ? a : b);
      if (boxOf(item).top < bottom && boxOf(item).bottom > top) {
        cluster.add(item);
        continue;
      }
    }
    clusters.add([item]);
  }
  return clusters;
}

/// [referenceYear] 因為表頭通常只有月/日沒有年份，預設用今年，校正畫面要能改。
RosterTableGuess parseRosterTableFromRecognizedText(
  RecognizedText recognized, {
  int? referenceYear,
}) {
  final year = referenceYear ?? DateTime.now().year;
  final lines = <_PositionedLine>[
    for (final block in recognized.blocks)
      for (final line in block.lines) _PositionedLine(line.text, line.boundingBox),
  ];

  final guess = _clusterGeometry(lines, year);
  if (guess.dates.isNotEmpty) return guess;
  // 座標分群完全找不到表頭日期，退回純文字版本，不要就這樣回傳空表格。
  return parseRosterTable(recognized.text, referenceYear: referenceYear);
}

RosterTableGuess _clusterGeometry(List<_PositionedLine> lines, int year) {
  // 找出所有含日期 token 的行。
  final dateHits = <_DateHit>[];
  for (final line in lines) {
    final m = _dateToken.firstMatch(line.text);
    if (m == null) continue;
    final month = int.parse(m.group(1)!);
    final day = int.parse(m.group(2)!);
    try {
      dateHits.add(_DateHit(DateTime(year, month, day), line.box));
    } catch (_) {
      continue; // 月/日超出範圍，OCR 誤讀，跳過
    }
  }
  if (dateHits.isEmpty) return const RosterTableGuess(dates: [], rows: []);

  // 表頭常常被拆成好幾行、順序也亂——用 Y 區間分群，取最大群當表頭，群內
  // 再依 X 排序還原正確的左到右欄位順序（信任座標，不信任文字出現順序）。
  final dateHitsByTop = List.of(dateHits)..sort((a, b) => a.box.top.compareTo(b.box.top));
  final dateGroups = _clusterByYOverlap(dateHitsByTop, (h) => h.box);
  final headerCluster = dateGroups.reduce((a, b) => a.length >= b.length ? a : b);
  final headerSorted = List.of(headerCluster)..sort((a, b) => a.x.compareTo(b.x));

  final dates = headerSorted.map((h) => h.date).toList();
  final dateColX = headerSorted.map((h) => h.x).toList();
  final headerBottom = headerCluster.map((h) => h.box.bottom).reduce((a, b) => a > b ? a : b);

  double avgSpacing = 100;
  if (dateColX.length >= 2) {
    var totalGap = 0.0;
    for (var i = 1; i < dateColX.length; i++) {
      totalGap += dateColX[i] - dateColX[i - 1];
    }
    avgSpacing = totalGap / (dateColX.length - 1);
  }
  // 第一個日期欄實際的左邊界，左邊全部算「標籤區」（角色欄 + 姓名欄都在
  // 這裡，源表格常常是兩欄），不要用猜出來的虛擬欄寬去切——猜錯會讓真正
  // 的姓名反而比較靠近第一個日期欄，被判成日期資料而不是姓名。
  final labelZoneRight = headerSorted.first.box.left;

  // 表頭以外、而且要在表頭「下面」（Y 大於表頭）的行才是表格本體——店號/
  // 店名/列印日期這些表頭上方的行雖然沒跟表頭同一 Y 帶重疊，但也不是員工
  // 列，之前只排除「重疊表頭」漏掉了這些。
  final bodyLines = lines.where((l) => l.box.top >= headerBottom).toList()
    ..sort((a, b) => a.box.top.compareTo(b.box.top));
  final rowClusters = _clusterByYOverlap(bodyLines, (l) => l.box);

  final rows = <RosterRowGuess>[];
  for (final cluster in rowClusters) {
    final rowText = cluster.map((l) => l.text).join(' ');
    if (_stopWords.any((w) => rowText.contains(w))) continue;

    final sortedCluster = List.of(cluster)..sort((a, b) => a.box.left.compareTo(b.box.left));
    final nameParts = <String>[];
    final cellParts = List<List<String>>.generate(dates.length, (_) => []);

    for (final line in sortedCluster) {
      final x = line.box.center.dx;
      if (x < labelZoneRight) {
        // 標籤區：角色欄（PT/PM/P/PI 這種純英文代碼）跟姓名欄都會落在
        // 這裡，只留有非英數字元（中文姓名）的片段，把角色代碼濾掉。
        if (RegExp(r'[^\x00-\x7F]').hasMatch(line.text)) {
          nameParts.add(line.text);
        }
        continue;
      }
      var nearestIdx = 0;
      var nearestDist = (x - dateColX[0]).abs();
      for (var i = 1; i < dateColX.length; i++) {
        final d = (x - dateColX[i]).abs();
        if (d < nearestDist) {
          nearestDist = d;
          nearestIdx = i;
        }
      }
      // 日期欄要套距離篩選，用來濾掉代班/特休/備註/合計等尾端彙總欄位。
      if (nearestDist <= avgSpacing * 0.6) {
        cellParts[nearestIdx].add(line.text);
      }
    }

    final name = nameParts.join('').trim();
    if (name.isEmpty) continue;

    final cells = List<String?>.filled(dates.length, null);
    for (var col = 0; col < dates.length; col++) {
      if (cellParts[col].isEmpty) continue;
      final m = _cellToken.firstMatch(cellParts[col].join(' '));
      if (m == null) continue;
      cells[col] = m.group(3) != null ? null : '${m.group(1)}-${m.group(2)}';
    }

    rows.add(RosterRowGuess(employeeName: name, cells: cells));
  }

  return RosterTableGuess(dates: dates, rows: rows);
}

// ── 純文字備援（座標完全用不了時才會走到這裡）─────────────────────────────

/// [referenceYear] 因為表頭通常只有月/日沒有年份，預設用今年，校正畫面要能改。
RosterTableGuess parseRosterTable(String rawText, {int? referenceYear}) {
  final year = referenceYear ?? DateTime.now().year;
  final lines = rawText
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // 找表頭行：日期 token 數量最多的那一行，決定欄數跟各欄日期。
  int headerIndex = -1;
  List<DateTime> dates = [];
  for (var i = 0; i < lines.length; i++) {
    final matches = _dateToken.allMatches(lines[i]).toList();
    if (matches.length < 2 || matches.length <= dates.length) continue;
    headerIndex = i;
    dates = matches.map((m) {
      final month = int.parse(m.group(1)!);
      final day = int.parse(m.group(2)!);
      try {
        return DateTime(year, month, day);
      } catch (_) {
        return DateTime(year, 1, 1);
      }
    }).toList();
  }

  final rows = <RosterRowGuess>[];
  for (var i = 0; i < lines.length; i++) {
    if (i == headerIndex || dates.isEmpty) continue;
    final line = lines[i];
    if (_stopWords.any((w) => line.contains(w))) continue;

    // 姓名跟班次資料的分界：第一個數字或「-」（休假格常常整列都是「-」，
    // 前面完全沒有數字，所以不能只找第一個數字）。
    final firstCellChar = line.indexOf(RegExp(r'[\d\-–—]'));
    if (firstCellChar <= 0) continue; // 沒有姓名部分，或整行從格子內容開頭，跳過
    final name = line.substring(0, firstCellChar).trim();
    if (name.isEmpty) continue;

    final cellMatches = _cellToken.allMatches(line.substring(firstCellChar)).toList();
    if (cellMatches.isEmpty) continue; // 完全沒抓到班次資訊，八成不是員工列

    final cells = List<String?>.filled(dates.length, null);
    for (var col = 0; col < dates.length && col < cellMatches.length; col++) {
      final m = cellMatches[col];
      cells[col] = m.group(3) != null ? null : '${m.group(1)}-${m.group(2)}';
    }

    rows.add(RosterRowGuess(employeeName: name, cells: cells));
  }

  return RosterTableGuess(dates: dates, rows: rows);
}
