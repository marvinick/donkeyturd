class CreateCities < ActiveRecord::Migration[8.0]
  def change
    create_table :cities do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :country, null: false
      t.string :state_province
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.text :description
      t.boolean :featured, default: false
      t.integer :listings_count, default: 0

      t.timestamps
    end
    
    add_index :cities, :slug, unique: true
    add_index :cities, [:country, :state_province]
    add_index :cities, :featured
    add_index :cities, [:latitude, :longitude]
  end
end
