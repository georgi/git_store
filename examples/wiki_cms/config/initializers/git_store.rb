# frozen_string_literal: true

# GitStore configuration for Rails 8
# This initializer sets up the GitStore connection for content storage

Rails.application.config.to_prepare do
  # Path to the content repository
  content_repo_path = Rails.root.join('content_repo')

  # Ensure the repository exists
  unless File.exist?(content_repo_path.join('.git'))
    FileUtils.mkdir_p(content_repo_path)
    Dir.chdir(content_repo_path) do
      # Use array form to avoid shell injection
      system('git', 'init')
      system('git', 'config', 'user.name', 'Wiki System')
      system('git', 'config', 'user.email', 'wiki@example.com')
    end
  end

  # Initialize the global GitStore instance
  Rails.application.config.content_store = GitStore.new(content_repo_path.to_s)
end

# Helper method to access the store from anywhere
module GitStoreHelper
  def content_store
    Rails.application.config.content_store
  end
end
