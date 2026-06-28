# CampusLife

班表查看 App。`app/` 是 Flutter 前端,`api/` 是 FastAPI 後端,資料庫是 NAS 上的 MySQL。

## 開發環境啟動

```
.\scripts\start-dev.ps1   # 開 SSH tunnel + 啟動 API
cd app
flutter run -d chrome     # 或接 Android/iOS 裝置
.\scripts\stop-dev.ps1    # 結束時關閉
```

## iOS

這台開發機沒有 Mac,iOS 版透過 [Codemagic](https://codemagic.io)
(`codemagic.yaml`)在雲端編譯出未簽名的 `.ipa`,push 到 `master` 會自動觸發建置。
下載產出的 `unsigned.ipa` 後,用 [Sideloadly](https://sideloadly.io) 搭配免費
Apple ID 簽名安裝到手機(7 天後需要重新安裝一次)。
