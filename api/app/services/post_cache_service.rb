class PostCacheService
  CACHE_KEY = 'tl:global'
  MAX_CACHED_POSTS = 50
  DEFAULT_LIMIT = 50

  def initialize
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1'))
  end

  # Add a post to the cache
  # @param post [Post] The post to cache
  # @return [void]
  def cache_post(post)
    redis.lpush(CACHE_KEY, post.id)
    redis.ltrim(CACHE_KEY, 0, MAX_CACHED_POSTS - 1)
  rescue Redis::BaseError => e
    Rails.logger.error("Redis error in cache_post: #{e.message}")
    # Silently fail - caching is not critical
  end

  # Get cached post IDs
  # @param limit [Integer] Number of post IDs to retrieve
  # @return [Array<Integer>] Array of post IDs
  def get_cached_ids(limit = DEFAULT_LIMIT)
    cached_ids = redis.lrange(CACHE_KEY, 0, limit - 1)
    cached_ids.map(&:to_i)
  rescue Redis::BaseError => e
    Rails.logger.error("Redis error in get_cached_ids: #{e.message}")
    []
  end

  private

  attr_reader :redis
end
