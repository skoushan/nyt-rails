module Api
  class ArticlesController < Api::BaseController

    private

    def query_params
      if params[:section] == 'Top Stories'
        params.delete(:section)
      end
      params.permit(:section, :url, :title)
    end

    def query_sort
      :score.desc
    end
  end
end