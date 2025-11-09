require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'validations' do
    it 'is valid with a body' do
      post = build(:post)
      expect(post).to be_valid
    end

    it 'is invalid without a body' do
      post = build(:post, body: nil)
      expect(post).not_to be_valid
      expect(post.errors[:body]).to include("can't be blank")
    end

    it 'is invalid with an empty body' do
      post = build(:post, body: '')
      expect(post).not_to be_valid
      expect(post.errors[:body]).to include("can't be blank")
    end

    it 'is valid with a body of exactly 140 characters' do
      post = build(:post, :long_body)
      expect(post).to be_valid
    end

    it 'is invalid with a body longer than 140 characters' do
      post = build(:post, body: 'a' * 141)
      expect(post).not_to be_valid
      expect(post.errors[:body]).to include('is too long (maximum is 140 characters)')
    end
  end

  describe 'default values' do
    it 'sets author_name to "guest" by default' do
      post = create(:post)
      expect(post.author_name).to eq('guest')
    end

    it 'allows overriding author_name' do
      post = create(:post, :with_custom_author)
      expect(post.author_name).to eq('custom_user')
    end
  end

  describe 'scopes/ordering' do
    it 'orders posts by created_at descending by default' do
      # Create posts with different timestamps
      old_post = create(:post, body: 'Old post', created_at: 2.days.ago)
      new_post = create(:post, body: 'New post', created_at: 1.day.ago)
      newest_post = create(:post, body: 'Newest post', created_at: Time.current)

      posts = Post.all
      expect(posts.first).to eq(newest_post)
      expect(posts.second).to eq(new_post)
      expect(posts.third).to eq(old_post)
    end
  end
end
