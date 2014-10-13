require 'digest/sha1'

namespace :scheduler do
  desc "TODO"
  task retrieve_articles: :environment do
    response = RestClient.get 'http://api.nytimes.com/svc/news/v3/content/all/all/.json?api-key=5fa60494024b4c3c13ecb72011023ad8:11:69972922'
    response = JSON.parse(response)
    response['results'].each do |article|
      retrieved = Article.where(:url => article['url']).all[0]
      # id = djb2a article['url']
      # retrieved = Article.find(id)
      if retrieved
        retrieved.set(article)
      else
        # article["_id"] = BSON::ObjectId.from_string id.to_s
        article = Article.create article
        article.save!
      end
    end
  end

  # creates a 24 character hash using the djb2a algorithm + appending 0's
  def djb2a str
    hash = 5381
    str.each_byte do |b|
      hash = (((hash << 5) + hash) ^ b) % (2 ** 32)
    end
    hash = hash.to_s + '0' * (24 - hash.to_s.length)
  end
end
