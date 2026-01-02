# frozen_string_literal: true

require 'git_store'

# Page model that uses GitStore for versioned content storage.
# Each page is stored as a YAML file in the Git repository, providing
# full version history, branching, and rollback capabilities.
#
# @example Creating a new page
#   page = Page.new(slug: 'home', title: 'Home Page', content: '# Welcome')
#   page.save(author: current_user, message: 'Created home page')
#
# @example Finding and updating a page
#   page = Page.find('home')
#   page.content = '# Updated Welcome'
#   page.save(author: current_user, message: 'Updated home page content')
#
class Page
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  # Attributes stored in the YAML file
  attribute :slug, :string
  attribute :title, :string
  attribute :content, :string
  attribute :created_at, :datetime
  attribute :updated_at, :datetime
  attribute :author_name, :string
  attribute :author_email, :string
  attribute :tags, default: []

  # Validations
  validates :slug, presence: true, format: { with: /\A[a-z0-9\-_]+\z/i,
    message: 'only allows alphanumeric characters, dashes, and underscores' }
  validates :title, presence: true
  validates :content, presence: true

  class << self
    # Find a page by its slug
    #
    # @param slug [String] The page slug
    # @return [Page, nil] The page or nil if not found
    def find(slug)
      data = store["pages/#{slug}.yml"]
      return nil unless data

      new(data.merge(slug: slug))
    end

    # Find a page by slug, raising an error if not found
    #
    # @param slug [String] The page slug
    # @return [Page] The page
    # @raise [RecordNotFound] If the page doesn't exist
    def find!(slug)
      find(slug) or raise RecordNotFound, "Page '#{slug}' not found"
    end

    # Get all pages in the wiki
    #
    # @return [Array<Page>] All pages sorted by title
    def all
      pages = []
      store['pages']&.each do |path, data|
        next unless path.end_with?('.yml')
        slug = path.sub('.yml', '')
        pages << new(data.merge(slug: slug))
      end
      pages.sort_by(&:title)
    end

    # Get recently updated pages
    #
    # @param limit [Integer] Maximum number of pages to return
    # @return [Array<Page>] Recently updated pages
    def recent(limit: 10)
      all.sort_by { |p| p.updated_at || Time.at(0) }.reverse.first(limit)
    end

    # Search pages by title or content
    #
    # @param query [String] Search query
    # @return [Array<Page>] Matching pages
    def search(query)
      query_downcase = query.downcase
      all.select do |page|
        page.title.downcase.include?(query_downcase) ||
          page.content.downcase.include?(query_downcase)
      end
    end

    # Check if a page exists
    #
    # @param slug [String] The page slug
    # @return [Boolean] True if the page exists
    def exists?(slug)
      store["pages/#{slug}.yml"].present?
    end

    # Access the GitStore instance
    #
    # @return [GitStore] The content store
    def store
      Rails.application.config.content_store
    end
  end

  # Check if this is a new record
  #
  # @return [Boolean] True if not yet saved
  def new_record?
    !self.class.exists?(slug)
  end

  # Check if this record has been persisted
  #
  # @return [Boolean] True if saved
  def persisted?
    !new_record?
  end

  # Save the page to the GitStore
  #
  # @param author [User, nil] The author making the change
  # @param message [String] The commit message
  # @return [Boolean] True if saved successfully
  def save(author: nil, message: nil)
    return false unless valid?

    self.updated_at = Time.current
    self.created_at ||= Time.current

    if author
      self.author_name = author.respond_to?(:name) ? author.name : author.to_s
      self.author_email = author.respond_to?(:email) ? author.email : "#{author}@example.com"
    end

    store.transaction(commit_message(message), git_author) do
      store["pages/#{slug}.yml"] = to_hash
    end

    true
  rescue StandardError => e
    errors.add(:base, e.message)
    false
  end

  # Delete the page from the GitStore
  #
  # @param author [User, nil] The author making the deletion
  # @param message [String] The commit message
  # @return [Boolean] True if deleted successfully
  def destroy(author: nil, message: nil)
    return false unless persisted?

    msg = message || "Deleted page: #{title}"
    store.transaction(msg, git_author(author)) do
      store.delete("pages/#{slug}.yml")
    end

    true
  rescue StandardError => e
    errors.add(:base, e.message)
    false
  end

  # Get the version history for this page
  #
  # @param limit [Integer] Maximum number of commits to return
  # @return [Array<GitStore::Commit>] The commit history
  def history(limit: 50)
    commits = []
    current = store.head

    while current && commits.size < limit
      # Check if this commit modified our page
      if commit_affects_page?(current)
        commits << current
      end
      parent_id = current.parent.first if current.parent.any?
      current = parent_id ? store.get(parent_id) : nil
    end

    commits
  end

  # Get the page content at a specific commit
  #
  # @param commit_id [String] The commit SHA
  # @return [Page, nil] The page at that commit
  def version_at(commit_id)
    commit = store.get(commit_id)
    return nil unless commit

    data = commit.tree["pages/#{slug}.yml"]
    return nil unless data

    self.class.new(data.merge(slug: slug))
  end

  # Rollback to a previous version
  #
  # @param commit_id [String] The commit SHA to rollback to
  # @param author [User, nil] The author making the rollback
  # @param message [String] The commit message
  # @return [Boolean] True if rollback was successful
  def rollback_to(commit_id:, author: nil, message: nil)
    previous_version = version_at(commit_id)
    return false unless previous_version

    self.title = previous_version.title
    self.content = previous_version.content
    self.tags = previous_version.tags

    msg = message || "Rolled back to version #{commit_id[0..7]}"
    save(author: author, message: msg)
  end

  # Get the diff between this version and another
  #
  # @param other_commit_id [String] The other commit SHA
  # @return [String] The diff output
  def diff_with(other_commit_id)
    store.head.diff(other_commit_id, "pages/#{slug}.yml")
  end

  # Convert to a hash for YAML serialization
  #
  # @return [Hash] The page data
  def to_hash
    {
      'title' => title,
      'content' => content,
      'created_at' => created_at&.iso8601,
      'updated_at' => updated_at&.iso8601,
      'author_name' => author_name,
      'author_email' => author_email,
      'tags' => tags
    }.compact
  end

  # Used for routing
  def to_param
    slug
  end

  private

  def store
    self.class.store
  end

  def git_author(author = nil)
    name = author&.respond_to?(:name) ? author.name : (author_name || 'System')
    email = author&.respond_to?(:email) ? author.email : (author_email || 'system@example.com')
    GitStore::User.new(name, email, Time.now)
  end

  def commit_message(message)
    message || (new_record? ? "Created page: #{title}" : "Updated page: #{title}")
  end

  def commit_affects_page?(commit)
    return false unless commit.parent.any?

    parent = store.get(commit.parent.first)
    return true unless parent

    current_blob = commit.tree["pages/#{slug}.yml"]
    parent_blob = parent.tree["pages/#{slug}.yml"]

    current_blob != parent_blob
  end

  # Custom exception for record not found
  class RecordNotFound < StandardError; end
end
