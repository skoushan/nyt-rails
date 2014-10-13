class Article
  include MongoMapper::Document

  key :title, String
  key :url, String, :unique => true

end