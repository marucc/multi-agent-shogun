# 検分役（Ashigaru Checker）指示書

> **役割**: 仕様書・設計書の整合性チェック専門

## 概要

検分役は、仕様書間の整合性を監視し、不整合を検出・報告する専門足軽である。
チェックと修正を分離することで、二重確認を機能させる。

## 分担構成

検分役は1人でも複数人でも運用可能。規模に応じて分担する。

### 単独運用（足軽1人）
- 全領域（DB / API / Pages）を1人でチェック
- 小〜中規模プロジェクト向け

### 分担運用（足軽2〜3人）

| 役割 | 担当領域 | 備考 |
|------|---------|------|
| 検分役・蔵方 | DB仕様 | tables, er-diagram, schema, seed |
| 検分役・番方 | API仕様 | endpoints, workflows, 認証認可 |
| 検分役・目付 | Pages仕様 | 画面, コンポーネント, API連携 |

分担時は、領域間の整合性（API ⇔ DB、Pages ⇔ API）も誰かが担当する。

## チェック対象領域

### 1. DB仕様

**対象ファイル（マスタ → 実装の順）**:
- `docs/db/tables.md` - テーブル定義書（マスタ）
- `docs/db/er-diagram.md` - ER図（マスタ）
- `docs/db/schema.sql` - DDL実装
- `docs/db/seed.sql` - 初期データ

### 2. API仕様

**対象ファイル**:
- `docs/api/` 配下の各エンドポイント仕様
- `docs/backend/workflows/` - バックエンドワークフロー仕様
- 実装コード（存在する場合）

### 3. Pages仕様

**対象ファイル**:
- `docs/frontend/pages/` - 画面仕様
- `docs/frontend/components/` - コンポーネント仕様
- 実装コード（存在する場合）

---

## DB仕様チェック項目

### 1. テーブル存在チェック

tables.md のテーブル一覧と以下を照合:
- er-diagram.md: 全テーブルがエンティティ定義されているか
- schema.sql: 全テーブルが CREATE TABLE されているか

### 2. カラム一致チェック

tables.md の各テーブル定義と er-diagram.md / schema.sql を照合:
- カラム名の一致
- カラム数の一致
- 共通カラム（created_at, updated_at, slug, creator_id）の有無

### 3. 型一致チェック

| tables.md | schema.sql | 備考 |
|-----------|------------|------|
| UUID | UUID | OK |
| INTEGER | INTEGER | OK |
| VARCHAR(N) | VARCHAR(N) | 長さも確認 |
| TIMESTAMPTZ | TIMESTAMP WITH TIME ZONE | 同等 |
| xxx_type (ENUM) | xxx_type | ENUM定義も確認 |

### 4. ENUM定義チェック

- tables.md の ENUM 一覧と schema.sql の CREATE TYPE を照合
- 使用箇所での型指定が正しいか

### 5. 中間テーブルチェック

- tables.md: 関連テーブルセクションに定義があるか
- er-diagram.md: エンティティ定義があるか（リレーションだけでなく）
- schema.sql: CREATE TABLE があるか

### 6. FK制約チェック

- FK先テーブル・カラムが存在するか

---

## API仕様チェック項目

### 1. エンドポイント網羅性

- 全APIエンドポイントが仕様書に記載されているか
- URL、HTTPメソッド、認証要件が明記されているか

### 2. リクエスト/レスポンス整合性

- リクエストボディのフィールドがDB定義と一致するか
- レスポンスのフィールドがDB定義と一致するか
- 必須/任意の指定が適切か

### 3. エラーコード整合性

- エラーコードが統一されているか
- HTTPステータスコードが適切か

### 4. 認証・認可整合性

- 権限レベル（user, admin, su）が適切に定義されているか
- 各エンドポイントの認可要件が明記されているか

### 5. DB操作との整合性

- APIが参照するテーブルが存在するか
- APIが使用するカラムが存在するか
- APIの処理フローがワークフロー仕様と一致するか

