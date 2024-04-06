class AddApiTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    change_table :users do |t|
      t.string :api_token, index: true
    end
  end
end
