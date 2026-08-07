class CreateAnomonitorAnomalies < ActiveRecord::Migration[7.0]
  def change
    create_table :anomonitor_anomalies do |t|
      t.string :rule, null: false
      t.string :source, null: false
      t.string :metric, null: false
      t.float :value, null: false
      t.float :threshold
      t.string :severity, null: false, default: "high"
      t.string :cooldown_key, null: false
      t.json :tags, default: {}
      t.datetime :sampled_at
      t.string :webhook_status, default: "pending"
      t.datetime :webhook_delivered_at

      t.timestamps
    end

    add_index :anomonitor_anomalies, :cooldown_key
    add_index :anomonitor_anomalies, :created_at
    add_index :anomonitor_anomalies, [:source, :metric]
  end
end
