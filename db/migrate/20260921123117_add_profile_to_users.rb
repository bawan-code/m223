class AddProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string, null: false, default: ""
    # enum: benutzer (0), moderator (1), administrator (2)
    add_column :users, :role, :integer, null: false, default: 0
    # Neue E-Mail-Adresse bis zur Bestätigung über den Link
    add_column :users, :unconfirmed_email, :string
    # Gesetzt, wenn ein Administrator das Konto gesperrt hat
    add_column :users, :locked_at, :datetime
  end
end
