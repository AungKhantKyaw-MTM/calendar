class AddEventTimesToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :event_start_time, :datetime
    add_column :events, :event_end_time, :datetime
  end
end
