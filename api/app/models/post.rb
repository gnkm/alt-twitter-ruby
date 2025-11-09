class Post < ApplicationRecord
  # Validations
  validates :body, presence: true, length: { maximum: 140 }
  
  # Callbacks
  before_validation :set_default_author_name, on: :create
  
  # Default scope for ordering
  default_scope { order(created_at: :desc) }
  
  private
  
  def set_default_author_name
    self.author_name ||= 'guest'
  end
end
