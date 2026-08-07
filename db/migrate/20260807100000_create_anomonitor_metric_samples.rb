class CreateAnomonitorMetricSamples < ActiveRecord::Migration[7.0]
  def change
    create_table :anomonitor_metric_samples do |t|
      t.string :source, null: false
      t.string :metric, null: false
      t.float :value, null: false, default: 0
      t.json :tags, default: {}
      t.datetime :sampled_at, null: false

      t.timestamps
    end

    add_index :anomonitor_metric_samples, [:source, :metric, :sampled_at],
              name: "idx_anomonitor_samples_source_metric_time"
    add_index :anomonitor_metric_samples, :sampled_at
  end
end
