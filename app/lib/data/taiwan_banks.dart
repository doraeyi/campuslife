// 台灣主要銀行代碼（金融機構代碼），用來讓「銀行」欄位可以用選的、避免打錯字
// 導致同一家銀行的卡片沒辦法正確合併。清單只涵蓋常見的銀行，沒列到的還是可以
// 直接手動輸入銀行名稱。
typedef TaiwanBank = ({String code, String name});

const List<TaiwanBank> taiwanBanks = [
  (code: '004', name: '台灣銀行'),
  (code: '005', name: '土地銀行'),
  (code: '006', name: '合作金庫銀行'),
  (code: '007', name: '第一銀行'),
  (code: '008', name: '華南銀行'),
  (code: '009', name: '彰化銀行'),
  (code: '011', name: '上海商業儲蓄銀行'),
  (code: '012', name: '台北富邦銀行'),
  (code: '013', name: '國泰世華銀行'),
  (code: '016', name: '高雄銀行'),
  (code: '017', name: '兆豐銀行'),
  (code: '021', name: '花旗銀行'),
  (code: '050', name: '台灣企銀'),
  (code: '052', name: '渣打銀行'),
  (code: '081', name: '匯豐銀行'),
  (code: '103', name: '新光銀行'),
  (code: '108', name: '陽信銀行'),
  (code: '118', name: '板信銀行'),
  (code: '803', name: '聯邦銀行'),
  (code: '805', name: '遠東銀行'),
  (code: '806', name: '元大銀行'),
  (code: '807', name: '永豐銀行'),
  (code: '808', name: '玉山銀行'),
  (code: '809', name: '凱基銀行'),
  (code: '810', name: '星展銀行'),
  (code: '812', name: '台新銀行'),
  (code: '815', name: '日盛銀行'),
  (code: '816', name: '安泰銀行'),
  (code: '822', name: '中國信託'),
  (code: '823', name: '將來銀行'),
  (code: '824', name: '連線銀行'),
  (code: '826', name: '樂天銀行'),
];
