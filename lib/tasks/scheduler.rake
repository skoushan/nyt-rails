require 'digest/sha1'
require 'date'

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
          name: 'share'}]

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

  desc 'Calculate scores'
  task calculate_scores: :environment do
    calculate_scores
  end

  def calculate_scores
    Article.all.each do |article|
      prev_pop_rank = 0.5*article['prev_view_rank'] + 0.5*article['prev_share_rank']
      prev_pop = prev_pop_rank == 0 ? 0 : 1/prev_pop_rank

      cur_pop_rank = 0.5*article['cur_view_rank'] + 0.5*article['cur_share_rank']
      cur_pop = cur_pop_rank == 0 ? 0 : 1/cur_pop_rank

      peak_pop_rank = 0.5*article['peak_view_rank'] + 0.5*article['peak_share_rank']
      peak_pop = peak_pop_rank == 0 ? 0 : 1/peak_pop_rank

      delta_pop = cur_pop - prev_pop

      article['score'] = article['updated_date'].to_i + 18*60*60*cur_pop + 8*60*60*delta_pop + 4*60*60*peak_pop
      article.save!
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
