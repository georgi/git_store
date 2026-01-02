# frozen_string_literal: true

require 'git_store'
require 'digest'

# AuditedRecord provides tamper-evident, versioned storage for audit-critical data.
# Every change creates an immutable Git commit with cryptographic proof of existence.
#
# @example Creating an audited record
#   AuditedRecord.create(
#     record_type: 'transaction',
#     record_id: 'txn_123',
#     data: { amount: 100 },
#     author: user,
#     message: 'Created transaction'
#   )
#
# @example Finding and verifying a record
#   record = AuditedRecord.find('transaction', 'txn_123')
#   record.verify_integrity! # => true
#
class AuditedRecord
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :record_type, :string
  attribute :record_id, :string
  attribute :data
  attribute :created_at, :datetime
  attribute :updated_at, :datetime
  attribute :author_name, :string
  attribute :author_email, :string
  attribute :commit_id, :string
  attribute :checksum, :string

  validates :record_type, presence: true, format: { with: /\A[a-z_]+\z/,
    message: 'must be lowercase with underscores only' }
  validates :record_id, presence: true
  validates :data, presence: true

  class << self
    # Create a new audited record
    #
    # @param record_type [String] The type of record (e.g., 'transaction')
    # @param record_id [String] Unique identifier within the type
    # @param data [Hash] The record data
    # @param author [User, nil] The author creating the record
    # @param message [String, nil] The audit message
    # @return [AuditedRecord] The created record
    def create(record_type:, record_id:, data:, author: nil, message: nil)
      record = new(
        record_type: record_type,
        record_id: record_id,
        data: data
      )
      record.save(author: author, message: message)
      record
    end

    # Find a record by type and id
    #
    # @param record_type [String] The record type
    # @param record_id [String] The record id
    # @return [AuditedRecord, nil] The record or nil
    def find(record_type, record_id)
      path = storage_path(record_type, record_id)
      stored = store[path]
      return nil unless stored

      new(
        record_type: record_type,
        record_id: record_id,
        data: stored['data'],
        created_at: stored['created_at'] ? Time.parse(stored['created_at']) : nil,
        updated_at: stored['updated_at'] ? Time.parse(stored['updated_at']) : nil,
        author_name: stored['author_name'],
        author_email: stored['author_email'],
        checksum: stored['checksum']
      )
    end

    # Find a record, raising if not found
    #
    # @param record_type [String] The record type
    # @param record_id [String] The record id
    # @return [AuditedRecord] The record
    # @raise [RecordNotFound] If not found
    def find!(record_type, record_id)
      find(record_type, record_id) or raise RecordNotFound,
        "Record '#{record_type}/#{record_id}' not found"
    end

    # Find by composite id (type/id)
    #
    # @param composite_id [String] Format: "type/id"
    # @return [AuditedRecord, nil] The record
    def find_by_composite_id(composite_id)
      parts = composite_id.split('/', 2)
      return nil unless parts.size == 2
      find(parts[0], parts[1])
    end

    # List all records of a specific type
    #
    # @param record_type [String] The record type
    # @return [Array<AuditedRecord>] All records of that type
    def where(record_type:)
      type_tree = store["records/#{record_type}"]
      return [] unless type_tree.is_a?(GitStore::Tree)

      type_tree.table.keys.map do |filename|
        next unless filename.end_with?('.yml')
        record_id = filename.sub('.yml', '')
        find(record_type, record_id)
      end.compact
    end

    # List all record types
    #
    # @return [Array<String>] Available record types
    def types
      records_tree = store['records']
      return [] unless records_tree.is_a?(GitStore::Tree)

      records_tree.table.keys.select do |name|
        records_tree.table[name].is_a?(GitStore::Tree)
      end.sort
    end

    # Search records across all types
    #
    # @param query [String] Search query
    # @return [Array<AuditedRecord>] Matching records
    def search(query)
      results = []
      types.each do |type|
        where(record_type: type).each do |record|
          if matches_query?(record, query)
            results << record
          end
        end
      end
      results
    end

    # Get all records (with pagination)
    #
    # @param page [Integer] Page number
    # @param per_page [Integer] Records per page
    # @return [Array<AuditedRecord>] Records for the page
    def all(page: 1, per_page: 50)
      all_records = []
      types.each do |type|
        all_records.concat(where(record_type: type))
      end
      all_records.sort_by { |r| r.updated_at || Time.at(0) }
                 .reverse
                 .slice((page - 1) * per_page, per_page) || []
    end

    # Access the GitStore instance
    def store
      Rails.application.config.audit_store
    end

    # Generate the storage path for a record
    def storage_path(record_type, record_id)
      "records/#{record_type}/#{record_id}.yml"
    end

    private

    def matches_query?(record, query)
      query_down = query.downcase
      record.record_id.downcase.include?(query_down) ||
        record.data.to_s.downcase.include?(query_down)
    end
  end

  # Check if this is a new record
  def new_record?
    !self.class.find(record_type, record_id)
  end

  # Check if persisted
  def persisted?
    !new_record?
  end

  # Save the record with audit trail
  #
  # @param author [User, nil] The author
  # @param message [String, nil] The audit message
  # @return [Boolean] True if saved
  def save(author: nil, message: nil)
    return false unless valid?

    now = Time.current
    self.updated_at = now
    self.created_at ||= now

    self.author_name = author&.respond_to?(:name) ? author.name : 'System'
    self.author_email = author&.respond_to?(:email) ? author.email : 'system@example.com'

    # Calculate checksum for integrity verification
    self.checksum = calculate_checksum

    msg = message || (new_record? ? "Created #{record_type}/#{record_id}" : "Updated #{record_type}/#{record_id}")

    store.transaction(msg, git_author(author)) do
      store[storage_path] = to_storage_hash
    end

    # Store the commit ID
    self.commit_id = store.head&.id

    true
  rescue StandardError => e
    errors.add(:base, e.message)
    false
  end

  # Get the complete revision history
  #
  # @param limit [Integer] Maximum revisions to return
  # @return [Array<Revision>] The revision history
  def revisions(limit: 100)
    commits = []
    current = store.head

    while current && commits.size < limit
      if commit_affects_record?(current)
        commits << Revision.new(
          commit_id: current.id,
          message: current.message,
          author: current.author&.name,
          email: current.author&.email,
          timestamp: current.author&.time,
          record: version_at(current.id)
        )
      end
      parent_id = current.parent.first
      current = parent_id ? store.get(parent_id) : nil
    end

    commits
  end

  # Get the record state at a specific commit
  #
  # @param commit_id [String] The commit SHA
  # @return [AuditedRecord, nil] The record at that commit
  def version_at(commit_id)
    commit = store.get(commit_id)
    return nil unless commit

    stored = commit.tree[storage_path]
    return nil unless stored

    self.class.new(
      record_type: record_type,
      record_id: record_id,
      data: stored['data'],
      created_at: stored['created_at'] ? Time.parse(stored['created_at']) : nil,
      updated_at: stored['updated_at'] ? Time.parse(stored['updated_at']) : nil,
      checksum: stored['checksum']
    )
  end

  # Get the record state at a specific point in time
  #
  # @param timestamp [Time] The point in time
  # @return [AuditedRecord, nil] The record state
  def state_at(timestamp)
    revisions.each do |revision|
      if revision.timestamp && revision.timestamp <= timestamp
        return revision.record
      end
    end
    nil
  end

  # Verify data integrity using checksum
  #
  # @return [Boolean] True if data hasn't been tampered with
  def verify_integrity!
    return false unless checksum.present?
    calculate_checksum == checksum
  end

  # Generate existence proof for compliance
  #
  # @return [Hash] Proof of existence
  def existence_proof
    current_commit = store.head
    revision = revisions.find { |r| r.record&.record_id == record_id }

    {
      record_type: record_type,
      record_id: record_id,
      commit_id: revision&.commit_id,
      timestamp: revision&.timestamp&.iso8601,
      author: revision&.author,
      checksum: checksum,
      current_head: current_commit&.id,
      verified: verify_integrity!,
      generated_at: Time.current.iso8601
    }
  end

  # Compare with another version
  #
  # @param commit_id [String] The other commit SHA
  # @return [Hash] Diff data
  def diff_with(commit_id)
    other = version_at(commit_id)
    return nil unless other

    {
      from: {
        commit_id: commit_id,
        data: other.data,
        timestamp: other.updated_at
      },
      to: {
        commit_id: self.commit_id,
        data: data,
        timestamp: updated_at
      },
      changes: compute_diff(other.data, data)
    }
  end

  # Get composite ID for routing
  def composite_id
    "#{record_type}/#{record_id}"
  end

  def to_param
    composite_id
  end

  # Convert to hash for storage
  def to_storage_hash
    {
      'data' => data,
      'created_at' => created_at&.iso8601,
      'updated_at' => updated_at&.iso8601,
      'author_name' => author_name,
      'author_email' => author_email,
      'checksum' => checksum
    }
  end

  # Convert to hash for API responses
  def to_hash
    {
      'record_type' => record_type,
      'record_id' => record_id,
      'data' => data,
      'created_at' => created_at&.iso8601,
      'updated_at' => updated_at&.iso8601,
      'checksum' => checksum,
      'verified' => verify_integrity!
    }
  end

  private

  def store
    self.class.store
  end

  def storage_path
    self.class.storage_path(record_type, record_id)
  end

  def git_author(author)
    name = author&.respond_to?(:name) ? author.name : (author_name || 'System')
    email = author&.respond_to?(:email) ? author.email : (author_email || 'system@example.com')
    GitStore::User.new(name, email, Time.now)
  end

  def calculate_checksum
    content = {
      record_type: record_type,
      record_id: record_id,
      data: data,
      created_at: created_at&.iso8601
    }.to_yaml
    Digest::SHA256.hexdigest(content)
  end

  def commit_affects_record?(commit)
    return false unless commit.parent.any?

    parent = store.get(commit.parent.first)
    return true unless parent

    current_blob = commit.tree[storage_path]
    parent_blob = parent.tree[storage_path]

    current_blob != parent_blob
  end

  def compute_diff(old_data, new_data)
    changes = []

    # Handle nil inputs
    old_data = old_data || {}
    new_data = new_data || {}

    # Ensure both are hashes before calling .keys
    return changes unless old_data.respond_to?(:keys) && new_data.respond_to?(:keys)

    all_keys = (old_data.keys + new_data.keys).uniq
    all_keys.each do |key|
      old_val = old_data[key]
      new_val = new_data[key]

      next if old_val == new_val

      if old_val.nil?
        changes << { action: 'added', key: key, value: new_val }
      elsif new_val.nil?
        changes << { action: 'removed', key: key, value: old_val }
      else
        changes << { action: 'changed', key: key, from: old_val, to: new_val }
      end
    end

    changes
  end

  # Revision struct for history
  Revision = Struct.new(:commit_id, :message, :author, :email, :timestamp, :record, keyword_init: true)

  class RecordNotFound < StandardError; end
end
