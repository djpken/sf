<!-- /autoplan restore point: /Users/kunkun/.gstack/projects/sf/main-autoplan-restore-20260605-213547.md -->
# 計畫：Follow-ups（建議追問 + 主動反問澄清）

> 初步計畫，供 /autoplan 審查。分工：codex 實作、Claude Code 規劃與驗收。

## 意圖

讓對話更會「接話」。兩個子功能：

- **A. 建議追問鈕**：AI 每次回答完，下面出現 2–4 個可點的建議問句（例如「有素食嗎？」「可以訂幾點？」），點了直接送出。等同把現有開場白 STARTERS（`web/src/App.jsx:17-24`）延伸到對話中。
- **B. 主動反問澄清**：當使用者問題太模糊（缺人數、時段、日期等關鍵資訊）時，AI 主動丟出釐清性問題，而不是亂猜。

## 生成策略（已定案）

**同一次回覆串流的尾端產出** —— 不額外多打一次 LLM，避免加重現有 Gemini 429 配額壓力（見 commit 3bd6070）。

利用既有的 streaming + function-calling 基礎設施（Gemini/OpenAI 兩個 provider 都支援，`llm.py` 已統一成 `("tool", {name, result})` 事件）：

- 新增工具規格 `propose_followups(questions: list[str])`，system prompt 指示模型在答完後呼叫它丟出 2–4 個追問。
- `main.py` 的 SSE 產生器攔截這個 tool 事件，轉成新的 SSE 事件 `{"suggestions": [...]}` 推給前端。
- 不需新增 LLM 呼叫；不需改 provider 層。

## 後端改動（server/）

1. **System prompt**：
   - 加入規則：資訊不足時先反問澄清（B），不要亂猜訂位細節。
   - 加入規則：每次回答結尾呼叫 `propose_followups` 給 2–4 個貼合當前情境的追問（A）。
2. **工具規格 `propose_followups`**：中性 JSON schema，沿用既有 tool_specs/tool_registry 機制（`main.py:94-154`、`llm.py`）。
3. **SSE 協定**：新增 `{"suggestions": ["...", "..."]}` 事件型態（在 `{done:true}` 之前送）。更新 `CLAUDE.md:79-83` 的協定文件。
4. **不持久化**：suggestions 為短期輔助，不寫 SQLite（`db.py` 不動）。

## 前端改動（web/src/）

1. **SSE 解析**（`App.jsx:117-137`）：新增 `if (payload.suggestions) attachSuggestions(...)` 分流。
2. **Message state**（`App.jsx:28`）：model 訊息新增 `suggestions: string[]` 欄位。
3. **Render**（`App.jsx:266-305`）：model 訊息底下渲染 suggestion chips；點擊 → `send(question)`。
4. **樣式**（`styles.css`）：`.suggestion-chips`、`.suggestion-chip`，沿用 Design System token。

## 已知邊界情況（待審查補強）

- suggestions 在 `{done:true}` 後才送 vs 串流中途送的時序。
- 空陣列 / 格式錯誤 → 不渲染任何鈕，絕不報錯。
- 模型沒呼叫 `propose_followups`（偶爾不照做）→ 該則回覆就沒有追問鈕，可接受。
- 訂位確認卡（`role:'booking'`）之後要不要出現追問？
- 載入舊對話（`GET /api/conversations/{id}`）因未持久化 → 舊訊息沒有 chips，只有當前回覆有。是否可接受。
- 429 / 串流中斷時 follow-up 的降級行為。
- 點了一個追問鈕之後，舊的 chips 要不要消失（避免重複點）。

## 不在範圍（initial）

- suggestions 持久化與歷史對話回填。
- 個人化追問（依 profile 忌口記憶調整）—— 可作為後續。

---

# GSTACK REVIEW REPORT（/autoplan · single-model）

> Codex 撞到用量上限（恢復時間 7/5），全程僅 Claude 獨立 subagent 把關。雙聲交叉驗證缺席，下列共識表的 Codex 欄一律 N/A。

## CEO 共識表（策略）

| 構面 | Claude | Codex | 共識 |
|---|---|---|---|
| 1. 前提有效？ | 部分 — 「提升轉換」無法證偽（訂位是 mock、零埋點） | N/A | 單聲 critical 旗標 |
| 2. 是對的問題？ | 部分 — B(反問)是；A(每則追問鈕)價值可疑 | N/A | 單聲 |
| 3. 範圍校準？ | 否 — 「兩者都要」綁住高價值的 B，被低價值高成本的 A 拖累 | N/A | 單聲 high |
| 4. 替代方案探索足夠？ | 否 — 應拆成 B→A，A 收斂成「決策點 quick-reply」 | N/A | 單聲 |
| 5. 競品風險覆蓋？ | 部分 — 業界 quick-reply 用在「需使用者選擇」時，非每則泛用 | N/A | 單聲 |
| 6. 6 個月軌跡？ | 風險 — 真正 10x 在「能真的訂到位 + 可量測」 | N/A | 單聲 |

