# 実装計画

仕様書に基づいた詳細な実装計画です。TDD（テスト駆動開発）を前提とし、4つのフェーズで進めます。

---

## Phase 1: Docker環境構築 ✅

### 1.1 プロジェクト初期化 ✅
- [x] `.gitignore` の整備
- [x] `docker-compose.yml` 作成（4サービス: frontend, api, db, redis）
- [x] Rails用 `Dockerfile` 作成（Ruby 3.3.6）
- [x] Next.js用 `Dockerfile` 作成

### 1.2 Rails API初期化 ✅
- [x] `rails new api --api --database=mysql --skip-test` 実行
- [x] `database.yml` をDocker MySQL用に設定
- [x] Redis gem追加（`redis`, `redis-rails`）
- [x] CORS設定（`rack-cors`）
- [x] RSpec + FactoryBot + DatabaseCleaner セットアップ

### 1.3 Next.js初期化 ✅
- [x] `npx create-next-app@latest frontend --typescript --tailwind --app`
- [x] shadcn/ui初期化（`npx shadcn@latest init`）
- [x] Vitest + React Testing Library セットアップ
- [x] `vitest.config.ts` 作成
- [x] 環境変数設定（`.env.local`）

### 1.4 動作確認 ✅
- [x] `docker-compose up` で全サービス起動確認
- [x] Rails: `http://localhost:3001` アクセス確認（Ruby 3.3.6 + Rails 8.1.1）
- [x] Next.js: `http://localhost:3000` アクセス確認
- [x] MySQL接続確認（twitter_clone_development, twitter_clone_test作成済み）
- [x] Redis接続確認（PONG応答確認）

**完了日**: 2025-11-09
**備考**: Rubyバージョンを3.3.0から3.3.6に更新してRails 8.1.1との互換性問題を解決

---

## Phase 2: Rails APIバックエンド実装（TDD） ✅

### 2.1 Postモデル（TDD） ✅

**Red**: テストを書く
- [x] `spec/models/post_spec.rb` 作成
  - bodyのバリデーション（presence, length: maximum 140）
  - author_nameのデフォルト値（"guest"）
  - created_atでの降順ソート

**Green**: 実装
- [x] `rails g model Post body:text author_name:string`
- [x] マイグレーション修正（`add_index :posts, :created_at`）
- [x] `rails db:migrate`
- [x] `app/models/post.rb` にバリデーション追加

**Refactor**: 改善
- [x] FactoryBot設定（`spec/factories/posts.rb`）
- [x] テスト整理

### 2.2 PostsController（TDD） ✅

**Red**: テストを書く
- [x] `spec/requests/api/posts_spec.rb` 作成
  - `POST /api/posts` の正常系・異常系
  - `GET /api/posts` の一覧取得
  - limitパラメータのテスト

**Green**: 実装
- [x] `rails g controller Api::Posts --skip-routes`
- [x] `config/routes.rb` にAPIルート追加
- [x] `create` アクション実装
- [x] `index` アクション実装

**Refactor**: 改善
- [x] エラーハンドリング整理
- [x] Strong Parametersの確認

### 2.3 Redisキャッシュ層（TDD） ✅

**Red**: テストを書く
- [x] `spec/services/post_cache_service_spec.rb` 作成
  - `cache_post(post)` で `LPUSH tl:global`
  - `LTRIM tl:global 0 49` で50件制限
  - `get_cached_ids(limit)` でID取得

**Green**: 実装
- [x] `app/services/post_cache_service.rb` 作成
- [x] `PostsController#create` でキャッシュ更新
- [x] `PostsController#index` でキャッシュ読み込み

**Refactor**: 改善
- [x] キャッシュミス時のDB補完ロジック
- [x] Redis接続エラーハンドリング

### 2.4 統合テスト ✅
- [x] `spec/requests/api/posts_spec.rb` で全フローテスト
  - 投稿作成 → Redis確認 → 一覧取得の流れ
- [x] エラーケースの網羅（422, 500）

**完了日**: 2025-11-09
**備考**: TDDサイクルでPost モデル、PostsController、PostCacheServiceを実装完了

---

## Phase 3: Next.jsフロントエンド実装（TDD）

### 3.1 型定義
- [ ] `types/post.ts` 作成
  ```typescript
  export interface Post {
    id: number
    body: string
    author_name: string
    created_at: string
  }
  ```

### 3.2 APIクライアント（TDD）

**Red**: テストを書く
- [ ] `__tests__/lib/api.test.ts` 作成
  - `fetchPosts()` のテスト
  - `createPost(body)` のテスト

**Green**: 実装
- [ ] `lib/api.ts` 作成
- [ ] `fetch` を使ったAPI通信実装

**Refactor**: 改善
- [ ] エラーハンドリング
- [ ] 型安全性の確認

### 3.3 PostFormコンポーネント（TDD）

