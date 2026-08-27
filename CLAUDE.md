# ACA Basic Settings（飯店端填寫表單）

單一 `index.html`（無框架、無 build step）+ Tailwind Play CDN + Supabase。單人開發：Jim。
本機：`/Users/jim.chao/ACA basic settings`（建立後補上實際 GitHub repo 名稱）。
部署：Vercel，預計正式網址 `https://aca-basic-settings.aiello.dev/`。

## 動手前先讀

**這是 Aiello 表單家族的一員，header/sidebar、語言切換、banner 行為、自動存檔、Supabase 慣例等
共用規格寫在 `/Users/jim.chao/hotel-dashboard/docs/aiello-forms-spec.md` —— 動這些邏輯前先讀那份
文件，不要在這裡重新設計或憑印象照舊做法延續。這個表單走「沒有嵌入即時載入語言的第三方元件」
那一派（比照 SiteChat Settings），UI 語言切換是原地重繪、不整頁重載。** 這份 CLAUDE.md 只放這個
表單自己的專屬資訊。

其他待辦、方案評估看 `/Users/jim.chao/hotel-dashboard/docs/todo.md`。

## 本表單專屬資訊

- 定位：ACA 產品線的前期設定表單，跟 AVA basic settings、AVA UI settings、SiteChat Settings 平行
  並列，**不是**這三個表單的分頁，也不跟 UAT Portal 原本（分開的資料源、需要登入）的前期設定頁面
  同步——兩邊目前是手動同步關係，這也是為什麼這個表單一定要有「匯出 Excel」功能（Aiello 內部人員
  匯出後手動比對/謄寫進 UAT Portal）。
- 連結格式：`?p=<project_id>`（`project_id` 對應共用 Supabase 專案的 `public.projects.id`）。
- `form-submit-notify` Edge Function 的 `source` 標籤：`aca_basic_settings`，通知信固定收件人
  `avapjm@aiello.ai`（跟其他表單「通知專案負責人」不同，這個是寫死的固定信箱）。已在 2026-08-27
  部署 `form-submit-notify` v5，於 `SOURCE_LABELS` map 加上 `aca_basic_settings: "ACA 基礎設定
  表單"`，跟 AVA basic settings 沿用的 `basic_settings: "基礎設定表單"` 標籤區分開來，避免兩邊
  通知信在標題/內文完全看不出差異。
- 主要資料表：`aca_transfer_departments`、`aca_transfer_scenarios`、`aca_welcome_messages`（見
  `migration.sql`，尚未 apply，等 Jim 確認後再跑）。**KMS 使用者刻意不開新表**，直接讀寫既有的
  `web_portal_users`（跟 AVA basic settings 完全共用同一張表，欄位、Publish/Edit 兩級枚舉值都
  是同一套）。
- KMS 權限的編輯歸屬：專案 `products` 陣列裡有 `"AVA"` 時，這個表單的 KMS 分頁改為唯讀顯示（編輯
  以 AVA basic settings 為主），沒有 `"AVA"` 時才開放在這裡直接編輯／新增／刪除。判斷邏輯是
  `hasAva()`，改動前先確認這個規則沒有跟著漂移。
- 轉接部門、轉接場景的名稱欄位、歡迎詞都是**純文字**（`text`，不是 jsonb）——Jim 明確決定
  （2026-08-27）：這些內容客戶只填一版，不像 Greeting/FAQ 那樣要分 en/zh/ja 三份。只有這個表單
  自己的 UI 文字（標籤、按鈕、說明）走 `uiLang`/`UI_STRINGS`/`t()` 三語，資料本身不分語言——這跟
  規格文件第 2 節「UI 語言 vs 內容語言」的區分邏輯一致，只是這個表單刻意選擇不開放內容語言切換。
  「恢復預設內容」（歡迎詞）會依照當下的 `uiLang` 決定要代入哪個語言版本的預設句子。
- 轉接場景的「處理方式」下拉只有兩個選項：`transfer_human`（轉接人工）/ `auto_ticket`（後台自動
  開單）。選到 `auto_ticket` 時，部門/分機/Email 三欄要反灰（`disabled`），不清空既有值。
- 轉接場景的「部門」欄位是**手填文字**，不是外鍵（`<input list>` + `<datalist>` 提供轉接部門設定
  分頁既有的部門名稱當建議選項，方便快速帶入，但不強制一定要選現有的）。只有當文字**完全等於**
  某個現有部門的名稱時，前端才視為「有連動」（`matchedDept()`）：連動時分機欄位鎖死、即時顯示該
  部門的分機（因為「同部門應該只有一組分機」），Email 欄位則帶入該部門的 `emails` 當預設值但保持
  可編輯，允許各轉接場景設定不同收件信箱。文字沒有完全對上任何部門名稱時（自己手打的內容、或部門
  之後被改名/刪除）——分機恢復成該筆場景自己獨立存的值、完全開放編輯，不會被強制帶入或清空任何
  東西（Jim，2026-08-27）。`aca_transfer_scenarios` 表因此同時有 `department_name text`（純文字，
  無 FK 約束）跟 `ext text`（未連動時才真的有用的獨立欄位）兩個欄位。
