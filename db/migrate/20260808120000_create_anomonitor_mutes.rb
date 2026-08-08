class CreateAnomonitorMutes < ActiveRecord::Migration[6.1]
  def change
    create_table :anomonitor_mutes do |t|
      t.string :metric
      t.string :rule
      t.string :source
      t.string :tenant
      t.datetime :muted_until, null: false
      t.string :reason
      t.timestamps
    end

    add_index :anomonitor_mutes, :muted_until
    add_index :anomonitor_mutes, :tenant
  end
end
