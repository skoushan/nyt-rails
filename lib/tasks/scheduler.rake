require 'digest/sha1'
require 'date'

namespace :scheduler do
  desc "Retrieves the 20 most recent articles from the Newswire API. This happens every ten minutes. It works assuming that articles are not producer faster than 2 per minute (on average)."
  task retrieve_articles: :environment do
    response = RestClient.get 'http://api.nytimes.com/svc/news/v3/content/all/all/.json?api-key=5fa60494024b4c3c13ecb72011023ad8:11:69972922'
    response = JSON.parse(response)
    response['results'].each do |article|
      retrieved = Article.where(:url => article['url']).all[0] # safe to assume there is only one because this field is set to be unique
      if retrieved
        retrieved.set(article) # update article
      else
        article = Article.create article
        article.save!
      end
    end
  end

  desc "Retrieves all the sections from the Newswire API."
  task retrieve_sections: :environment do
    response = RestClient.get 'http://api.nytimes.com/svc/news/v3/content/section-list.json?api-key=5fa60494024b4c3c13ecb72011023ad8:11:69972922'
    response = JSON.parse(response)
    response['results'].each_with_index do |section|
      retrieved = Section.where(:section => section['section']).all[0] # safe to assume there is only one because this field is set to be unique
      if retrieved
        retrieved.set(section)
      else
        section = Section.create section
        section['order'] = Section.count + 1
        section.save!
      end
    end
  end

  desc "Retrieves popularity info using the Most Popular API"
  task retrieve_popularity: :environment do
    popularity_types = [
        { url: 'mostviewed', name: 'view' } ,
        { url: 'mostshared', name: 'share' } ]

    popularity_types.each do |popularity_type|
      offset = 0
      loop do
        response = RestClient.get "http://api.nytimes.com/svc/mostpopular/v2/#{popularity_type[:url]}/all-sections/1.json?offset=#{offset}&api-key=7e50471e4abb9b539dbf73e6c69cb4b4:18:69972922"
        response = JSON.parse(response)
        response['results'].each_with_index do |article, index|
          retrieved = Article.where(url: article['url']).all
          if retrieved && retrieved[0] # if the article exists
            retrieved = retrieved[0]
            rank = offset + index + 1 # rank starts at 1
            retrieved["prev_#{popularity_type[:name]}_rank"] = retrieved["cur_#{popularity_type[:name]}_rank"]
            retrieved["cur_#{popularity_type[:name]}_rank"] = rank
            if retrieved["peak_#{popularity_type[:name]}_rank"] == nil or rank < retrieved["peak_#{popularity_type[:name]}_rank"]
              retrieved["peak_#{popularity_type[:name]}_rank"] = rank
            end
            puts "#{popularity_type[:name]} ##{rank}: #{retrieved.title}"
            retrieved.save!
          end
        end
        count = response['results'].length
        offset += count
        break if response['num_results'] - offset - count <= 0
      end
    end
  end

  desc "Calculates a composite score for an article based on its created_date and popularity rank"
  task calculate_scores: :environment do
    calculate_scores
  end

  def calculate_scores
    Article.all.each do |article|
      # convert rankings (lower is better) to a popularity measure (higher is better) by inverting it
      prev_view = article['prev_view_rank'] == 0 ? 0 : 1.0/article['prev_view_rank']
      prev_share = article['prev_share_rank'] == 0 ? 0 : 1.0/article['prev_share_rank']
      prev_pop = 0.5*prev_view + 0.5*prev_share

      cur_view = article['cur_view_rank'] == 0 ? 0 : 1.0/article['cur_view_rank']
      cur_share = article['cur_share_rank'] == 0 ? 0 : 1.0/article['cur_share_rank']
      cur_pop = 0.5*cur_view + 0.5*cur_share

      peak_view = article['peak_view_rank'] == 0 ? 0 : 1.0/article['peak_view_rank']
      peak_share = article['peak_share_rank'] == 0 ? 0 : 1.0/article['peak_share_rank']
      peak_pop = 0.5*peak_view + 0.5*peak_share

      trending_factor = cur_pop - prev_pop

      article['score'] = article['created_date'].to_i + 20*60*60*(24*cur_pop + 12*trending_factor + 12*peak_pop)
      article.save!
    end
  end

  desc "Converts empty strings to arrays (that's how Times returns it to us)"
  task fix_multimedia: :environment do
    Article.all.each do |article|
      if article[:multimedia] == ""
        article[:multimedia] = []
        article.save!
      end
    end
  end

  # creates a 24 character hash using the djb2a algorithm and then appending 0's
  def djb2a str
    hash = 5381
    str.each_byte do |b|
      hash = (((hash << 5) + hash) ^ b) % (2 ** 32)
    end
    hash = hash.to_s + '0' * (24 - hash.to_s.length)
  end
end
