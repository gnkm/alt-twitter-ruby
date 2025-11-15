require 'rails_helper'

RSpec.describe PostCacheService, type: :service do
  let(:redis) { Redis.new }
  let(:service) { described_class.new }

  before do
    # Clean up Redis before each test
    redis.del('tl:global')
  end

  after do
    # Clean up Redis after each test
    redis.del('tl:global')
  end

  describe '#cache_post' do
    it 'adds post ID to the beginning of the global timeline cache' do
      post = create(:post)

      service.cache_post(post)

      cached_ids = redis.lrange('tl:global', 0, -1)
      expect(cached_ids).to eq([post.id.to_s])
    end

    it 'maintains the most recent 50 posts' do
      # Create 51 posts
      posts = (1..51).map { create(:post) }

      # Cache all posts
      posts.each { |post| service.cache_post(post) }

      # Only 50 should remain
      cached_ids = redis.lrange('tl:global', 0, -1)
      expect(cached_ids.length).to eq(50)

      # The newest 50 posts should be cached (excluding the oldest)
      expected_ids = posts.reverse[0..49].map { |p| p.id.to_s }
      expect(cached_ids).to eq(expected_ids)
    end

    it 'adds new posts to the beginning of the list' do
      old_post = create(:post, body: 'Old post')
      new_post = create(:post, body: 'New post')

      service.cache_post(old_post)
      service.cache_post(new_post)

      cached_ids = redis.lrange('tl:global', 0, -1)
      expect(cached_ids.first).to eq(new_post.id.to_s)
      expect(cached_ids.second).to eq(old_post.id.to_s)
    end
  end

  describe '#get_cached_ids' do
    it 'retrieves the specified number of post IDs from cache' do
      posts = []
      10.times { posts << create(:post) }

      # Cache all posts (lpush adds to front, so last post added is first in list)
      posts.each { |post| service.cache_post(post) }

      cached_ids = service.get_cached_ids(5)

      expect(cached_ids.length).to eq(5)
      # Should return the most recently cached 5 posts (in reverse order of creation)
      expect(cached_ids).to eq(posts.reverse[0..4].map(&:id))
    end

    it 'returns an empty array when cache is empty' do
      cached_ids = service.get_cached_ids(10)

      expect(cached_ids).to eq([])
    end

    it 'returns all available IDs when fewer than limit exist' do
      posts = []
      3.times { posts << create(:post) }

      # Cache all posts
      posts.each { |post| service.cache_post(post) }

      cached_ids = service.get_cached_ids(10)

      expect(cached_ids.length).to eq(3)
      # Should return IDs in order they were cached (newest first)
      expect(cached_ids).to eq(posts.reverse.map(&:id))
    end

    it 'defaults to 50 when no limit is specified' do
      posts = []
      60.times { posts << create(:post) }

      # Cache all posts
      posts.each { |post| service.cache_post(post) }

      cached_ids = service.get_cached_ids

      expect(cached_ids.length).to eq(50)
    end
  end

  describe 'Redis connection error handling' do
    it 'handles Redis connection errors gracefully in cache_post' do
      post = create(:post)
      allow(redis).to receive(:lpush).and_raise(Redis::CannotConnectError)
      allow(service).to receive(:redis).and_return(redis)

      expect { service.cache_post(post) }.not_to raise_error
    end

    it 'returns empty array on Redis connection errors in get_cached_ids' do
      allow(redis).to receive(:lrange).and_raise(Redis::CannotConnectError)
      allow(service).to receive(:redis).and_return(redis)

      result = service.get_cached_ids(10)

      expect(result).to eq([])
    end
  end
end
