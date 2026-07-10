/// Best-effort parser for a photographed multi-employee shift roster
/// (排班表：日期欄 × 員工列的表格，格子是「0700-1500」這種時間區間，或「-」
/// 代表休假)。
///
/// OCR（`bank_notify` 那套 `TextRecognizer`）只回傳一整串攤平的文字，沒有座標
/// 資訊，所以這裡完全沒有真正的表格幾何可以依靠——只能用「逐行讀、把行裡依序
/// 出現的時間區間/裸「-」對應到日期欄」這種猜測法。任何一行只要 OCR 斷詞方式
/// 跟表頭行不一樣，欄位就可能對不齊。RosterReviewPage 才是正確性的最後防線，
/// 這個函式只負責給一個「大概是這樣」的初始猜測，永遠要讓使用者能編輯校正，
/// 不能直接拿去寫入資料庫。
library;

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
