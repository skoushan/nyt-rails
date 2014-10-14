module Api
  class ArticlesController < Api::BaseController

    private

    def article_params
      params.require(:article).permit(:title)
    end

    def query_params
      # this assumes that an article belongs to an artist and has an :artist_id
      # allowing us to filter by this
      params.permit(:section)
    end

    def query_sort
      :score.desc
    end
  end
end