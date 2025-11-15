# Redis configuration for caching
Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1'))
