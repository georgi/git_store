# frozen_string_literal: true

# Controller for wiki pages with full CRUD operations and version history.
# Provides a complete wiki experience with version control features.
#
# @example Routes
#   GET    /pages          # List all pages
#   GET    /pages/new      # New page form
#   POST   /pages          # Create page
#   GET    /pages/:slug    # Show page
#   GET    /pages/:slug/edit    # Edit form
#   PATCH  /pages/:slug    # Update page
#   DELETE /pages/:slug    # Delete page
#   GET    /pages/:slug/history # Version history
#   GET    /pages/:slug/diff    # Show diff
#   POST   /pages/:slug/rollback # Rollback to version
#
class PagesController < ApplicationController
  before_action :set_page, only: [:show, :edit, :update, :destroy, :history, :diff, :rollback, :raw]
  before_action :refresh_store

  # GET /pages
  # List all wiki pages
  def index
    @pages = Page.all
  end

  # GET /pages/recent
  # Show recently updated pages
  def recent
    @pages = Page.recent(limit: 20)
    render :index
  end

  # GET /pages/search?q=query
  # Search pages
  def search
    @query = params[:q].to_s.strip
    @pages = @query.present? ? Page.search(@query) : Page.all
    render :index
  end

  # GET /pages/:slug
  # Show a specific page
  def show
    respond_to do |format|
      format.html
      format.json { render json: @page.to_hash }
    end
  end

  # GET /pages/:slug/raw
  # Show raw markdown content
  def raw
    render plain: @page.content, content_type: 'text/plain'
  end

  # GET /pages/new
  # New page form
  def new
    @page = Page.new(slug: params[:slug])
  end

  # GET /pages/:slug/edit
  # Edit page form
  def edit
  end

  # POST /pages
  # Create a new page
  def create
    @page = Page.new(page_params)

    if @page.save(author: current_user, message: params[:commit_message])
      redirect_to page_path(@page), notice: 'Page was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /pages/:slug
  # Update a page
  def update
    @page.assign_attributes(page_params)

    if @page.save(author: current_user, message: params[:commit_message])
      redirect_to page_path(@page), notice: 'Page was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /pages/:slug
  # Delete a page
  def destroy
    @page.destroy(author: current_user, message: params[:commit_message])
    redirect_to pages_path, notice: 'Page was successfully deleted.'
  end

  # GET /pages/:slug/history
  # Show version history
  def history
    @commits = @page.history(limit: 50)
  end

  # GET /pages/:slug/diff?from=abc123&to=def456
  # Show diff between versions
  def diff
    @from_commit = params[:from]
    @to_commit = params[:to] || store.head&.id

    if @from_commit && @to_commit
      @diff = @page.diff_with(@from_commit)
      @from_version = @page.version_at(@from_commit)
      @to_version = @page.version_at(@to_commit)
    else
      redirect_to history_page_path(@page), alert: 'Please select two versions to compare.'
    end
  end

  # POST /pages/:slug/rollback
  # Rollback to a previous version
  def rollback
    commit_id = params[:commit_id]

    if @page.rollback_to(commit_id: commit_id, author: current_user)
      redirect_to page_path(@page), notice: "Successfully rolled back to version #{commit_id[0..7]}."
    else
      redirect_to history_page_path(@page), alert: 'Failed to rollback. The version may not exist.'
    end
  end

  private

  # Find the page by slug
  def set_page
    @page = Page.find!(params[:slug])
  rescue Page::RecordNotFound
    if action_name == 'show'
      redirect_to new_page_path(slug: params[:slug])
    else
      redirect_to pages_path, alert: 'Page not found.'
    end
  end

  # Refresh the store to pick up external changes
  def refresh_store
    store.refresh!
  end

  # Strong parameters for page
  def page_params
    params.require(:page).permit(:slug, :title, :content, tags: [])
  end

  # Access the GitStore
  def store
    Rails.application.config.content_store
  end

  # Helper for current user (implement based on your auth system)
  def current_user
    # Return current authenticated user
    # Example with Devise: current_user
    # Example with basic auth: request.env['REMOTE_USER']
    @current_user ||= OpenStruct.new(
      name: session[:user_name] || 'Anonymous',
      email: session[:user_email] || 'anonymous@example.com'
    )
  end
  helper_method :current_user
end
