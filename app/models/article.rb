class Article
  include MongoMapper::Document

  key :title, String
  key :url, String, :unique => true

  key :prev_view_rank, Integer, :default => 0
  key :cur_view_rank, Integer, :default => 0
  key :peak_view_rank, Integer, :default => 0

  key :prev_share_rank, Integer, :default => 0
  key :cur_share_rank, Integer, :default => 0
  key :peak_share_rank, Integer, :default => 0

  key :score, Integer, :default => 0

  key :updated_date, Time
  key :created_date, Time
  key :published_date, Time

end
