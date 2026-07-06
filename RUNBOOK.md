# YiWallet 開發 / 部署手冊

專案結構：`app/` 是 Flutter 前端，`api/` 是 FastAPI 後端，資料庫是 NAS 上的 MySQL。
正式環境跑在 `kaikaizhen.myasustor.com`（liam 的 NAS）。

---

## 1. 本機執行

### 後端 (FastAPI)

```powershell
.\scripts\start-dev.ps1
```

這支 script 會：
1. 建立 SSH tunnel 到 NAS 的 MySQL（本機 3307 → NAS 3306），如果已經有開就跳過
2. 在本機 8000 port 啟動 FastAPI（`uvicorn main:app --host 0.0.0.0 --port 8000`）
3. 啟動後可以到 http://127.0.0.1:8000/docs 看 Swagger 測試 API

結束開發時：

```powershell
.\scripts\stop-dev.ps1
```

**注意 `api/.env` 的 `DATABASE_URL`**：如果裡面寫的是 `127.0.0.1:3306`，代表接的是本機自己的 MySQL，不是 NAS；如果要接 NAS 資料庫做測試，要改成 `127.0.0.1:3307`（配合上面的 tunnel）。兩種資料庫的資料不會同步，改之前先確認現在連的是哪一個。

### 前端 (Flutter)

```powershell
cd app
flutter run -d chrome --web-port=61287    # 或接 Android/iOS 裝置跑 flutter run -d <device>
```

跑起來後按 `r` 可以 hot reload、`R` hot restart、`q` 結束。

**重要**：`app/lib/services/api_client.dart` 裡的 `baseUrl` 目前是寫死指向正式環境：
```dart
static const String baseUrl = 'https://kaikaizhen.myasustor.com:1123/yiwallet';
```
也就是說，就算本機後端有跑起來，Flutter app 預設還是打正式環境的 API，**不是**本機的 8000 port。如果要讓前端測本機後端，要暫時把這行改成 `http://127.0.0.1:8000`，測完記得改回來，不要不小心 commit 上去。

### 資料庫 schema 變更

專案沒有用 Alembic 之類的 migration 工具，`main.py` 裡的 `Base.metadata.create_all()` 只會建立不存在的新表，**不會**幫舊表加新欄位。如果改了 `models.py` 新增欄位，要手動連進資料庫下 `ALTER TABLE`（可以參考 `api/migrate_add_einvoice_fields.py` 的寫法），本機、NAS 的資料庫都要各自補一次。

---

## 2. Push 原始碼

```bash
git add <files>
git commit -m "..."
git push origin master
```

- 遠端：`git@github.com:doraeyi/campuslife.git`，只有 `master` 一個分支
- push 到 `master` 會自動觸發 [Codemagic](https://codemagic.io) 的 iOS workflow（`codemagic.yaml`），編譯出未簽名的 `unsigned.ipa`。這台開發機沒有 Mac，iOS 版都是靠這個雲端建置。建置完到 Codemagic 網站下載 `unsigned.ipa`，用 [Sideloadly](https://sideloadly.io) 搭配免費 Apple ID 簽名安裝（7 天後要重簽一次）
- Android / Web 目前沒有自動化建置，要手動 build（見下面）

### 手動 build（選用）

```powershell
cd app
flutter build apk --release      # Android APK
flutter build web --release      # Web
```

---

## 3. 部署後端到 NAS（正式環境）

NAS 上的 `~/yiwallet`（`liam@kaikaizhen.myasustor.com`）**不是** git repo，是手動同步過去的檔案，push 到 GitHub **不會**自動更新正式環境，需要手動部署：

### 3.1 複製改動的檔案上去

```bash
scp -P 1122 api/main.py api/models.py api/schemas.py api/auth.py api/database.py \
    liam@kaikaizhen.myasustor.com:~/yiwallet/
scp -P 1122 -r api/routers liam@kaikaizhen.myasustor.com:~/yiwallet/
```

依實際改了哪些檔案調整清單即可，不用每次全部複製。

**千萬不要**把本機的 `api/.env` 複製上去蓋掉——NAS 上有自己的 `.env`（DB 密碼、LINE/Google 金鑰都跟本機不同）。

### 3.2 如果 `requirements.txt` 有新增套件

```bash
ssh -p 1122 liam@kaikaizhen.myasustor.com
cd ~/yiwallet && source venv/bin/activate && pip install -r requirements.txt
```

### 3.3 如果這次改動有動到資料庫 schema

先手動對 NAS 上的 MySQL 執行對應的 `ALTER TABLE` / migration script（同本機，`create_all()` 不會自動改舊表）。

### 3.4 重啟服務

```bash
ssh -t -p 1122 liam@kaikaizhen.myasustor.com "sudo systemctl restart yiwallet"
```

`-t` 是為了讓 sudo 密碼提示能正常顯示（liam 沒有設定 passwordless sudo，會要求輸入密碼）。

### 3.5 確認服務正常

```bash
ssh -p 1122 liam@kaikaizhen.myasustor.com "systemctl status yiwallet --no-pager"
ssh -p 1122 liam@kaikaizhen.myasustor.com "journalctl -u yiwallet -n 50 --no-pager"
```

（看 log 不用 sudo，liam 本身在 `adm` 群組裡可以直接讀 journal）

---

## 4. 速查資訊

| 項目 | 值 |
|---|---|
| App 對外打的 API base URL | `https://kaikaizhen.myasustor.com:1123/yiwallet` |
| NAS uvicorn 實際監聽的 port | `3001`（外部 1123 是 NAS 反向代理轉進來的） |
| NAS SSH | `ssh -p 1122 liam@kaikaizhen.myasustor.com` |
| NAS 上後端程式路徑 | `~/yiwallet`（純檔案同步，非 git repo） |
| systemd service 名稱 | `yiwallet`（unit 檔在 `/etc/systemd/system/yiwallet.service`） |
| Git 遠端 | `git@github.com:doraeyi/campuslife.git`，分支 `master` |
