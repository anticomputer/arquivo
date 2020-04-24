class TimelineController < ApplicationController
  def index
    entries = Entry.for_notebook(current_notebook).order(occurred_at: :desc)

    @entries = entries.group_by do |e|
      e.created_at.strftime("%Y-%m-%d")
    end
  end

  def search
    @search_query = params[:searchfield]

    if @search_query.present?
      entries = Search.find(notebook: current_notebook,
                            query: @search_query)

      @entries = entries.group_by do |e|
        e.created_at.strftime("%Y-%m-%d")
      end

      render :search
    else
      redirect_to timeline_path(notebook: current_notebook)
    end
  end
end
