module Api
  class SectionsController < Api::BaseController

    private

    def query_params
      params.permit(:display_name)
    end

    def query_sort
      :order.asc
    end
  end
end