module Api
  class PostsController < ApplicationController
    # POST /api/posts
    def create
      @post = Post.new(post_params.merge(author_name: 'guest'))

      if @post.save
        render json: @post, status: :created
      else
        render json: { error: @post.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end

    # GET /api/posts
    def index
      limit = params[:limit]&.to_i || 50
      @posts = Post.order(created_at: :desc).limit(limit)
      render json: @posts
    end

    private

    def post_params
      params.permit(:body)
    end
  end
end
