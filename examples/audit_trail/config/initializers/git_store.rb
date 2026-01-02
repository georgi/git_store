# frozen_string_literal: true

# GitStore configuration for Rails 8 - Audit Trail
# Provides tamper-evident, versioned storage for compliance requirements

Rails.application.config.to_prepare do
  # Path to the audit repository
  audit_repo_path = Rails.root.join('audit_repo')

  # Ensure the repository exists
  unless File.exist?(audit_repo_path.join('.git'))
    FileUtils.mkdir_p(audit_repo_path)
    Dir.chdir(audit_repo_path) do
      # Use array form to avoid shell injection
      system('git', 'init')
      system('git', 'config', 'user.name', 'Audit System')
      system('git', 'config', 'user.email', 'audit@example.com')
    end
  end

  # Initialize the GitStore instance for audit trail
  Rails.application.config.audit_store = GitStore.new(audit_repo_path.to_s)
end

# Helper module to access the audit store
module AuditStoreHelper
  def audit_store
    Rails.application.config.audit_store
  end
end
