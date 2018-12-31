class AddAuthenticationTokenToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :auth_token, :string
    add_index :users, :auth_token, unique: true
    # Add an initial auth_token to existing users
    User.all.each do |this|
      this.auth_token = Devise.friendly_token
      this.save!
    end
  end
end
