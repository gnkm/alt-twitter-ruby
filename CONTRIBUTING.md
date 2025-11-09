# 開発ガイド

## 📋 プロジェクト概要

Rails API + Next.js + MySQL + Redis を使った最小実装のTwitterクローンです。
詳細な仕様は [docs/specs.md](docs/specs.md) を参照してください。

## 🛠️ 開発環境のセットアップ

### 必要なツール

- Docker & Docker Compose

### セットアップ手順

```bash
# リポジトリのクローン
git clone <repository-url>
cd alt-twitter-ruby

# Docker Composeで全サービスを起動
docker compose up -d

# データベースのセットアップ
docker compose exec api rails db:create db:migrate

# フロントエンドにアクセス
open http://localhost:3000
```

## 🏗️ プロジェクト構成

```
.
├── api/              # Rails API (ポート3001)
│   ├── app/
│   │   ├── controllers/
│   │   └── models/
│   ├── config/
│   └── db/
├── frontend/         # Next.js (ポート3000)
│   ├── app/
│   ├── components/
│   └── lib/
├── docker-compose.yml
└── docs/
    └── specs.md      # 仕様書
```

## 📝 開発ガイドライン

### コーディング規約

#### Rails (API)

- Ruby Style Guide に準拠
- RuboCop の設定に従う
- モデルにはバリデーションとテストを必須とする

#### Next.js (Frontend)

- TypeScript を使用
- ESLint の設定に従う
- コンポーネントは `components/` ディレクトリに配置
- shadcn/ui + Tailwind CSS でスタイリング

### Git ワークフロー

1. 新機能や修正用のブランチを作成

```bash
git checkout -b feature/your-feature-name
# または
git checkout -b fix/issue-description
```

2. コミットメッセージは明確に

```bash
git commit -m "Add: 投稿削除機能を追加"
git commit -m "Fix: タイムライン取得時のキャッシュバグを修正"
```

3. プルリクエストを作成
   - 変更内容を簡潔に説明
   - 関連するIssue番号を記載

## 🧪 テスト

### Rails API

```bash
# RSpecの実行
docker compose exec api bundle exec rspec

# 特定のファイルのみ
docker compose exec api bundle exec rspec spec/models/post_spec.rb
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

## 🔍 コードレビューのポイント

- [ ] テストが追加されているか
- [ ] バリデーションが適切か
- [ ] エラーハンドリングが実装されているか
- [ ] Redisキャッシュのロジックが正しいか
- [ ] UIが仕様書通りか（投稿フォーム、タイムライン表示）

## 📦 主要な技術スタック

| 層 | 技術 |
|---|---|
| フロントエンド | Next.js 16, TypeScript, Tailwind CSS, shadcn/ui |
| APIサーバ | Rails 8.1 (APIモード) |
| データベース | MySQL 8.4 |
| キャッシュ | Redis 7 |
| 開発環境 | Docker Compose |

## 🐛 バグ報告

Issueを作成する際は以下を含めてください：

- 発生した問題の説明
- 再現手順
- 期待される動作
- 実際の動作
- 環境情報（ブラウザ、OSなど）

## 💡 機能提案

現在は最小実装のため、以下の機能は対象外です：

- ユーザー認証・ログイン
- フォロー機能
- いいね・リツイート
- 画像投稿

機能追加を提案する場合は、Issue で議論してから実装を開始してください。

## 📄 ライセンス

このプロジェクトのライセンスについては [LICENSE](LICENSE) を参照してください。

## 🙏 謝辞

貢献していただいたすべての方に感謝します！