**Red**: テストを書く
- [ ] `__tests__/components/PostForm.test.tsx` 作成
  - テキスト入力のテスト
  - 140文字制限のバリデーション
  - 空文字の場合のボタン無効化
  - 投稿成功後のクリア

**Green**: 実装
- [ ] `components/PostForm.tsx` 作成（Client Component）
- [ ] shadcn/ui の `Textarea`, `Button` 使用
- [ ] `useState` でフォーム管理

**Refactor**: 改善
- [ ] エラー表示の改善
- [ ] ローディング状態の追加

### 3.4 PostListコンポーネント（TDD）

**Red**: テストを書く
- [ ] `__tests__/components/PostList.test.tsx` 作成
  - 投稿リスト表示
  - 空配列時のメッセージ
  - 日時フォーマット

**Green**: 実装
- [ ] `components/PostList.tsx` 作成（Client Component）
- [ ] `components/PostCard.tsx` 作成
- [ ] lucide-react でアイコン追加

**Refactor**: 改善
- [ ] スタイリング調整
- [ ] アクセシビリティ対応

### 3.5 トップページ（SSR + CSR）

**Red**: テストを書く
- [ ] `__tests__/app/page.test.tsx` 作成
  - SSRでの初期データ取得
  - 10秒ポーリングのテスト

**Green**: 実装
- [ ] `app/page.tsx` 作成（Server Component）
  - SSRで初期50件取得
- [ ] `usePostPolling` カスタムフック作成（CSR）
  - `setInterval` で10秒ごとに再取得

**Refactor**: 改善
- [ ] エラーバウンダリ追加
- [ ] メタデータ設定（SEO）

### 3.6 統合テスト
- [ ] E2Eシナリオ（手動確認）
  - 投稿 → タイムライン反映 → ポーリング更新

---

## Phase 4: 統合テスト・最終確認

### 4.1 統合テスト
- [ ] フロントエンド・バックエンド疎通確認
- [ ] CORS設定の動作確認
- [ ] Redisキャッシュヒット率の確認

### 4.2 ドキュメント整備
- [x] README.md 更新
  - セットアップ手順
  - 起動方法
  - テスト実行方法
- [x] API仕様書の確認（specs.md）

### 4.3 最終チェック
- [ ] 全RSpecテストがパス
- [ ] 全Vitestテストがパス
- [ ] `docker-compose up` で正常起動
- [ ] ブラウザでの動作確認

---

## タイムライン見積もり

| Phase | 内容 | 想定時間 |
|---|---|---|
| Phase 1 | Docker環境構築 | 2-3時間 |
| Phase 2 | Rails API実装 | 4-6時間 |
| Phase 3 | Next.js実装 | 4-6時間 |
| Phase 4 | 統合・最終確認 | 1-2時間 |
| **合計** | | **11-17時間** |

---

## 使用するサブエージェント

- **tdd-rails-expert**: Phase 2全体
- **tdd-nextjs-expert**: Phase 3全体
- **general-purpose**: Phase 1, 4

---

## ディレクトリ構成（完成時）

```
.
├── docker-compose.yml
├── .gitignore
├── README.md
├── docs/
│   ├── specs.md
│   └── implementation-plan.md
├── .claude/
│   └── subagents/
│       ├── tdd-rails-expert.md
│       └── tdd-nextjs-expert.md
├── api/                        # Rails API
│   ├── Dockerfile
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── config/
│   │   ├── database.yml
│   │   ├── routes.rb
│   │   └── initializers/
│   │       ├── cors.rb
│   │       └── redis.rb
│   ├── app/
│   │   ├── models/
│   │   │   └── post.rb
│   │   ├── controllers/
│   │   │   └── api/
│   │   │       └── posts_controller.rb
│   │   └── services/
│   │       └── post_cache_service.rb
│   ├── db/
│   │   └── migrate/
│   │       └── *_create_posts.rb
│   └── spec/
│       ├── factories/
│       │   └── posts.rb
│       ├── models/
│       │   └── post_spec.rb
│       ├── requests/
│       │   └── api/
│       │       └── posts_spec.rb
│       └── services/
│           └── post_cache_service_spec.rb
└── frontend/                   # Next.js
    ├── Dockerfile
    ├── package.json
    ├── package-lock.json
    ├── vitest.config.ts
    ├── app/
    │   ├── page.tsx
    │   ├── layout.tsx
    │   └── globals.css
    ├── components/
    │   ├── PostForm.tsx
    │   ├── PostList.tsx
    │   └── PostCard.tsx
    ├── lib/
    │   └── api.ts
    ├── types/
    │   └── post.ts
    ├── hooks/
    │   └── usePostPolling.ts
    └── __tests__/
        ├── setup.ts
        ├── components/
        │   ├── PostForm.test.tsx
        │   └── PostList.test.tsx
        ├── lib/
        │   └── api.test.ts
        └── app/
            └── page.test.tsx
```