- 21 組預設場景、5 組預設部門是**首次載入時真的寫進 DB 的一次性 seed**（`seedDefaultsIfEmpty()`），
  不是前端 in-memory 假資料——這是刻意的設計決定：因為 UAT Portal 裡這些預設項目本來就可以被刪除，
  如果做成「DB 沒資料就顯示前端假預設」，使用者刪除後重新整理又會原樣長回來，行為會不一致。seed
  只在該專案兩張表都還是空的時候跑一次，跑完之後這兩張表就完全是一般的可重複列表，沒有任何特殊
  邏輯。來源 PDF（UAT Portal 前期設定頁）文字寫「22 組預設場景」但實際只匯出 21 組可讀的——如果之後
  補到第 22 組，去 `DEFAULT_SCENARIOS` 加一行即可。
- 歡迎詞刻意跟 AVA basic settings 的 `welcome_messages` 表分開（Jim 確認過不是同一份資料），預設
  文字套用專案的飯店名稱（`defaultWelcome()`），「恢復為預設內容」按鈕會重新代入當下的飯店名稱。
- Excel 匯出用 SheetJS（CDN，`xlsx.full.min.js`），純前端把目前畫面上的四個分頁狀態轉成四張
  sheet 直接下載，不經過 Supabase，格式沒有硬性規定，之後要調欄位順序/樣式都只改
  `exportExcelBtn` 那段轉換邏輯即可。
- 標題（`.panel h1`）、卡片標題（`.card h3`）、表格（`table.rep`）、新增列按鈕（`.btn.small.addrow`）、
  刪除列按鈕（`.rm` + `RM_ICON_SVG`）、參考表（`.reftable`）都是直接搬 AVA basic settings 的樣式/
  class 名稱（顏色數值、字級都一致），不是自己重新設計的——之後這個表單再加新分頁，UI 元件先看
  AVA basic settings 有沒有現成的可以照抄，不要自創一套。KMS 分頁的「KMS 權限等級參考」表格內容
  （Publish/Edit 說明文字）也是直接搬 AVA basic settings 的 `KMS_PERMISSION_DETAIL`，兩邊如果之後
  要改權限說明文字記得兩邊一起改（目前沒有共用成同一個檔案）。

## 尚未完成的事（Jim 之後要做的）

1. ~~在本機建立這個 repo~~ 已完成：`git init` + GitHub repo `aiellojim/ACA-basic-settings` + push。
2. ~~apply migration.sql~~ 已完成（2026-08-27，透過 Supabase MCP）：三張表
   `aca_transfer_departments`／`aca_transfer_scenarios`／`aca_welcome_messages` 都已建立、RLS 已開。
3. ~~SOURCE_LABELS~~ 已完成（2026-08-27）：`form-submit-notify` v5 已加上
   `aca_basic_settings: "ACA 基礎設定表單"`。
4. Vercel 專案已建立、目前先用預設網域 `https://aca-basic-settings.vercel.app` 測試（2026-08-27）；
   還沒綁定正式網域 `aca-basic-settings.aiello.dev`，之後去 Vercel 專案 Settings → Domains 加。
5. 去 hotel-dashboard 的 `projects.products` 選項清單加上 `"ACA"` 這個產品標籤——**注意**：實查
   `projects` 表發現已經有多筆專案的 `products` 陣列裡存在 `"ACA"` 值（例如 國聯大飯店、Allianz
   安聯人壽、板橋凱撒大飯店等），代表這個標籤可能已經在別處（例如某個下拉選單/常數清單）加過了，
   下次動這塊之前先去 hotel-dashboard 確認目前 UI 選項清單的實際狀態，不要照舊假設「目前只有
   AVA/GW/KMS/TMSP」重複做一次。專案總覽頁加上這個表單的連結產生按鈕（比照 SiteChat Settings 當初
   的做法）這件事本身還沒做。

## 硬規則

1. 大改動（≥3 檔案、動 schema、動 Edge Function 介面，或 Jim 明說是大改動）前先 `git tag` 打還原點。
2. 禁止把 secret（service_role key、JWT Secret 等）寫進任何會 commit 的檔案；Supabase anon/publishable
   key 是公開金鑰，可以照現況寫在前端原始碼裡，不算 secret。
3. 完成的定義：`node --check` 語法過 **且** 實際頁面確認，「程式碼看起來對」不算完成——驗收流程見
   `aiello-forms-spec.md` 第 5 節。
4. 每次改完照 `aiello-forms-spec.md` 第 5 節跑完驗收流程，才能算改動結束。

## 維護協議

- 模型可自行更新這份檔案的「本表單專屬資訊」章節（例如新增資料表、新增 `source` 標籤）。
- 共用規格（`aiello-forms-spec.md`）的改動邏輯：先跟 Jim 確認，除非是修正明顯過時的既有描述。
