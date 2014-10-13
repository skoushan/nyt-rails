if ENV["MONGOLAB_URI"]
  uri = URI.parse(ENV["MONGOLAB_URI"])
  MongoMapper.connection = Mongo::Connection.from_uri(ENV["MONGOLAB_URI"])
  MongoMapper.database = uri.path.gsub(/^\//, '')
else
  MongoMapper.connection = Mongo::Connection.new('localhost', 27017)
  MongoMapper.database = "#nyt_rails_#{Rails.env}"
end

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    MongoMapper.connection.connect if forked
  end
end