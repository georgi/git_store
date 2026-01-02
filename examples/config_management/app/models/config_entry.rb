# frozen_string_literal: true

require 'git_store'
require 'json'

# ConfigEntry model for managing versioned application configurations.
# Supports YAML and JSON formats with full version history.
#
# @example Setting a configuration
#   ConfigEntry.set('features/beta.yml', { enabled: true }, author: user)
#
# @example Getting a configuration
#   config = ConfigEntry.get('features/beta.yml')
#   # => { 'enabled' => true }
#
class ConfigEntry
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Supported file formats
  SUPPORTED_FORMATS = %w[yml yaml json].freeze

  attribute :path, :string
  attribute :value
  attribute :format, :string
  attribute :updated_at, :datetime
  attribute :author_name, :string
  attribute :author_email, :string

  validates :path, presence: true
  validates :value, presence: true
  validate :validate_format

  class << self
    # Get a configuration value by path
    #
    # @param path [String] The config path (e.g., 'features/beta.yml')
    # @return [Hash, Array, String, nil] The configuration value
    def get(path)
      store[path]
    end

    # Set a configuration value
    #
    # @param path [String] The config path
    # @param value [Hash, Array, String] The configuration value
    # @param author [User, nil] The author making the change
    # @param message [String, nil] The commit message
    # @return [Boolean] True if saved successfully
    def set(path, value, author: nil, message: nil)
      entry = new(path: path, value: value)
      entry.save(author: author, message: message)
    end

    # Find a config entry by path
    #
    # @param path [String] The config path
    # @return [ConfigEntry, nil] The entry or nil
    def find(path)
      value = store[path]
      return nil unless value

      new(
        path: path,
        value: value,
        format: File.extname(path).delete('.'),
        updated_at: Time.current
      )
    end

    # Find a config entry, raising if not found
    #
    # @param path [String] The config path
    # @return [ConfigEntry] The entry
    # @raise [RecordNotFound] If not found
    def find!(path)
      find(path) or raise RecordNotFound, "Config '#{path}' not found"
    end

    # List all configuration files
    #
    # @return [Array<ConfigEntry>] All configs
    def all
      entries = []
      collect_entries(store.root, '', entries)
      entries.sort_by(&:path)
    end

    # Get configs for a specific environment
    #
    # @param env [String] Environment name (e.g., 'production')
    # @return [Array<ConfigEntry>] Configs for that environment
    def for_environment(env)
      all.select { |entry| entry.path.start_with?("environments/#{env}/") }
    end

    # List available environments
    #
    # @return [Array<String>] Environment names
    def environments
      all.map { |entry| entry.path.split('/')[1] if entry.path.start_with?('environments/') }
          .compact
          .uniq
          .sort
    end

    # Search configs by path pattern
    #
    # @param pattern [String] Search pattern
    # @return [Array<ConfigEntry>] Matching configs
    def search(pattern)
      pattern_downcase = pattern.downcase
      all.select { |entry| entry.path.downcase.include?(pattern_downcase) }
    end

    # Delete a configuration
    #
    # @param path [String] The config path
    # @param author [User, nil] The author
    # @param message [String, nil] The commit message
    # @return [Boolean] True if deleted
    def delete(path, author: nil, message: nil)
      msg = message || "Deleted config: #{path}"
      store.transaction(msg, git_author(author)) do
        store.delete(path)
      end
      true
    rescue StandardError
      false
    end

    # Access the GitStore instance
    def store
      Rails.application.config.config_store
    end

    private

    def collect_entries(tree, prefix, entries)
      return unless tree.is_a?(GitStore::Tree)

      tree.table.each do |name, entry|
        full_path = prefix.empty? ? name : "#{prefix}/#{name}"

        if entry.is_a?(GitStore::Tree)
          collect_entries(entry, full_path, entries)
        elsif SUPPORTED_FORMATS.include?(File.extname(name).delete('.'))
          value = tree[name]
          entries << new(
            path: full_path,
            value: value,
            format: File.extname(name).delete('.')
          )
        end
      end
    end

    def git_author(author)
      name = author&.respond_to?(:name) ? author.name : 'System'
      email = author&.respond_to?(:email) ? author.email : 'system@example.com'
      GitStore::User.new(name, email, Time.now)
    end
  end

  # Check if this is a new record
  def new_record?
    !self.class.find(path)
  end

  # Check if persisted
  def persisted?
    !new_record?
  end

  # Save the configuration
  #
  # @param author [User, nil] The author
  # @param message [String, nil] The commit message
  # @return [Boolean] True if saved
  def save(author: nil, message: nil)
    return false unless valid?

    self.updated_at = Time.current
    self.author_name = author&.respond_to?(:name) ? author.name : 'System'
    self.author_email = author&.respond_to?(:email) ? author.email : 'system@example.com'

    msg = message || (new_record? ? "Created config: #{path}" : "Updated config: #{path}")

    store.transaction(msg, git_author(author)) do
      store[path] = value
    end

    true
  rescue StandardError => e
    errors.add(:base, e.message)
    false
  end

  # Delete this configuration
  #
  # @param author [User, nil] The author
  # @param message [String, nil] The commit message
  # @return [Boolean] True if deleted
  def destroy(author: nil, message: nil)
    self.class.delete(path, author: author, message: message)
  end

  # Get version history for this config
  #
  # @param limit [Integer] Maximum commits to return
  # @return [Array<GitStore::Commit>] Commit history
  def history(limit: 50)
    commits = []
    current = store.head

    while current && commits.size < limit
      if commit_affects_config?(current)
        commits << current
      end
      parent_id = current.parent.first
      current = parent_id ? store.get(parent_id) : nil
    end

    commits
  end

  # Get the config value at a specific commit
  #
  # @param commit_id [String] The commit SHA
  # @return [ConfigEntry, nil] The config at that commit
  def version_at(commit_id)
    commit = store.get(commit_id)
    return nil unless commit

    value = commit.tree[path]
    return nil unless value

    self.class.new(
      path: path,
      value: value,
      format: format
    )
  end

  # Rollback to a previous version
  #
  # @param commit_id [String] The commit SHA
  # @param author [User, nil] The author
  # @param message [String, nil] The commit message
  # @return [Boolean] True if successful
  def rollback_to(commit_id:, author: nil, message: nil)
    previous = version_at(commit_id)
    return false unless previous

    self.value = previous.value
    msg = message || "Rolled back config #{path} to version #{commit_id[0..7]}"
    save(author: author, message: msg)
  end

  # Get diff with another version
  #
  # @param other_commit_id [String] The other commit SHA
  # @return [String] Diff output
  def diff_with(other_commit_id)
    store.head.diff(other_commit_id, path)
  end

  # Convert to hash for API responses
  #
  # @return [Hash] The config data
  def to_hash
    {
      'path' => path,
      'value' => value,
      'format' => format,
      'updated_at' => updated_at&.iso8601
    }
  end

  # For routing
  def to_param
    path
  end

  private

  def store
    self.class.store
  end

  def git_author(author)
    name = author&.respond_to?(:name) ? author.name : (author_name || 'System')
    email = author&.respond_to?(:email) ? author.email : (author_email || 'system@example.com')
    GitStore::User.new(name, email, Time.now)
  end

  def validate_format
    return if path.blank?

    ext = File.extname(path).delete('.')
    unless SUPPORTED_FORMATS.include?(ext)
      errors.add(:path, "must end with #{SUPPORTED_FORMATS.join(', ')}")
    end
  end

  def commit_affects_config?(commit)
    return false unless commit.parent.any?

    parent = store.get(commit.parent.first)
    return true unless parent

    current_blob = commit.tree[path]
    parent_blob = parent.tree[path]

    current_blob != parent_blob
  end

  class RecordNotFound < StandardError; end
end
