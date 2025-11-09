# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Rails API + Next.js + MySQL + Redis を使った最小実装のTwitterクローン。
ユーザー認証なしのグローバルタイムライン機能のみを提供。

## 重要な仕様

- **投稿の最大文字数**: 140文字
- **タイムライン表示件数**: デフォルト50件
- **ユーザー名**: 固定値 "guest"
- **自動更新**: 10秒ごとのポーリング
- **キャッシュ**: Redisに最新50件のpost IDを保存 (`tl:global`)

詳細は `docs/specs.md` を参照。

## 開発環境

### セットアップ

```bash
# Docker Composeで全サービスを起動
docker compose up -d

# データベースのセットアップ
docker compose exec api rails db:create db:migrate

# フロントエンド: http://localhost:3000
# API: http://localhost:3001
```

### サービス構成

- `frontend`: Next.js (ポート3000)
- `api`: Rails API (ポート3001)
- `db`: MySQL 8.4
- `redis`: Redis 7

## テスト実行

### Rails API

```bash
# RSpec全実行
docker compose exec api bundle exec rspec

# 特定ファイルのみ
docker compose exec api bundle exec rspec spec/models/post_spec.rb

# 特定の行のテスト
docker compose exec api bundle exec rspec spec/models/post_spec.rb:10
```

### Next.js

```bash
# Vitestの実行
docker compose exec frontend npm test

# ウォッチモード
docker compose exec frontend npm run test:watch

# カバレッジ
docker compose exec frontend npm run test:coverage
```

## アーキテクチャ

### データフロー

1. **投稿作成**: Next.js → Rails API → MySQL + Redis
2. **タイムライン取得**: Next.js → Rails API → Redis (キャッシュヒット時) → MySQL (キャッシュミス時)

### Redisキャッシュ戦略

- `tl:global`: 最新投稿IDのリスト (LPUSH, LTRIM で最大50件維持)
- 投稿作成時に `LPUSH`、投稿一覧取得時に `LRANGE` で高速化
- キャッシュミス時はMySQLから補完

### レンダリング戦略

- **SSR**: 初回タイムライン表示 (高速表示 + SEO + Redisキャッシュ活用)
- **CSR**: 投稿フォーム、自動更新 (非同期POST + 即時反映)

## テスト駆動開発 (TDD)

このプロジェクトではRed-Green-Refactorサイクルを推奨。

### TDDワークフロー

1. **Red**: 失敗するテストを書く (`bundle exec rspec`)
2. **Green**: 最小限の実装でテストをパスさせる
3. **Refactor**: テストを保持したまま改善

### テストの種類

- **Model Spec**: モデルのバリデーション、ロジック (`spec/models/`)
- **Request Spec**: APIエンドポイントの統合テスト (`spec/requests/`) - 推奨
- **Service Spec**: ビジネスロジックの単体テスト (`spec/services/`)

詳細は `.claude/agents/tdd-rails-expert.md` を参照。

## コミットガイドライン

### コミットメッセージ形式

```bash
git commit -m "Add: 投稿削除機能を追加"
git commit -m "Fix: タイムライン取得時のキャッシュバグを修正"
```

### Git操作

Git commitが必要な場合、git-commit-assistantエージェントが自動的に起動し、
変更内容を分析して適切なコミットメッセージを生成する。

## 技術スタック

| 層 | 技術 |
|---|---|
| フロントエンド | Next.js 16, TypeScript, Tailwind CSS, shadcn/ui |
| APIサーバ | Rails 8.1 (APIモード) |
| データベース | MySQL 8.4 |
| キャッシュ | Redis 7 |
| 開発環境 | Docker Compose |
| テスト | RSpec (Rails), Vitest (Next.js) |

## データベース設計

### postsテーブル

| カラム | 型 | 説明 |
|---|---|---|
| id | bigint | 主キー |
| body | text | 投稿内容 (最大140文字) |
| author_name | varchar(32) | ユーザー名 (固定: "guest") |
| created_at | datetime | 投稿日時 |
| updated_at | datetime | 更新日時 |

**インデックス**: `created_at DESC` (タイムライン取得用)

## API仕様

### POST /api/posts

投稿を作成。

**リクエスト**:
```json
{
  "body": "こんにちは、世界!"
}
```

**レスポンス (201)**:
```json
{
  "id": 1,
  "body": "こんにちは、世界!",
  "author_name": "guest",
  "created_at": "2025-11-09T13:00:00Z"
}
```

### GET /api/posts

投稿一覧取得 (最大50件、新しい順)。

**クエリ**: `?limit=50`

## エラーハンドリング

| 状況 | ステータス | メッセージ例 |
|---|---|---|
| bodyが空 | 422 | `{ "error": "Body can't be blank" }` |
| bodyが141文字以上 | 422 | `{ "error": "Body is too long (max 140)" }` |
| サーバーエラー | 500 | `{ "error": "Internal server error" }` |

## 非機能要件

- Redisキャッシュヒット率: 80%以上を目標
- DBトランザクションを明示
- 各機能に対して最低1件のテストを追加

## 対象外機能

以下は最小実装のため対象外:

- ユーザー認証・ログイン
- フォロー機能
- いいね・リツイート
- 画像投稿
