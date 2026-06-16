
### Specification: PBI state change spec.


以下是關於 ProductBacklogItem aggregate 的 PbiState 狀態機＋事件規則。

狀態定義（PbiState）
•	BACKLOGGED：未被選入 Sprint
•	SELECTED：已選入某 Sprint（尚未開始）
•	IN_PROGRESS：Sprint 開始後（與 Task 是否已動工無關）
•	DONE：所有 Task=Done 且 AC/DoD 通過（人工檢查即可）
•	CANCELED：取消

註：SELECTED 與 IN_PROGRESS 意義不同：一個是承諾，一個是時點（Sprint 開始）。

觸發事件與轉換規則

1) 承諾與開 Sprint
   •	PbiCommittedToSprint → BACKLOGGED → SELECTED（設定 committedSprintId）
   •	SprintStarted（對該 PBI 所屬 Sprint） → SELECTED → IN_PROGRESS
   •	若此時 PBI 沒有任何任務開始，也仍然進入 IN_PROGRESS（符合你的邏輯）

2) 完成與回退
   •	當 所有 Task=DONE 且 AC/DoD 通過：
   •	發 PbiCompleted → IN_PROGRESS → DONE
   •	若 PBI 已是 DONE，之後發生任務回退（任一 Task 從 DONE 變為 TODO/DOING/TEST/REVIEW）：
   •	發 PbiWorkRegressed（或沿用 TaskStateChangedInPbi 即可）→ DONE → IN_PROGRESS

3) 其它情境（建議）
   •	PbiUncommittedFromSprint：只允許在 SELECTED（Sprint 尚未開始）或沒有活動工作時；狀態 → BACKLOGGED、清空 committedSprintId
   •	PbiCanceled：任何時點可取消（終端）
   •	新增/刪除任務：
   •	若在 DONE 狀態新增任務 → 立即 DONE → IN_PROGRESS（避免「完成後又新增工作」的矛盾）

聚合內的檢查點（建議最少化）

boolean allTasksDone();
boolean anyTaskNotDone(); // 含 TODO/DOING/TEST/REVIEW
boolean acceptanceAllMandatoryMet();
boolean definitionOfDoneSatisfied();

命令處理（核心片段）

a) Sprint 開始時

public void startSprint(SprintId sprintId, String by) {
if (!sprintId.equals(this.committedSprintId)) return; // 不屬於這個 sprint
if (this.state == PbiState.SELECTED) {
apply(new PbiBecameInProgress(id, sprintId, by, now()));
}
}

b) 任務狀態改變（只處理完成/回退邏輯）

public void moveTask(TaskId taskId, ScrumBoardTaskState to, String by) {
// ...既有驗證與 TaskMoved 事件...
// 若全部完成且 AC/DoD 通過 → DONE
if (this.state != PbiState.DONE
&& allTasksDone()
&& acceptanceAllMandatoryMet()
&& definitionOfDoneSatisfied()) {
apply(new PbiCompleted(id, committedSprintId, by, now()));
}

// 若本來已 DONE，但此次移動造成非全 DONE → 回到 IN_PROGRESS
if (this.state == PbiState.DONE && anyTaskNotDone()) {
apply(new PbiWorkRegressed(id, committedSprintId, by, now()));
}
}

讀模型影響（CQRS）
•	承諾檢視：用 SELECTED 與 IN_PROGRESS 區分 Sprint 前/後
•	進展檢視：IN_PROGRESS 並不代表已動工，UI 可輔以「活動中任務數」提示（0 代表尚未動工）
•	燃盡/度量：基於 Task 事件即可；與 PBI 狀態拆開

優點 / 風險

優點
•	產品面溝通清楚：一開 Sprint，所有被承諾的 PBI 一律 IN_PROGRESS
•	完成與回退可被精準追蹤（PbiCompleted / 回退觸發 PbiWorkRegressed）

風險與對策
•	風險：IN_PROGRESS 但尚未動工可能造成誤解
•	對策：讀端同時顯示「活動中任務數」「已開始工作時間」。必要時加事件 PbiWorkStarted 代表第一次任務啟動
•	風險：完成後新增任務或回退造成閃爍
•	對策：在新增任務與任務回退時即刻將 PBI 置為 IN_PROGRESS，並以事件記錄原因

測試建議（Given–When–Then）
1.	Committed → SprintStarted：BACKLOGGED → SELECTED → IN_PROGRESS，即使所有 Task 仍 TODO
2.	全部完成：最後一個 Task → DONE 且 AC/DoD 通過 → PbiCompleted、狀態 DONE
3.	回退：DONE 後任一 Task DONE→DOING → PbiWorkRegressed、狀態 IN_PROGRESS
4.	DONE 後新增任務：自動 DONE→IN_PROGRESS
5.	Uncommit：SELECTED 可撤回；IN_PROGRESS 禁撤回（或需補償）

⸻

總結
只要明確把「承諾」與「進展」的語意界線定清楚，並補齊上述邊界與回退規則，就能在不觀察 Task 是否已動工的前提下，仍保持模型一致性與可預期性。

