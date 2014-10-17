module Api
  class ArticlesController < Api::BaseController

    private

    def query_params
      if ['Top Stories', 'Most Popular', 'Trending', 'Most Recent'].include? params[:section]
        params.permit(:url, :title)
      else
        params.permit(:section, :url, :title)
      end
    end

    def query_sort
      if params[:section] == 'Most Popular'
        :popularity.desc
      elsif params[:section] == 'Trending'
        :trending.desc
      elsif params[:section] == 'Most Recent'
        :created_date.desc
      else
        :score.desc
      end
    end
  end
end