## Eng 共識表（工程）

| 構面 | Claude | Codex | 共識 |
|---|---|---|---|
| 1. 架構健全？ | **否 — CRITICAL：現有 provider loop 是 ReAct 多輪，任何 tool call 都觸發下一輪 generate** | N/A | 單聲 critical |
| 2. 測試覆蓋足夠？ | 否 — 需補 terminal-tool 回歸測試、handler 單元測試、指令遵從 eval | N/A | 單聲 |
| 3. 效能風險？ | 高 — 未修 CRITICAL 前 LLM 呼叫量近乎翻倍，直接違背省配額前提 | N/A | 單聲 critical |
| 4. provider 差異？ | 高 — OpenAI args 串流截斷會靜默丟掉整包 suggestions | N/A | 單聲 high |
| 5. 前端 state？ | 高 — attach 必須定位「最後一則 model」(跳過 booking)、send() 須清舊 chips | N/A | 單聲 high |
| 6. 部署風險？ | 可控 — 降級行為(429/中斷)大致 OK，補防呆即可 | N/A | 單聲 |

## Design litmus（設計完整度 4/10）

| 構面 | 裁決 | 嚴重度 |
|---|---|---|
| 資訊層級 | chips 必須降級為輕量 pill，不可用 starter-card（會與 composer 搶焦點） | high |
| 缺漏狀態 | loading/點擊後/disabled/訂位後/歷史回填 五狀態只列問題未下決策 | critical |
| 觸控目標 | 手機須 ≥44px 命中區（Design System 鐵則），pill 視覺輕但命中區要夠 | high |
| 與 STARTERS 一致性 | 刻意區分：STARTERS 大卡、對話 follow-up pill，靠 token 維持家族感 | medium |
| DS 對齊 | 「沿用 token」太空泛，須列具體 token 清單（DS 已備 chip/pill 規格） | high |

## 跨階段主題（高信心訊號）

**「每則回覆都出泛用追問鈕」是這計畫最弱的一格** —— CEO 與 Design 兩個獨立 subagent 各自指向同一點：對話進行中塞泛用 chips 會變視覺雜訊。收斂成「決策點 quick-reply」可同時解掉 CEO 的價值疑慮、Design 的層級失衡、以及歷史回填不一致。

## Decision Audit Trail

| # | Phase | Decision | 分類 | 原則 | 理由 | 否決選項 |
|---|---|---|---|---|---|---|
| 1 | Eng | 將 `propose_followups` 設為 terminal 工具：provider 收到後 yield 完即 break，不接回對話起下一輪 | Mechanical | P1,P5 | 唯一正解；不修則功能失效或 LLM 翻倍 | 當一般 tool 跑完整 round-trip |
| 2 | Eng | prompt 互斥規則：呼叫 `submit_reservation` 的回合不呼叫 `propose_followups`；同回合兩者並存以 booking 為準 | Mechanical | P1 | 保護訂位這條正確性敏感路徑 | 兩工具同時掛載不設限 |
| 3 | Eng | `propose_followups` handler 須在 TOOLS registry 防禦：去空白/去非字串/上限 4 個/空陣列不送事件 | Mechanical | P1 | provider 差異(OpenAI 截斷)會靜默丟包 | 不防禦直接信任模型輸出 |
| 4 | Eng | 前端 attach 定位「最後一則 role==='model'」(跳過 booking)；send() 開頭清掉舊 suggestions；render 條件 `!streaming && suggestions?.length` | Mechanical | P5 | 修正 state 掛錯與舊 chips 殘留 | 掛在「最後一則」不分型態 |
| 5 | Design | chips 採輕量 pill + 具體 token 清單(`--ds-r-pill`/`--ds-card`/`--ds-divider-hi`/13.5px/600/最多 sh-flat)；手機 ≥44px 命中區 + gap 8px | Mechanical | P1,P5 | DS 已備規格；空泛描述無法驗收 | 複用 starter-card class |
| 6 | Design | 五狀態下明確決策：串流期不顯示佔位、suggestions 到達後淡入；點擊即移除該則整組 chips；isBusy 時 disabled；訂位卡後不追問；歷史不回填(明示接受) | Mechanical | P1 | 把設計債從實作端拉回計畫端 | 留問號丟給 codex |
| 7 | Design | 刻意區分 STARTERS(大卡) 與對話 follow-up(pill)，靠共用 token 維持家族感 | Taste | P5 | 情境不同；避免 codex 直接複製 starter-card | 兩者長一樣 |
| 8 | CEO | 範圍重構：B 先做、A 收斂成決策點 quick-reply | **User Challenge → 使用者否決** | — | 使用者看過畫面比較後選「方案二：兩者都要+每則都出」，理由 demo 鋪滿感 | 採重構建議(已否決) |

