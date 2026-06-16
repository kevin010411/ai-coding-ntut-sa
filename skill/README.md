# Copyright© Teddysoft

## 這是泰迪軟體為了「製作幫助開發人員採用 AI Coding」所製作的範本專案，將範本存在 .ai 目錄。透過開發 AI SCRUM 系統，提供 running example，再從中萃取出可供 AI Coding 的範本。

## Postgres docker for transactional outbox

#### X86

```shell
docker run --name postgres_ezscrum_prod -e POSTGRES_PASSWORD=root -p 5500:5432 -d ezkanban/postgres_message_db
docker run --name postgres_ezscrum_test -e POSTGRES_PASSWORD=root -p 5800:5432 -d ezkanban/postgres_message_db
docker run --name postgres_ezscrum_ai -e POSTGRES_PASSWORD=root -p 6600:5432 -d ezkanban/postgres_message_db
```

##### Apple Silicon
```shell
docker run --name postgres_ezscrum_prod -e POSTGRES_PASSWORD=root -p 5500:5432 -d ezkanban/postgres_message_db:arm64v8
docker run --name postgres_ezscrum_test -e POSTGRES_PASSWORD=root -p 5800:5432 -d ezkanban/postgres_message_db:arm64v8
docker run --name postgres_ezscrum_ai -e POSTGRES_PASSWORD=root -p 6600:5432 -d ezkanban/postgres_message_db:arm64v8
```

docker run --name postgres_ezscrum_test -e POSTGRES_PASSWORD=root -p 5800:5432 -d ezkanban/postgres_message_db:arm64v8
docker run --name postgres_ezscrum_test2 -e POSTGRES_PASSWORD=root -p 6000:5432 -d ezkanban/postgres_message_db:arm64v8

## 啟動 Claude Code，執行工作不需要使用者同意
claude --dangerously-skip-permissions


## 自學指令，直接問 Claude Code
畫出 execute-uc 執行流程
分析並告訴我 ezddd-java skill 用途
解釋 gate 2.5
ezddd-java skill 用到哪些 patterns?
解釋 ezddd-java skill 的 SSOA 機制
ezddd-java skill 是否有 hook?       


## 由規格產生程式碼的 Prompt 範例
Example 1: 使用 in-memory repository，不用起動 Postgres 
* 在 CLAUDE CLI 中輸入以下 prompt：
使用 execute-uc --only-inmemory 執行 create-product.json，不要參考任何 git history


Example 2: 使用 outbox 與 in-memory repository
* 把 project-config-outbox.json 內容複製到 project-config.json
* 啟動 docker, 確定測試使用的 Postgres 啟動在  localhost:5800
* 在 CLAUDE CLI 中輸入以下 prompt：
使用 execute-uc 執行 create-product.json，不要參考任何 git history


Example 3: 使用 in-memory repository，同時產生 controller layer 程式
使用 execute-uc --controller --only-inmemory 執行 create-product.json，不要參考任何 git history


Example 4: 使用 outbox 與 in-memory repository，同時產生 controller layer 程式
使用 execute-uc --controller 執行 create-product.json，不要參考任何 git history
