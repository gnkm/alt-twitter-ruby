class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.text :body
      t.string :author_name

      t.timestamps
    end
    
    add_index :posts, :created_at
  end
end
