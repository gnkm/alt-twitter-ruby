# RSpec テスト環境

このディレクトリにはRSpecテストファイルが含まれます。

## テストの実行方法

```bash
# 全テストを実行
docker compose run --rm --no-deps --entrypoint "" api sh -c "cd /app && bundle exec rspec"

# 特定のファイルを実行
docker compose run --rm --no-deps --entrypoint "" api sh -c "cd /app && bundle exec rspec spec/models/post_spec.rb"

# 特定の行のテストを実行
docker compose run --rm --no-deps --entrypoint "" api sh -c "cd /app && bundle exec rspec spec/models/post_spec.rb:10"
```

## ディレクトリ構造

```
spec/
├── models/       # モデルのテスト
├── requests/     # APIエンドポイントのテスト (推奨)
├── services/     # サービスクラスのテスト
├── support/      # テストサポートファイル
├── rails_helper.rb
└── spec_helper.rb
```

## 設定

- **FactoryBot**: テストデータの作成に使用
- **DatabaseCleaner**: テスト間でデータベースをクリーンアップ
- **Transactional fixtures**: 有効化済み (各テストはトランザクション内で実行)

## TDD ワークフロー

1. **Red**: 失敗するテストを書く
2. **Green**: 最小限の実装でテストをパスさせる
3. **Refactor**: テストを保持したまま改善
