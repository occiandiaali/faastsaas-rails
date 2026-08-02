class AddStrategistTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :strategist_token, :string
  end
end
