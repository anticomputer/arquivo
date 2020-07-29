class TimelineController < ApplicationController
  def index
    @all_entries = Entry.for_notebook(current_notebook).visible.hitherto.
      order(occurred_at: :desc).paginate(page: params[:page])

    @entries = @all_entries.group_by do |e|
      e.occurred_at_date
    end
  end

  def agenda
    @todays_date = Time.current.strftime("%Y-%m-%d")
    @entries = current_notebook.entries.today.visible.order(occurred_at: :asc)

    @reminder_entry = Search.find(notebook: @current_notebook, query: "#winddown").where("occurred_at < ?", Time.current.beginning_of_day).first
    @reminder_entry_date = @reminder_entry&.occurred_at&.strftime("%Y-%m-%d")

    @entry = Entry.new(occurred_at: Time.now)
  end

  def search
    @search_query = params[:query]

    if @search_query.present?
      @all_entries = Search.find(notebook: current_notebook,
                            query: @search_query).paginate(page: params[:page])

      @entries = @all_entries.group_by do |e|
        e.occurred_at_date
      end

      render :search
    else
      redirect_to timeline_path(notebook: current_notebook)
    end
  end

  def todo
    @search_query = '"- [ ]"'
    @all_entries = Search.find(notebook: current_notebook,
                               query: @search_query).paginate(page: params[:page])

    @entries = @all_entries.group_by do |e|
      e.occurred_at_date
    end
  end
end
