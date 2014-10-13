module Api
  class SectionsController < Api::BaseController

    private

    def article_params
      params.require(:section).permit(:display_name)
    end

    def query_params
      params.permit(:display_name)
    end

    def query_sort
      :display_name.asc
    end
  end
end