---

# 最終決議：方案二（兩者都要 + 每則都出）— APPROVED

使用者於最終閘門選定方案二。範圍維持原方向，並整合全部工程/設計修正。以下為 codex 的實作規格。

## 範圍
- **A**：每則 AI 回覆後出 2–4 個建議追問 pill（訂位回合除外，見下）。
- **B**：缺訂位關鍵欄位（人數/日期/時段）時主動反問澄清，不亂猜。
- 個人化追問（依 profile 忌口）維持延後。

## 後端（server/）
1. **[CRITICAL] `propose_followups` 設為 terminal 工具**：在 `gemini.py:106` / `openai_provider.py:113`，provider 收集到的 call 若全為 terminal 工具，yield `("tool", …)` 後直接 `return`，**不接回對話、不起下一輪 generate**。不修則功能失效或 LLM 呼叫量翻倍（違背省配額前提）。建議在工具註冊處標 `terminal=True`。
2. **prompt 規則**：(a) 每則回答結尾呼叫 `propose_followups` 給 2–4 個貼題追問；(b) **呼叫 `submit_reservation` 的那一回合不呼叫 `propose_followups`**；(c) 缺訂位關鍵欄位時先反問澄清(B)。
3. **handler 防禦**（須加進 TOOLS registry，否則 `gemini.py:117` 回 unknown tool）：去空白、濾非字串、上限 4 個、空陣列回空。
4. **SSE**：新增 `{"suggestions":[...]}` 事件，在 `{done:true}` 之前送；空陣列不送。同回合若 booking + suggestions 並存 → 以 booking 為準、丟棄 suggestions。更新 `CLAUDE.md:79-83` 協定。
5. 不持久化（`db.py` 不動）。

## 前端（web/src/）
1. **SSE 解析**（`App.jsx:132-135`）：加 `else if (payload.suggestions?.length)` 分流（注意 `[]` 是 truthy，須查 `.length`）。
2. **attach 定位**：找「最後一則 `role==='model'`」（跳過 booking），不可用「最後一則」。
3. **send() 開頭清舊 chips**：map 既有 messages 把 `suggestions` 清掉，確保僅最新一則有 chips；chip 點擊複用 `send(question)`。
4. **render 條件**：`!m.streaming && m.suggestions?.length` 才顯示，避免串流中閃現。

## 設計（styles.css，對齊 Design System）
- 形狀 `--ds-r-pill`、底 `--ds-card`、邊 `1px var(--ds-divider-hi)`、字 13.5px/600 `--ds-ink2`、hover `--ds-brand-soft`/`--ds-brand-dark`、陰影最多 `--ds-sh-flat`。**不可複用 `.starter-card`**。
- 容器 `gap:8px`、距上方回覆 12px、距 composer ≥16px。手機 **≥44px 命中區**（Design System 鐵則）。
- 五狀態決策：串流期不顯示佔位 → suggestions 到達後淡入(200ms，尊重 `prefers-reduced-motion`)；點擊即移除該則整組 chips；`isBusy` 時 disabled(`opacity:.5;pointer-events:none`)；訂位卡後不出 chips；歷史對話不回填(明示接受)。
- 加 `aria-label="建議追問"` 群組語意。

## 測試
- 單元：`propose_followups` handler（None/[]/含空字串/超過 4/非字串）；**terminal-tool 回歸**（mock stream 吐 propose_followups call，斷言 stream_chat 結束後無第二次 generate 呼叫）；`main.py` SSE 分流（suggestions 在 done 前、booking+suggestions 同回合只送 booking）。
- Eval（跨兩 provider）：訂位回合仍正確呼叫 `submit_reservation`（驗證新工具未稀釋遵從度）；模糊問題觸發反問澄清。
- 手動 QA：429/串流中斷不出 chips 且不報錯；無孤兒 chips；點擊後舊 chips 消失；舊對話無 chips。

> **交棒**：規劃與驗收由 Claude Code，實作由 codex（CLAUDE.md 分工）。最關鍵落地項是後端 terminal-tool（CRITICAL），請 codex 優先處理並附 terminal-tool 回歸測試。

