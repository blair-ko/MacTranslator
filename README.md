# MacTranslator — macOS 原生選單列翻譯工具

使用原生 **Swift + SwiftUI + AppKit + Vision + AVFoundation + Carbon** 打造的輕量級 macOS Menu Bar 常駐翻譯小工具。

## ✨ 核心功能

1. **Menu Bar 常駐 & 浮動置頂視窗**
   - 常駐於 macOS 右上角選單列（不佔用 Dock 空間）。
   - 支援浮動置頂（Pin on Top）與全螢幕輔助顯示（可在全螢幕 App 上方直接喚出）。
2. **免費免 API Key 即時翻譯 & 詞典詳解**
   - 串接 Google Translate GTX 免金鑰端點，支援即時防抖自動翻譯（0.45 秒）。
   - 單字查詢時自動顯示**音標/拼音**以及**多詞性字典詳解**（點擊詞彙即可一鍵複製）。
3. **中 <-> 英雙向智慧自動互翻**
   - 當來源語言設為「自動偵測」且啟用「智慧互翻」時：
     - 輸入**中文**時，自動翻譯為 **English**。
     - 輸入**英文或其他外文**時，自動翻譯為 **繁體中文**。
4. **全域快捷鍵 (Global Shortcuts)**（免額外輔助使用權限即可運作）
   - `⌥ Option + Space`：隨時喚出 / 隱藏翻譯視窗
   - `⌥ Option + C`：一鍵讀取剪貼簿文字（或剪貼簿內的圖片 OCR）並立即翻譯
   - `⌥ Option + S`：啟動互動式區域截圖並透過 Apple Vision OCR 自動辨識文字與翻譯
5. **螢幕截圖 OCR 翻譯**
   - 整合 macOS 系統互動式截圖與 Apple `Vision` 框架 (`VNRecognizeTextRequest`)，精準辨識繁中、簡中、英、日、韓文字。
6. **多語系自然語音朗讀 (TTS) & 一鍵複製**
   - 原生 `AVSpeechSynthesizer` 朗讀原文與譯文，自動對應語系發音。
7. **歷史紀錄與收藏夾**
   - 自動儲存最近 200 筆翻譯紀錄於 `~/Library/Application Support/MacTranslator/history.json`。
   - 支援關鍵字搜尋、星號收藏篩選、點擊回填與一鍵複製。

## 🚀 編譯與執行方式

### 1. 打包為 `.app` 並啟動（推薦）
```bash
cd /Users/blair/.gemini/antigravity/scratch/MacTranslator
./build_app.sh
open MacTranslator.app
```

也可以直接將打包好的 `MacTranslator.app` 拖曳至 `/Applications`（應用程式）資料夾中使用。

### 2. 使用 Swift CLI 直接執行
```bash
cd /Users/blair/.gemini/antigravity/scratch/MacTranslator
swift run
```
