class Section
  include MongoMapper::Document

  key :section, String, :unique => true
  key :display_name, String
  key :order, Integer, :default => 0

end
