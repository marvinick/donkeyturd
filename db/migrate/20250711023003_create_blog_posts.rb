class CreateBlogPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_posts do |t|
      t.string :title
      t.string :slug
      t.text :content
      t.text :excerpt
      t.string :meta_title
      t.text :meta_description
      t.boolean :published
      t.boolean :featured
      t.datetime :published_at
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
