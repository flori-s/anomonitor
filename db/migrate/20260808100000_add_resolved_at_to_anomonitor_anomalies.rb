class AddResolvedAtToAnomonitorAnomalies < ActiveRecord::Migration[6.1]
  def change
    add_column :anomonitor_anomalies, :resolved_at, :datetime
    add_index :anomonitor_anomalies, :resolved_at
  end
end
