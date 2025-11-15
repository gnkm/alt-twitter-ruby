require 'rails_helper'

RSpec.describe 'Api::Posts', type: :request do
  describe 'POST /api/posts' do
    context '正常系' do
      it '投稿が作成され、201が返る' do
        post '/api/posts', params: { body: 'こんにちは、世界!' }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['body']).to eq('こんにちは、世界!')
        expect(json['author_name']).to eq('guest')
        expect(json).to have_key('id')
        expect(json).to have_key('created_at')
      end

      it '140文字の投稿ができる' do
        long_body = 'あ' * 140
        post '/api/posts', params: { body: long_body }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['body']).to eq(long_body)
      end
    end

    context '異常系' do
      it 'bodyが空の場合は422エラー' do
        post '/api/posts', params: { body: '' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end

      it 'bodyが141文字以上の場合は422エラー' do
        long_body = 'あ' * 141
        post '/api/posts', params: { body: long_body }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end

      it 'bodyパラメータがない場合は422エラー' do
        post '/api/posts', params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end
    end
  end

  describe 'GET /api/posts' do
    context '投稿が存在する場合' do
      before do
        @post1 = Post.create!(body: '最初の投稿', author_name: 'guest')
        @post2 = Post.create!(body: '2番目の投稿', author_name: 'guest')
        @post3 = Post.create!(body: '最新の投稿', author_name: 'guest')
      end

      it '投稿一覧を新しい順で取得できる' do
        get '/api/posts'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(3)
        expect(json[0]['id']).to eq(@post3.id)
        expect(json[1]['id']).to eq(@post2.id)
        expect(json[2]['id']).to eq(@post1.id)
      end

      it 'limitパラメータで取得件数を制限できる' do
        get '/api/posts', params: { limit: 2 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(2)
        expect(json[0]['id']).to eq(@post3.id)
        expect(json[1]['id']).to eq(@post2.id)
      end

      it 'limit未指定時はデフォルトで50件取得' do
        # 51件の投稿を作成
        51.times { |i| Post.create!(body: "投稿#{i}", author_name: 'guest') }

        get '/api/posts'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(50)
      end

      it '各投稿に必要なフィールドが含まれている' do
        get '/api/posts'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        post = json.first
        expect(post).to have_key('id')
        expect(post).to have_key('body')
        expect(post).to have_key('author_name')
        expect(post).to have_key('created_at')
      end
    end

    context '投稿が存在しない場合' do
      it '空の配列を返す' do
        get '/api/posts'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to eq([])
      end
    end
  end
end
