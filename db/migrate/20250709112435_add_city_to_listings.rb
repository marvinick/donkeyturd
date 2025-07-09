class AddCityToListings < ActiveRecord::Migration[8.0]
  def change
    add_reference :listings, :city, null: true, foreign_key: true, index: true
  end
end
