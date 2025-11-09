require 'rails_helper'

RSpec.describe 'Api::Posts', type: :request do
  let(:redis) { Redis.new }

  before do
    # Clean up Redis before each test
    redis.del('tl:global')
  end

  after do
    # Clean up Redis after each test
    redis.del('tl:global')
  end

  describe 'POST /api/posts' do
    context 'with valid parameters' do
      let(:valid_params) { { post: { body: 'Hello, World!' } } }

      it 'creates a new post' do
        expect {
          post '/api/posts', params: valid_params
        }.to change(Post, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'returns the created post' do
        post '/api/posts', params: valid_params

        json = JSON.parse(response.body)
        expect(json['body']).to eq('Hello, World!')
        expect(json['author_name']).to eq('guest')
        expect(json['id']).to be_present
        expect(json['created_at']).to be_present
      end

      it 'caches the post ID in Redis' do
        post '/api/posts', params: valid_params

        json = JSON.parse(response.body)
        post_id = json['id']

        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids).to include(post_id.to_s)
      end

      it 'adds the post to the beginning of the cache' do
        old_post = create(:post, body: 'Old post')
        redis.lpush('tl:global', old_post.id)

        post '/api/posts', params: valid_params

        json = JSON.parse(response.body)
        new_post_id = json['id']

        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids.first).to eq(new_post_id.to_s)
      end
    end

    context 'with invalid parameters' do
      it 'returns an error when body is blank' do
        post '/api/posts', params: { post: { body: '' } }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include("can't be blank")
      end

      it 'returns an error when body exceeds 140 characters' do
        post '/api/posts', params: { post: { body: 'a' * 141 } }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('too long')
      end

      it 'does not cache invalid posts' do
        post '/api/posts', params: { post: { body: '' } }

        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids).to be_empty
      end
    end
  end

  describe 'GET /api/posts' do
    context 'when cache is empty' do
      it 'returns posts from database' do
        posts = create_list(:post, 3)

        get '/api/posts'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end

      it 'returns posts in descending order by created_at' do
        old_post = create(:post, body: 'Old post', created_at: 2.days.ago)
        new_post = create(:post, body: 'New post', created_at: 1.day.ago)

        get '/api/posts'

        json = JSON.parse(response.body)
        expect(json.first['id']).to eq(new_post.id)
        expect(json.second['id']).to eq(old_post.id)
      end
    end

    context 'when cache has post IDs' do
      it 'returns posts from cache' do
        posts = create_list(:post, 5)
        # Cache the IDs manually
        posts.reverse_each { |p| redis.lpush('tl:global', p.id) }

        get '/api/posts'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(5)
      end

      it 'maintains the cache order' do
        old_post = create(:post, body: 'Old post')
        new_post = create(:post, body: 'New post')

        redis.lpush('tl:global', old_post.id)
        redis.lpush('tl:global', new_post.id)

        get '/api/posts'

        json = JSON.parse(response.body)
        expect(json.first['id']).to eq(new_post.id)
        expect(json.second['id']).to eq(old_post.id)
      end

      it 'handles deleted posts in cache gracefully' do
        post1 = create(:post, body: 'Post 1')
        post2 = create(:post, body: 'Post 2')
        post3 = create(:post, body: 'Post 3')

        redis.lpush('tl:global', post1.id)
        redis.lpush('tl:global', post2.id)
        redis.lpush('tl:global', post3.id)

        # Delete post2 from database but leave it in cache
        post2.destroy

        get '/api/posts'

        json = JSON.parse(response.body)
        expect(json.length).to eq(2)
        expect(json.map { |p| p['id'] }).to contain_exactly(post1.id, post3.id)
      end
    end

    context 'with limit parameter' do
      it 'respects the limit parameter' do
        create_list(:post, 10)

        get '/api/posts', params: { limit: 5 }

        json = JSON.parse(response.body)
        expect(json.length).to eq(5)
      end

      it 'defaults to 50 posts when no limit is provided' do
        create_list(:post, 60)

        get '/api/posts'

        json = JSON.parse(response.body)
        expect(json.length).to eq(50)
      end
    end

    context 'when Redis is unavailable' do
      before do
        allow_any_instance_of(PostCacheService).to receive(:get_cached_ids).and_return([])
      end

      it 'falls back to database query' do
        posts = create_list(:post, 3)

        get '/api/posts'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end
    end
  end
end
