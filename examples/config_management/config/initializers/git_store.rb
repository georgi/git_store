# frozen_string_literal: true

# GitStore configuration for Rails 8 - Configuration Management
# Stores application configurations in a versioned Git repository

Rails.application.config.to_prepare do
  # Path to the configuration repository
  config_repo_path = Rails.root.join('config_repo')

  # Ensure the repository exists
  unless File.exist?(config_repo_path.join('.git'))
    FileUtils.mkdir_p(config_repo_path)
    Dir.chdir(config_repo_path) do
      system('git init')
      system('git config user.name "Config System"')
      system('git config user.email "config@example.com"')
    end
  end

  # Initialize the GitStore instance for configs
  Rails.application.config.config_store = GitStore.new(config_repo_path.to_s)
end

# Helper module to access the config store
module ConfigStoreHelper
  def config_store
    Rails.application.config.config_store
  end
end
