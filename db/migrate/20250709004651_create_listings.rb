class CreateListings < ActiveRecord::Migration[8.0]
  def change
    create_table :listings do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :external_url, null: false
      t.string :platform, null: false
      t.string :location, null: false
      t.string :view_type, null: false
      t.string :price_range
      t.references :user, null: false, foreign_key: true
      t.boolean :active, default: true
      t.datetime :verified_at
      t.text :admin_notes

      t.timestamps
    end

    add_index :listings, :external_url, unique: true
    add_index :listings, [:active, :view_type]
    add_index :listings, :location
    add_index :listings, :platform
    add_index :listings, :created_at
  end
end
