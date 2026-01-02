# frozen_string_literal: true

# Controller for managing versioned application configurations.
# Provides CRUD operations with full version history and rollback support.
#
# NOTE: This controller expects to inherit from ApplicationController which should
# have CSRF protection enabled (protect_from_forgery with: :exception).
# See Rails security guide: https://guides.rubyonrails.org/security.html
#
class ConfigsController < ApplicationController
  before_action :set_config, only: [:show, :edit, :update, :destroy, :history, :rollback, :diff]
  before_action :refresh_store

  # GET /configs
  # List all configurations grouped by directory
  def index
    @configs = if params[:q].present?
                 ConfigEntry.search(params[:q])
               else
                 ConfigEntry.all
               end
    @grouped_configs = @configs.group_by { |c| File.dirname(c.path) }
  end

  # GET /configs/environments
  # List available environments
  def environments
    @environments = ConfigEntry.environments
  end

  # GET /configs/environment/:env
  # Show configs for a specific environment
  def environment
    @environment = params[:env]
    @configs = ConfigEntry.for_environment(@environment)
  end

  # GET /configs/:path
  # Show a specific configuration
  def show
    respond_to do |format|
      format.html
      format.json { render json: @config.to_hash }
      format.yaml { render plain: @config.value.to_yaml }
    end
  end

  # GET /configs/new
  # Form to create a new configuration
  def new
    @config = ConfigEntry.new(path: params[:path])
  end

  # GET /configs/:path/edit
  # Form to edit a configuration
  def edit
  end

  # POST /configs
  # Create a new configuration
  def create
    @config = ConfigEntry.new(config_params)
    @config.value = parse_value(params[:config][:value_text], @config.path)

    if @config.save(author: current_user, message: params[:commit_message])
      redirect_to config_path(@config.path), notice: 'Configuration was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /configs/:path
  # Update a configuration
  def update
    @config.value = parse_value(params[:config][:value_text], @config.path)

    if @config.save(author: current_user, message: params[:commit_message])
      redirect_to config_path(@config.path), notice: 'Configuration was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /configs/:path
  # Delete a configuration
  def destroy
    @config.destroy(author: current_user, message: params[:commit_message])
    redirect_to configs_path, notice: 'Configuration was successfully deleted.'
  end

  # GET /configs/:path/history
  # Show version history
  def history
    @commits = @config.history(limit: 50)
  end

  # POST /configs/:path/rollback
  # Rollback to a previous version
  def rollback
    commit_id = params[:commit_id]

    if @config.rollback_to(commit_id: commit_id, author: current_user)
      redirect_to config_path(@config.path), notice: "Successfully rolled back to version #{commit_id[0..7]}."
    else
      redirect_to history_config_path(@config.path), alert: 'Failed to rollback.'
    end
  end

  # GET /configs/:path/diff
  # Show diff between versions
  def diff
    @from_commit = params[:from]
    @to_commit = params[:to] || store.head&.id

    if @from_commit && @to_commit
      @diff = @config.diff_with(@from_commit)
      @from_version = @config.version_at(@from_commit)
      @to_version = @config.version_at(@to_commit)
    else
      redirect_to history_config_path(@config.path), alert: 'Please select two versions to compare.'
    end
  end

  private

  def set_config
    @config = ConfigEntry.find!(params[:path])
  rescue ConfigEntry::RecordNotFound
    redirect_to new_config_path(path: params[:path])
  end

  def refresh_store
    store.refresh!
  end

  def config_params
    params.require(:config).permit(:path)
  end

  def parse_value(text, path)
    return {} if text.blank?

    ext = File.extname(path).delete('.')
    case ext
    when 'json'
      JSON.parse(text)
    when 'yml', 'yaml'
      YAML.safe_load(text, permitted_classes: [Date, Time])
    else
      text
    end
  rescue JSON::ParserError, Psych::SyntaxError => e
    flash.now[:alert] = "Invalid #{ext.upcase}: #{e.message}"
    nil
  end

  def store
    Rails.application.config.config_store
  end

  def current_user
    @current_user ||= OpenStruct.new(
      name: session[:user_name] || 'Admin',
      email: session[:user_email] || 'admin@example.com'
    )
  end
  helper_method :current_user
end