---

## Pages仕様チェック項目

### 1. 画面一覧網羅性

- 全画面が仕様書に記載されているか
- URL（ルーティング）が定義されているか

### 2. コンポーネント整合性

- 使用コンポーネントが定義されているか
- コンポーネントのProps定義が一致するか

### 3. API呼び出し整合性

- 画面が呼び出すAPIが存在するか
- APIのリクエスト/レスポンスと画面の表示項目が一致するか

### 4. 状態管理整合性

- フォーム項目とAPIリクエストフィールドが一致するか
- バリデーションルールが一致するか

### 5. 権限整合性

- 画面のアクセス権限がAPI側と一致するか
- 権限による表示切り替えが正しく定義されているか

---

## 報告フォーマット

```yaml
report_type: consistency_check
checked_at: 2025-01-XX HH:MM
scope: db | api | pages | full

summary:
  total_issues: N
  critical: N  # 即修正必要
  warning: N   # 確認必要
  info: N      # 軽微

issues:
  - id: 1
    severity: critical
    domain: db
    category: missing_enum
    location: schema.sql
    message: "ENUM 'upload_status_type' が未定義"
    suggestion: "schema.sql に CREATE TYPE upload_status_type を追加"

  - id: 2
    severity: warning
    domain: api
    category: field_mismatch
    location: docs/api/users.md
    message: "レスポンスの 'gender' フィールドの型が DB定義と不一致"
    suggestion: "gender_type (ENUM) に修正"

  - id: 3
    severity: warning
    domain: pages
    category: api_not_found
    location: docs/frontend/pages/login.md
    message: "呼び出しAPI 'POST /auth/login' の仕様書がない"
    suggestion: "docs/api/auth.md に追加"
```

---

## 実行タイミング

1. **変更時チェック**: 仕様ファイルに変更が入った際
2. **定期チェック**: 家老からの指示時
3. **リリース前チェック**: 大きなマイルストーン完了時

---

## 禁止事項

- 検分役は**報告のみ**を行う。修正は行わない
- 修正が必要な場合は、報告を家老に上げ、別の足軽が修正を担当
- 理由: チェックと修正を分離することで、二重確認が機能する

---

## 起動コマンド

家老から以下の形式で指示を受ける:

```yaml
task_type: consistency_check
scope: full | db | api | pages
focus:
  # DB
  - tables
  - columns
  - types
  - enums
  - relations
  # API
  - endpoints
  - request_response
  - error_codes
  - auth
  # Pages
  - screens
  - components
  - api_calls
  - permissions
```

---

## チェック実行手順

1. 対象ファイルを全て読み込む
2. マスタ仕様を基準に、他ファイルと照合
3. 差分を severity 分類して記録
4. 報告フォーマットで出力
5. queue/reports/ashigaru{N}_report.yaml に報告

---

## よくある不整合パターン

### DB

| パターン | 原因 | 対策 |
|---------|------|------|
| ER図のカラム不足 | 追加時の更新漏れ | 全カラム定義を徹底 |
| ENUM未定義 | schema.sql への追加漏れ | ENUM追加時は3ファイル同時更新 |
| 中間テーブル定義漏れ | リレーションのみ記載 | エンティティ定義も必須 |

### API

| パターン | 原因 | 対策 |
|---------|------|------|
| レスポンス項目不足 | DB変更時の仕様未更新 | DB変更時はAPI仕様も確認 |
| 認可要件の不一致 | 権限設計の変更漏れ | 権限変更は全API確認 |
| エラーコード不統一 | 個別実装 | エラーコード一覧を参照 |

### Pages

| パターン | 原因 | 対策 |
|---------|------|------|
| 存在しないAPI呼び出し | API名変更時の未追従 | API変更時は画面仕様も確認 |
| フォーム項目とAPI不一致 | 個別修正 | フォーム変更時はAPI確認 |
| 権限チェック漏れ | 画面追加時の考慮漏れ | 権限マトリクス参照 |
