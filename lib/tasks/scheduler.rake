require 'digest/sha1'
require 'date'

namespace :scheduler do
  desc "Retrieves the 20 most recent articles from the Newswire API. This happens every ten minutes. It works assuming that articles are not producer faster than 2 per minute (on average)."
  task retrieve_articles: :environment do
    offset = 0
    loop do
      begin
        response = RestClient.get "http://api.nytimes.com/svc/news/v3/content/all/all/.json?offset=#{offset}&api-key=5fa60494024b4c3c13ecb72011023ad8:11:69972922"
        response = JSON.parse(response)
        last_article = nil
        response['results'].each do |article|
          retrieved = Article.where(:url => article['url']).all[0] # safe to assume there is only one because this field is set to be unique
          if retrieved
            retrieved.set(article) # update article
            last_article = retrieved
          else
            article = Article.create article
            article.save!
            last_article = article
          end
        end
        offset += 20
        break if last_article == nil or last_article[:created_date] < 1.days.ago
      rescue => e
        break if e.response.code != 500
      end
    end
  end

  desc "Retrieves all the sections from the Newswire API."
  task retrieve_sections: :environment do
    Section.destroy_all
    response = RestClient.get 'http://api.nytimes.com/svc/news/v3/content/section-list.json?api-key=5fa60494024b4c3c13ecb72011023ad8:11:69972922'
    response = JSON.parse(response)
    response['results'].each_with_index do |section|
      section = Section.create section
      section['order'] = Section.count
      section.save!
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
            if retrieved["peak_#{popularity_type[:name]}_rank"] == nil or retrieved["peak_#{popularity_type[:name]}_rank"] == 0 or rank < retrieved["peak_#{popularity_type[:name]}_rank"]
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

  def calculate_pop(article, type, lowest)
    view = article["#{type}_view_rank".to_sym] == 0 ? 0 : (lowest["#{type}_view"] - article["#{type}_view_rank".to_sym])/(lowest["#{type}_view"] - 1.0)

    share = article["#{type}_share_rank".to_sym] == 0 ? 0 : (lowest["#{type}_share"] - article["#{type}_share_rank".to_sym])/(lowest["#{type}_share"] - 1.0)

    pop = 0.5*view + 0.5*share
    pop
  end

  def calculate_scores
    newest = Article.sort(:created_date.desc).first[:created_date]
    oldest = Article.sort(:created_date.asc).first[:created_date]

    as = ['prev', 'cur', 'peak']
    bs = ['view', 'share']

    lowest = Hash.new

    as.each do |a|
      bs.each do |b|
        lowest["#{a}_#{b}"] = Article.sort("#{a}_#{b}_rank".to_sym.desc).first["#{a}_#{b}_rank".to_sym]
      end
    end

    total = Article.count

    Article.sort(:created_date.desc).all.each_with_index do |article, index|
      puts "#{index + 1} of #{total}"
      prev_pop = calculate_pop(article, 'prev', lowest)
      cur_pop = calculate_pop(article, 'cur', lowest)
      peak_pop = calculate_pop(article, 'peak', lowest)
      trending_factor = cur_pop - prev_pop

      popularity = (3*cur_pop + trending_factor + peak_pop)/5

      recentness = (article[:created_date].to_f - oldest.to_f)/(newest.to_f - oldest.to_f)

      score = (0.5*recentness + 0.1*popularity + 0.3*recentness*popularity)*1000000000000
      article['score'] = score
      article['popularity'] = popularity*1000000000000
      article['trending'] = trending_factor*1000000000000
      article.save!
    end
  end

  desc "Converts empty strings to arrays (that's how Times returns it to us)"
  task fix_multimedia: :environment do
    Article.all.each do |article|
      if article[:multimedia] == ''
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
