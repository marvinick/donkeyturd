class AddExternalDataToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :external_id, :string
    add_column :listings, :external_source, :string # e.g., 'tripadvisor', 'google_places', 'foursquare'
    add_column :listings, :external_data, :text     # JSON data from API
    add_column :listings, :import_status, :string, default: 'manual' # 'manual', 'imported', 'synced', 'failed'
    
    add_index :listings, [:external_source, :external_id], unique: true
    add_index :listings, :import_status
  end
end
