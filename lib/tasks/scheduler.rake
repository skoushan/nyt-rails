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

  desc "Retrieve sections"
  task retrieve_sections: :environment do
    response = RestClient.get 'http://api.nytimes.com/svc/news/v3/content/section-list.json?api-key=5fa60494024b4c3c13ecb72011023ad8:11:69972922'
    response = JSON.parse(response)
    response['results'].each do |section|
      retrieved = Section.where(:section => section['section']).all[0]
      if retrieved
        retrieved.set(section)
      else
        section = Section.create section
        section.save
      end
    end
  end

  desc 'Retrieve popularity'
  task retrieve_popularity: :environment do
    popularity_types = [
        { url: 'mostviewed',
          name: 'view'} ,
        { url: 'mostshared',
          name: 'shared'}]

    popularity_types.each do |popularity_type|
      offset = 0
      loop do
        response = RestClient.get "http://api.nytimes.com/svc/mostpopular/v2/#{popularity_type[:url]}/all-sections/1.json?offset=#{offset}&api-key=7e50471e4abb9b539dbf73e6c69cb4b4:18:69972922"
        response = JSON.parse(response)
        response['results'].each_with_index do |article, index|
          retrieved = Article.where(url: article['url']).all
          if retrieved && retrieved[0]
            rank = offset + index + 1
            retrieved = retrieved[0]
            retrieved["prev_#{popularity_type[:name]}_rank"] = retrieved["cur_#{popularity_type[:name]}_rank"]
            retrieved["cur_#{popularity_type[:name]}_rank"] = rank
            if retrieved["peak_#{popularity_type[:name]}_rank"] == nil or rank > retrieved["peak_#{popularity_type[:name]}_rank"]
              retrieved["peak_#{popularity_type[:name]}_rank"] = rank
            end
            puts "#{rank}: #{retrieved.title}"
            retrieved.save!
          end
        end
        count = response['results'].length
        offset += count
        break if response['num_results'] - offset - count <= 0
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
