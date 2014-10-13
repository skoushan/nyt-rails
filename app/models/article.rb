class Article
  include MongoMapper::Document

  key :title, String
  key :url, String, :unique => true

  key :prev_page_rank, Integer, :default => 0
  key :cur_page_rank, Integer, :default => 0
  key :peak_page_rank, Integer, :default => 0

  key :score, Integer, :default => 0
end
