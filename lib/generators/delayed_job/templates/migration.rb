superclass = if ActiveRecord.version >= Gem::Version.new(5)
              ActiveRecord::Migration[5.0]
            else
              ActiveRecord::Migration
            end

class AddMetadataToDelayedJobs < superclass
  def self.up
    add_column :delayed_jobs, :metadata, :text
  end

  def self.down
    remove_column :delayed_jobs, :metadata
  end
end
