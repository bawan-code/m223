class CreateRetailChains < ActiveRecord::Migration[8.1]
  def change
    create_table :retail_chains do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :retail_chains, :name, unique: true
  end
end
