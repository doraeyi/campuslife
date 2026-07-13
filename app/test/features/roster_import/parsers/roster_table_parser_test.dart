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
  test('座標分群：表頭順序打亂、角色+姓名兩欄、cell 被拆成兩行、表頭上下的雜訊都能正確處理', () {
    final lines = <TextLine>[
      // 表頭「上面」的文件標題/店號列——之前只排除跟表頭同一 Y 帶重疊的行，
      // 沒排除表頭上方的行，導致這種列被誤判成員工列。
      _line('店號:991458 店名:八里', const Rect.fromLTWH(0, 20, 200, 20)),

      // 表頭日期，刻意打亂順序（模擬 OCR 實際輸出），parser 要信任 X 座標，
      // 不是文字/行出現的順序。
      _line('07/19(日)', const Rect.fromLTWH(700, 90, 60, 20)),
      _line('07/13(一)', const Rect.fromLTWH(100, 95, 60, 20)),
      _line('07/14(二)', const Rect.fromLTWH(200, 92, 60, 20)),
      _line('07/15(三)', const Rect.fromLTWH(300, 90, 60, 20)),
      _line('07/16(四)', const Rect.fromLTWH(400, 93, 60, 20)),
      _line('07/17(五)', const Rect.fromLTWH(500, 91, 60, 20)),
      _line('07/18(六)', const Rect.fromLTWH(600, 90, 60, 20)),

      // 第一位員工：來源表格「角色」跟「員工姓名」是兩個獨立欄位，角色欄
      // （PT）比姓名欄更靠左，姓名欄跟同一列格子的 Y 中心點沒對齊（測 Y
      // 區間重疊而不是中心點距離），07/13 那格被拆成兩個 TextLine。
      _line('PT', const Rect.fromLTWH(0, 200, 20, 20)),
      _line('珮甄', const Rect.fromLTWH(30, 175, 60, 30)),
      _line('0700-', const Rect.fromLTWH(90, 200, 30, 20)),
      _line('1500', const Rect.fromLTWH(125, 200, 30, 20)),
      _line('-', const Rect.fromLTWH(190, 200, 20, 20)), // 07/14 休假
      _line('0700-1500', const Rect.fromLTWH(290, 200, 60, 20)), // 07/15
      // 尾端彙總欄位（代班/特休/合計），X 遠超過最後一欄，不該被當成 07/18 的資料
      _line('0.0', const Rect.fromLTWH(850, 200, 20, 20)),

      // 第二位員工，姓名前面黏著表格框線被誤判成的雜訊字元「|」，測濾除
      // 雜訊只留中文字元。
      _line('PT', const Rect.fromLTWH(0, 260, 20, 20)),
      _line('|昇平', const Rect.fromLTWH(30, 260, 60, 20)),
      _line('1500-2300', const Rect.fromLTWH(390, 260, 70, 20)), // 07/16

      // 第三位員工，Y 範圍跟上一列完全沒有重疊——測分群不會因為之前用「整
      // 群邊界」比對而把這種明顯是不同列的行誤併進去（改成跟群裡實際存在
      // 的行個別比對之後才修好的那個 bug）。
      _line('PT', const Rect.fromLTWH(0, 285, 20, 20)),
      _line('俊佑', const Rect.fromLTWH(30, 285, 60, 20)),
      _line('1500-2300', const Rect.fromLTWH(390, 285, 70, 20)), // 07/16

      // 應該被整列跳過的彙總列
      _line('合計工時 32.0 44.0', const Rect.fromLTWH(0, 340, 200, 20)),
    ];

    final recognized = RecognizedText(
      text: lines.map((l) => l.text).join('\n'),
      blocks: [_block(lines)],
    );

    final guess =
        parseRosterTableFromRecognizedText(recognized, referenceYear: 2026);

    expect(guess.dates.length, 7);
    expect(
      guess.dates.map((d) => '${d.month}/${d.day}').toList(),
      ['7/13', '7/14', '7/15', '7/16', '7/17', '7/18', '7/19'],
    );

    // 三個真正的員工列都要分開——表頭上方的店號列、角色欄的「PT」代碼、
    // 彙總列都不該冒出額外的列，第二、三位員工也不該被誤併成同一列。
    expect(guess.rows.length, 3);

    final peiJhen = guess.rows.firstWhere((r) => r.employeeName == '珮甄');
    expect(peiJhen.cells[0], '0700-1500'); // 07/13，兩行合併
    expect(peiJhen.cells[1], isNull); // 07/14 休假
    expect(peiJhen.cells[2], '0700-1500'); // 07/15
    expect(peiJhen.cells[6], isNull); // 07/18：尾端雜訊沒有污染這一欄

    final shengPing = guess.rows.firstWhere((r) => r.employeeName == '昇平');
    expect(shengPing.cells[3], '1500-2300'); // 07/16，姓名前的「|」雜訊被濾掉

    final junYou = guess.rows.firstWhere((r) => r.employeeName == '俊佑');
    expect(junYou.cells[3], '1500-2300'); // 07/16，跟「昇平」那一列沒有被併在一起

    expect(guess.rows.any((r) => r.employeeName.contains('合計')), isFalse);
  });

  test('列的分界只看姓名行，密集的格子資料不會讓兩個人被併成同一列', () {
    // 這是真實照片踩到的那個 bug 的最小重現：兩個人的姓名行 Y 範圍緊貼在
    // 一起（3px 間隔，沒有重疊），中間夾了一堆密集的格子資料——姓名分群
    // 現在只看姓名行本身，不會被格子的密度影響。
    final lines = <TextLine>[
      _line('07/13(一)', const Rect.fromLTWH(100, 90, 60, 20)),
      _line('07/14(二)', const Rect.fromLTWH(200, 90, 60, 20)),

      _line('育傑', const Rect.fromLTWH(20, 150, 60, 20)), // top=150, bottom=170
      _line('0700-1500', const Rect.fromLTWH(90, 150, 60, 20)),
      _line('1500-2300', const Rect.fromLTWH(190, 150, 60, 20)),
      _line('0.0', const Rect.fromLTWH(90, 165, 20, 15)),
      _line('0.0', const Rect.fromLTWH(190, 165, 20, 15)),

      _line('彥彬', const Rect.fromLTWH(20, 173, 60, 20)), // top=173，跟上面只差 3px
      _line('1900-2300', const Rect.fromLTWH(90, 173, 60, 20)),
      _line('-', const Rect.fromLTWH(190, 173, 20, 20)),
    ];

    final recognized = RecognizedText(
      text: lines.map((l) => l.text).join('\n'),
      blocks: [_block(lines)],
    );

    final guess =
        parseRosterTableFromRecognizedText(recognized, referenceYear: 2026);

    expect(guess.rows.length, 2);
    final yuJie = guess.rows.firstWhere((r) => r.employeeName == '育傑');
    expect(yuJie.cells[0], '0700-1500');
    expect(yuJie.cells[1], '1500-2300');
    final yenBin = guess.rows.firstWhere((r) => r.employeeName == '彥彬');
    expect(yenBin.cells[0], '1900-2300');
    expect(yenBin.cells[1], isNull);
  });

  test('拍照角度造成表頭被拆成兩個 Y 群組時，兩群都要收進表頭，不能只留最大群', () {
    // 真實照片踩到的 bug：透視變形讓表頭 7 個日期裡有 2 個的 Y 座標跟其他
    // 5 個有落差，形成兩個不重疊的 Y 群組。舊邏輯只取「最大群」，另一群的
    // 2 個日期會直接消失（實測真的發生過一次少兩天）。
    final lines = <TextLine>[
      _line('07/13(一)', const Rect.fromLTWH(100, 90, 60, 20)),
      _line('07/14(二)', const Rect.fromLTWH(200, 90, 60, 20)),
      _line('07/16(四)', const Rect.fromLTWH(400, 90, 60, 20)),
      _line('07/17(五)', const Rect.fromLTWH(500, 90, 60, 20)),
      _line('07/19(日)', const Rect.fromLTWH(700, 90, 60, 20)),
      // 這兩欄因為透視變形被 OCR 判在稍微低一點的 Y 位置，跟上面 5 個沒有
      // Y 重疊（top=112 >= 主群 bottom=110），會被分到不同的群組。
      _line('07/15(三)', const Rect.fromLTWH(300, 112, 60, 20)),
      _line('07/18(六)', const Rect.fromLTWH(600, 112, 60, 20)),

      _line('小明', const Rect.fromLTWH(20, 200, 60, 20)),
      _line('0700-1500', const Rect.fromLTWH(290, 200, 60, 20)), // 07/15
    ];

    final recognized = RecognizedText(
      text: lines.map((l) => l.text).join('\n'),
      blocks: [_block(lines)],
    );

    final guess =
        parseRosterTableFromRecognizedText(recognized, referenceYear: 2026);

    expect(
      guess.dates.map((d) => '${d.month}/${d.day}').toList(),
      ['7/13', '7/14', '7/15', '7/16', '7/17', '7/18', '7/19'],
    );
    final xiaoMing = guess.rows.firstWhere((r) => r.employeeName == '小明');
    expect(xiaoMing.cells[2], '0700-1500'); // 07/15 那一欄要對得到
  });

  test('欄距因透視變形不平均時，最外側欄位(六、日)的格子改用鄰欄實際距離判斷容忍度，不會被誤判成雜訊丟掉', () {
    // 真實照片常踩到的狀況：拍照角度造成透視變形，表格最後一欄(日)跟前一
    // 欄的間距比其他欄寬(150 vs 100)。舊邏輯用「整張表格的平均欄寬」算
    // 容忍度，這欄的格子因為變形多偏了一點，距離超過用平均值算出來的門檻
    // 就被當雜訊丟棄——看起來就像「六、日明明有排班卻沒辨識出來」。改成
    // 看這欄自己跟鄰欄的實際距離之後，這種因變形被拉開的欄位才留得住。
    final lines = <TextLine>[
      _line('07/13(一)', const Rect.fromLTWH(100, 90, 60, 20)),
      _line('07/14(二)', const Rect.fromLTWH(200, 90, 60, 20)),
      _line('07/15(三)', const Rect.fromLTWH(300, 90, 60, 20)),
      _line('07/16(四)', const Rect.fromLTWH(400, 90, 60, 20)),
      _line('07/17(五)', const Rect.fromLTWH(500, 90, 60, 20)),
      _line('07/18(六)', const Rect.fromLTWH(600, 90, 60, 20)),
      // 透視變形讓最後一欄(日)離前一欄的間距比其他欄寬(150 對 100)。
      _line('07/19(日)', const Rect.fromLTWH(750, 90, 60, 20)),

      _line('小明', const Rect.fromLTWH(20, 200, 60, 20)),
      // 這格中心點(710)離 07/19 欄中心(780)有 70px：用整張表格的平均欄寬
      // (≈108.3)算容忍度只有 65，會被丟掉；改成看 07/19 欄自己跟左鄰欄
      // (07/18)的實際距離(150)算，容忍度 90 才留得住。
      _line('0700-1500', const Rect.fromLTWH(680, 200, 60, 20)),
    ];

    final recognized = RecognizedText(
      text: lines.map((l) => l.text).join('\n'),
      blocks: [_block(lines)],
    );

    final guess =
        parseRosterTableFromRecognizedText(recognized, referenceYear: 2026);

    expect(guess.dates.length, 7);
    final xiaoMing = guess.rows.firstWhere((r) => r.employeeName == '小明');
    expect(xiaoMing.cells[6], '0700-1500'); // 07/19
  });

  test('彙總列標籤 Y 座標跟最後一位員工的姓名黏太近時，不會把員工也一起判成雜訊丟掉', () {
    // 真實照片踩到的 bug：表格最後一位員工「育傑」的姓名行跟底下彙總列
    // 標籤「預估PSD」Y 範圍重疊，被分到同一個姓名群組，合併後的文字整段
    // 含有 stopword「預估」，導致連育傑的姓名都被 stopword 檢查判定成雜訊
    // 列一起丟掉——整個人從結果裡消失。標籤要在進姓名分群前就先濾掉，
    // 不能只在分群後對合併文字做 stopword 檢查。
    final lines = <TextLine>[
      _line('07/13(一)', const Rect.fromLTWH(100, 90, 60, 20)),
      _line('07/14(二)', const Rect.fromLTWH(200, 90, 60, 20)),

      _line('育傑', const Rect.fromLTWH(20, 150, 60, 20)), // top=150, bottom=170
      _line('0700-1500', const Rect.fromLTWH(90, 150, 60, 20)),
      _line('1500-2300', const Rect.fromLTWH(190, 150, 60, 20)),

      // 彙總列標籤，Y 範圍跟育傑的姓名行重疊（top=165 < 170，bottom=185 > 150）。
      _line('預估PSD', const Rect.fromLTWH(20, 165, 80, 20)),
      _line('105556', const Rect.fromLTWH(90, 165, 60, 20)),
    ];

    final recognized = RecognizedText(
      text: lines.map((l) => l.text).join('\n'),
      blocks: [_block(lines)],
    );

    final guess =
        parseRosterTableFromRecognizedText(recognized, referenceYear: 2026);

    expect(guess.rows.length, 1);
    final yuJie = guess.rows.single;
    expect(yuJie.employeeName, '育傑');
    expect(yuJie.cells[0], '0700-1500');
    expect(yuJie.cells[1], '1500-2300');
  });

  test('完全沒有座標可用時，退回純文字解析', () {
    const rawText = '07/13(一) 07/14(二)\n小明 0700-1500 -\n';
    final recognized = RecognizedText(text: rawText, blocks: const []);

    final guess =
        parseRosterTableFromRecognizedText(recognized, referenceYear: 2026);

    expect(guess.dates.length, 2);
    expect(guess.rows.single.employeeName, '小明');
    expect(guess.rows.single.cells, ['0700-1500', null]);
  });
}
