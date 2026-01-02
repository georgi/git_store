# frozen_string_literal: true

# Controller for audited records with compliance features.
# Provides CRUD operations, history, and compliance proof generation.
#
class RecordsController < ApplicationController
  before_action :set_record, only: [:show, :edit, :update, :destroy, :history, :state_at, :proof, :diff]
  before_action :refresh_store
  before_action :log_access, only: [:show, :proof]

  # GET /records
  # List all audited records
  def index
    @page = (params[:page] || 1).to_i
    @records = AuditedRecord.all(page: @page, per_page: 25)
    @types = AuditedRecord.types
  end

  # GET /records/search
  # Search records
  def search
    @query = params[:q].to_s.strip
    @records = @query.present? ? AuditedRecord.search(@query) : []
  end

  # GET /records/types
  # List available record types
  def types
    @types = AuditedRecord.types
  end

  # GET /records/:composite_id
  # Show a specific record
  def show
    respond_to do |format|
      format.html
      format.json { render json: @record.to_hash }
    end
  end

  # GET /records/new
  # Form for new record
  def new
    @record = AuditedRecord.new(
      record_type: params[:type] || 'document',
      record_id: params[:id]
    )
  end

  # GET /records/:composite_id/edit
  # Edit form
  def edit
  end

  # POST /records
  # Create a new audited record
  def create
    @record = AuditedRecord.new(record_params)
    @record.data = parse_data(params[:record][:data_text])

    if @record.save(author: current_user, message: params[:commit_message])
      redirect_to record_path(@record.composite_id), notice: 'Record was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /records/:composite_id
  # Update a record
  def update
    @record.data = parse_data(params[:record][:data_text])

    if @record.save(author: current_user, message: params[:commit_message])
      redirect_to record_path(@record.composite_id), notice: 'Record was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /records/:composite_id
  # Note: In audit systems, deletion might be prohibited for compliance
  def destroy
    # For audit systems, we typically don't allow hard deletes
    # Instead, we might mark as deleted
    @record.data = @record.data.merge('_deleted' => true, '_deleted_at' => Time.current.iso8601)
    @record.save(author: current_user, message: "Marked as deleted: #{@record.composite_id}")

    redirect_to records_path, notice: 'Record was marked as deleted.'
  end

  # GET /records/:composite_id/history
  # Full revision history
  def history
    @revisions = @record.revisions(limit: 100)
  end

  # GET /records/:composite_id/state_at?timestamp=2024-01-15T10:00:00Z
  # Get record state at a point in time
  def state_at
    timestamp = params[:timestamp] ? Time.parse(params[:timestamp]) : 1.day.ago
    @historical_record = @record.state_at(timestamp)
    @timestamp = timestamp
  end

  # GET /records/:composite_id/proof
  # Generate existence proof for compliance
  def proof
    @proof = @record.existence_proof

    respond_to do |format|
      format.html
      format.json { render json: @proof }
    end
  end

  # GET /records/:composite_id/diff?commit_id=abc123
  # Show diff between versions
  def diff
    @commit_id = params[:commit_id]
    @diff = @record.diff_with(@commit_id) if @commit_id
  end

  private

  def set_record
    @record = AuditedRecord.find_by_composite_id(params[:composite_id])
    redirect_to records_path, alert: 'Record not found.' unless @record
  end

  def refresh_store
    Rails.application.config.audit_store.refresh!
  end

  def record_params
    params.require(:record).permit(:record_type, :record_id)
  end

  def parse_data(text)
    return {} if text.blank?
    YAML.safe_load(text, permitted_classes: [Symbol, Date, Time])
  rescue Psych::SyntaxError => e
    flash.now[:alert] = "Invalid YAML: #{e.message}"
    {}
  end

  def log_access
    return unless @record

    AuditService.log_access(
      record_type: @record.record_type,
      record_id: @record.record_id,
      user: current_user,
      action: action_name
    )
  end

  def current_user
    @current_user ||= OpenStruct.new(
      name: session[:user_name] || 'Auditor',
      email: session[:user_email] || 'auditor@example.com'
    )
  end
  helper_method :current_user
end
