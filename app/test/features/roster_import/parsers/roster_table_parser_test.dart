import 'dart:ui';

import 'package:app/features/roster_import/parsers/roster_table_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

TextLine _line(String text, Rect box) => TextLine(
      text: text,
      elements: const [],
      boundingBox: box,
      recognizedLanguages: const [],
      cornerPoints: const [],
      confidence: null,
      angle: null,
    );

TextBlock _block(List<TextLine> lines) => TextBlock(
      text: lines.map((l) => l.text).join('\n'),
      lines: lines,
      boundingBox: lines.first.boundingBox,
      recognizedLanguages: const [],
      cornerPoints: const [],
    );

void main() {
  test('座標分群：表頭順序打亂、姓名欄較寬、cell 被拆成兩行、尾端雜訊欄都能正確處理', () {
    final lines = <TextLine>[
      // 表頭日期，刻意打亂順序（模擬 OCR 實際輸出），parser 要信任 X 座標，
      // 不是文字/行出現的順序。
      _line('07/19(日)', const Rect.fromLTWH(700, 90, 60, 20)),
      _line('07/13(一)', const Rect.fromLTWH(100, 95, 60, 20)),
      _line('07/14(二)', const Rect.fromLTWH(200, 92, 60, 20)),
      _line('07/15(三)', const Rect.fromLTWH(300, 90, 60, 20)),
      _line('07/16(四)', const Rect.fromLTWH(400, 93, 60, 20)),
      _line('07/17(五)', const Rect.fromLTWH(500, 91, 60, 20)),
      _line('07/18(六)', const Rect.fromLTWH(600, 90, 60, 20)),

      // 第一位員工：姓名欄比日期欄寬、跟同一列格子的 Y 中心點沒對齊（測 Y 區間
      // 重疊而不是中心點距離），07/13 那格被拆成兩個 TextLine。
      _line('珮甄', const Rect.fromLTWH(0, 175, 80, 30)),
      _line('0700-', const Rect.fromLTWH(90, 200, 30, 20)),
      _line('1500', const Rect.fromLTWH(125, 200, 30, 20)),
      _line('-', const Rect.fromLTWH(190, 200, 20, 20)), // 07/14 休假
      _line('0700-1500', const Rect.fromLTWH(290, 200, 60, 20)), // 07/15
      // 尾端彙總欄位（代班/特休/合計），X 遠超過最後一欄，不該被當成 07/18 的資料
      _line('0.0', const Rect.fromLTWH(850, 200, 20, 20)),

      // 第二位員工，測多列都能分開處理
      _line('昇平', const Rect.fromLTWH(5, 260, 60, 20)),
      _line('1500-2300', const Rect.fromLTWH(390, 260, 70, 20)), // 07/16

      // 應該被整列跳過的彙總列
      _line('合計工時 32.0 44.0', const Rect.fromLTWH(0, 320, 200, 20)),
    ];

    final recognized = RecognizedText(
      text: lines.map((l) => l.text).join('\n'),
      blocks: [_block(lines)],
    );

    final guess = parseRosterTableFromRecognizedText(recognized, referenceYear: 2026);

    expect(guess.dates.length, 7);
    expect(
      guess.dates.map((d) => '${d.month}/${d.day}').toList(),
      ['7/13', '7/14', '7/15', '7/16', '7/17', '7/18', '7/19'],
    );

    final peiJhen = guess.rows.firstWhere((r) => r.employeeName == '珮甄');
    expect(peiJhen.cells[0], '0700-1500'); // 07/13，兩行合併
    expect(peiJhen.cells[1], isNull); // 07/14 休假
    expect(peiJhen.cells[2], '0700-1500'); // 07/15
    expect(peiJhen.cells[6], isNull); // 07/18：尾端雜訊沒有污染這一欄

    final shengPing = guess.rows.firstWhere((r) => r.employeeName == '昇平');
    expect(shengPing.cells[3], '1500-2300'); // 07/16

    expect(guess.rows.any((r) => r.employeeName.contains('合計')), isFalse);
  });

  test('完全沒有座標可用時，退回純文字解析', () {
    const rawText = '07/13(一) 07/14(二)\n小明 0700-1500 -\n';
    final recognized = RecognizedText(text: rawText, blocks: const []);

    final guess = parseRosterTableFromRecognizedText(recognized, referenceYear: 2026);

    expect(guess.dates.length, 2);
    expect(guess.rows.single.employeeName, '小明');
    expect(guess.rows.single.cells, ['0700-1500', null]);
  });
}
