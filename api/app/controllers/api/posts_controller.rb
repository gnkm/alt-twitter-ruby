module Api
  class PostsController < ApplicationController
    DEFAULT_LIMIT = 50

    # POST /api/posts
    def create
      post = Post.new(post_params)

      if post.save
        # Cache the new post
        cache_service.cache_post(post)

        render json: post, status: :created
      else
        render json: { error: post.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end

    # GET /api/posts
    def index
      limit = params.fetch(:limit, DEFAULT_LIMIT).to_i

      # Try to get cached post IDs
      cached_ids = cache_service.get_cached_ids(limit)

      if cached_ids.any?
        # Fetch posts from DB using cached IDs, preserving order
        posts = Post.where(id: cached_ids).index_by(&:id)
        ordered_posts = cached_ids.map { |id| posts[id] }.compact
      else
        # Cache miss: fetch from DB
        ordered_posts = Post.limit(limit).to_a
      end

      render json: ordered_posts
    end

    private

    def post_params
      params.require(:post).permit(:body)
    end

    def cache_service
      @cache_service ||= PostCacheService.new
    end
  end
end
