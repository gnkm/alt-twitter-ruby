require 'rails_helper'

RSpec.describe 'Api::Posts', type: :request do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1')) }

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
          post '/api/posts', params: valid_params, as: :json
        }.to change(Post, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'returns the created post' do
        post '/api/posts', params: valid_params, as: :json

        json = JSON.parse(response.body)
        expect(json['body']).to eq('Hello, World!')
        expect(json['author_name']).to eq('guest')
        expect(json['id']).to be_present
        expect(json['created_at']).to be_present
      end

      it 'caches the post ID in Redis' do
        post '/api/posts', params: valid_params, as: :json

        json = JSON.parse(response.body)
        post_id = json['id']

        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids).to include(post_id.to_s)
      end

      it 'adds the post to the beginning of the cache' do
        old_post = create(:post, body: 'Old post')
        redis.lpush('tl:global', old_post.id)

        post '/api/posts', params: valid_params, as: :json

        json = JSON.parse(response.body)
        new_post_id = json['id']

        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids.first).to eq(new_post_id.to_s)
      end
    end

    context 'with invalid parameters' do
      it 'returns an error when body is blank' do
        post '/api/posts', params: { post: { body: '' } }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include("can't be blank")
      end

      it 'returns an error when body exceeds 140 characters' do
        post '/api/posts', params: { post: { body: 'a' * 141 } }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('too long')
      end

      it 'does not cache invalid posts' do
        post '/api/posts', params: { post: { body: '' } }, as: :json

        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids).to be_empty
      end
    end
  end

  describe 'GET /api/posts' do
    context 'when cache is empty' do
      it 'returns posts from database' do
        posts = create_list(:post, 3)

        get '/api/posts', as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end

      it 'returns posts in descending order by created_at' do
        old_post = create(:post, body: 'Old post', created_at: 2.days.ago)
        new_post = create(:post, body: 'New post', created_at: 1.day.ago)

        get '/api/posts', as: :json

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

        get '/api/posts', as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(5)
      end

      it 'maintains the cache order' do
        old_post = create(:post, body: 'Old post')
        new_post = create(:post, body: 'New post')

        redis.lpush('tl:global', old_post.id)
        redis.lpush('tl:global', new_post.id)

        get '/api/posts', as: :json

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

        get '/api/posts', as: :json

        json = JSON.parse(response.body)
        expect(json.length).to eq(2)
        expect(json.map { |p| p['id'] }).to contain_exactly(post1.id, post3.id)
      end
    end

    context 'with limit parameter' do
      it 'respects the limit parameter' do
        create_list(:post, 10)

        get '/api/posts', params: { limit: 5 }, as: :json

        json = JSON.parse(response.body)
        expect(json.length).to eq(5)
      end

      it 'defaults to 50 posts when no limit is provided' do
        create_list(:post, 60)

        get '/api/posts', as: :json

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

        get '/api/posts', as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end
    end
  end

  # Integration Tests: Full Flow
  describe 'Integration: Full Flow' do
    context 'complete post creation to timeline retrieval flow' do
      it 'creates posts, caches them in Redis, and retrieves them in correct order' do
        # Step 1: Create first post
        post '/api/posts',
             params: { post: { body: 'First post' } },
             as: :json

        expect(response).to have_http_status(:created)
        first_post = JSON.parse(response.body)

        # Verify Redis cache
        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids).to eq([first_post['id'].to_s])

        # Step 2: Create second post
        post '/api/posts',
             params: { post: { body: 'Second post' } },
             as: :json

        expect(response).to have_http_status(:created)
        second_post = JSON.parse(response.body)

        # Verify Redis cache has both posts in correct order
        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids).to eq([second_post['id'].to_s, first_post['id'].to_s])

        # Step 3: Retrieve timeline
        get '/api/posts', as: :json

        expect(response).to have_http_status(:ok)
        timeline = JSON.parse(response.body)

        # Verify timeline order (newest first)
        expect(timeline.length).to eq(2)
        expect(timeline[0]['id']).to eq(second_post['id'])
        expect(timeline[0]['body']).to eq('Second post')
        expect(timeline[1]['id']).to eq(first_post['id'])
        expect(timeline[1]['body']).to eq('First post')
      end

      it 'handles mixed cache and database scenarios correctly' do
        # Create posts directly in database (simulating old posts not in cache)
        old_posts = create_list(:post, 3, created_at: 2.days.ago)

        # Create new posts via API (will be cached)
        post '/api/posts',
             params: { post: { body: 'New cached post' } },
             as: :json

        new_post = JSON.parse(response.body)

        # Verify only new post is in cache
        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids).to eq([new_post['id'].to_s])

        # Retrieve timeline - should get cached post first
        get '/api/posts', as: :json

        timeline = JSON.parse(response.body)
        expect(timeline.first['id']).to eq(new_post['id'])
      end

      it 'maintains cache integrity after multiple operations' do
        # Create 10 posts
        post_ids = []
        10.times do |i|
          post '/api/posts',
               params: { post: { body: "Post #{i + 1}" } },
               as: :json

          post_ids << JSON.parse(response.body)['id']
        end

        # Verify cache has all posts
        cached_ids = redis.lrange('tl:global', 0, -1)
        expect(cached_ids.map(&:to_i)).to eq(post_ids.reverse)

        # Retrieve timeline
        get '/api/posts', as: :json

        timeline = JSON.parse(response.body)
        expect(timeline.length).to eq(10)
        expect(timeline.first['body']).to eq('Post 10')
        expect(timeline.last['body']).to eq('Post 1')
      end
    end
  end

  # Error Cases: 422 and 500
  describe 'Error Handling' do
    context '422 Unprocessable Entity errors' do
      it 'returns 422 for empty body' do
        post '/api/posts',
             params: { post: { body: '' } },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
        expect(json['error']).to match(/can't be blank/)
      end

      it 'returns 422 for nil body' do
        post '/api/posts',
             params: { post: { body: nil } },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end

      it 'returns 422 for body exceeding 140 characters' do
        long_body = 'a' * 141
        post '/api/posts',
             params: { post: { body: long_body } },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
        expect(json['error']).to match(/too long/)
      end

      it 'returns 422 for body with exactly 141 characters' do
        post '/api/posts',
             params: { post: { body: 'x' * 141 } },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'accepts body with exactly 140 characters' do
        valid_body = 'y' * 140
        post '/api/posts',
             params: { post: { body: valid_body } },
             as: :json

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['body']).to eq(valid_body)
      end

      it 'does not create post or cache when validation fails' do
        initial_count = Post.count

        post '/api/posts',
             params: { post: { body: '' } },
             as: :json

        expect(Post.count).to eq(initial_count)
        expect(redis.lrange('tl:global', 0, -1)).to be_empty
      end
    end

    context '500 Internal Server Error simulation' do
      it 'handles database errors gracefully' do
        # Simulate database error during save
        allow_any_instance_of(Post).to receive(:save).and_raise(ActiveRecord::StatementInvalid.new('Database error'))

        expect {
          post '/api/posts',
               params: { post: { body: 'Test post' } },
               as: :json
        }.to raise_error(ActiveRecord::StatementInvalid)
      end

      it 'continues to work when Redis is down during post creation' do
        # Simulate Redis error
        allow_any_instance_of(PostCacheService).to receive(:cache_post).and_raise(Redis::BaseError.new('Redis unavailable'))

        # Should still create the post even if caching fails
        expect {
          post '/api/posts',
               params: { post: { body: 'Test post' } },
               as: :json
        }.to change(Post, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'falls back to database when Redis fails during retrieval' do
        posts = create_list(:post, 3)

        # Simulate Redis error
        allow_any_instance_of(PostCacheService).to receive(:get_cached_ids).and_raise(Redis::BaseError.new('Redis error'))

        get '/api/posts', as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end
    end
  end

  # Edge Cases
  describe 'Edge Cases' do
    it 'handles empty timeline gracefully' do
      get '/api/posts', as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end

    it 'respects cache limit of 50 posts' do
      # Create 60 posts
      60.times do |i|
        post '/api/posts',
             params: { post: { body: "Post #{i + 1}" } },
             as: :json
      end

      # Verify cache only has 50 posts
      cached_ids = redis.lrange('tl:global', 0, -1)
      expect(cached_ids.length).to eq(50)
    end

    it 'handles special characters in post body' do
      special_body = "Hello 世界! 🌍 <script>alert('xss')</script>"
      post '/api/posts',
           params: { post: { body: special_body } },
           as: :json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['body']).to eq(special_body)
    end

    it 'handles concurrent post creation correctly' do
      # Simulate concurrent requests by creating multiple posts rapidly
      threads = []
      5.times do |i|
        threads << Thread.new do
          post '/api/posts',
               params: { post: { body: "Concurrent post #{i}" } },
               as: :json
        end
      end
      threads.each(&:join)

      # All posts should be created
      expect(Post.count).to eq(5)

      # Cache should have all post IDs
      cached_ids = redis.lrange('tl:global', 0, -1)
      expect(cached_ids.length).to eq(5)
    end
  end
end
