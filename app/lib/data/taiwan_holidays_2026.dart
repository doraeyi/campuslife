// 中華民國 115 年(西元 2026 年)政府行政機關辦公日曆表
// 來源:行政院人事行政總處 https://www.dgpa.gov.tw/information?uid=41&pid=12573
const taiwanHolidays2026 = <String, String>{
  '2026-01-01': '元旦',
  '2026-02-16': '除夕',
  '2026-02-17': '春節',
  '2026-02-18': '春節',
  '2026-02-19': '春節',
  '2026-02-28': '和平紀念日',
  '2026-04-04': '兒童節',
  '2026-04-05': '清明節',
  '2026-05-01': '勞動節',
  '2026-06-19': '端午節',
  '2026-09-25': '中秋節',
  '2026-09-28': '教師節',
  '2026-10-10': '國慶日',
  '2026-10-25': '台灣光復暨金門古寧頭大捷紀念日',
  '2026-12-25': '行憲紀念日',
};

String _key(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String? holidayNameFor(DateTime date) => taiwanHolidays2026[_key(date)];

bool isWeekend(DateTime date) => date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
