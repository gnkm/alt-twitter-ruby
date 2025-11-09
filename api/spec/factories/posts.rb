FactoryBot.define do
  factory :post do
    body { 'This is a sample post' }
    author_name { 'guest' }
    
    trait :long_body do
      body { 'a' * 140 }
    end
    
    trait :with_custom_author do
      author_name { 'custom_user' }
    end
  end
end
