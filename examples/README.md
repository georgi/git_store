# GitStore Rails 8 Examples

This directory contains complete Rails 8 example applications demonstrating the key use cases for GitStore.

## 📚 Available Examples

### 1. Wiki/CMS (`wiki_cms/`)

A complete wiki application with versioned content management.

**Features:**
- Create and edit wiki pages with Markdown support
- Full version history with diff viewing
- Rollback to any previous version
- Wiki-style `[[Page Links]]`
- Search functionality

**Key files:**
- `app/models/page.rb` - Page model with GitStore integration
- `app/controllers/pages_controller.rb` - Full CRUD with history
- `app/views/pages/` - Views with Tailwind CSS

[Read more →](wiki_cms/README.md)

---

### 2. Configuration Management (`config_management/`)

Version-controlled application configuration storage.

**Features:**
- YAML/JSON configuration storage
- Environment-specific configs
- Instant rollback for bad configurations
- Diff viewing between versions
- API access for programmatic use

**Key files:**
- `app/models/config_entry.rb` - Config model with versioning
- `app/controllers/configs_controller.rb` - Config management
- `app/services/` - (Optional) Config validation services

[Read more →](config_management/README.md)

---

### 3. Audit Trail (`audit_trail/`)

Tamper-evident data storage for compliance requirements.

**Features:**
- Immutable audit trail
- Point-in-time data reconstruction
- Cryptographic integrity verification
- Compliance report generation
- Existence proofs for legal/regulatory needs

**Key files:**
- `app/models/audited_record.rb` - Record with full audit capabilities
- `app/services/audit_service.rb` - Report generation and compliance tools
- `app/controllers/records_controller.rb` - CRUD with audit features

[Read more →](audit_trail/README.md)

---

## 🚀 Quick Start

Each example can be integrated into a new Rails 8 application:

```bash
# Create a new Rails 8 app
rails new my_app --database=sqlite3 --css=tailwind

# Add git_store to your Gemfile
cd my_app
echo "gem 'git_store', github: 'georgi/git_store'" >> Gemfile
bundle install

# Copy example files
cp -r /path/to/examples/wiki_cms/app/* app/
cp -r /path/to/examples/wiki_cms/config/* config/

# Initialize the content repository
mkdir -p content_repo
cd content_repo && git init && cd ..

# Start the server
rails server
```

## 📁 Common Patterns

### GitStore Initialization

All examples use a similar pattern for initializing GitStore in Rails:

```ruby
# config/initializers/git_store.rb
Rails.application.config.to_prepare do
  repo_path = Rails.root.join('data_repo')
  
  unless File.exist?(repo_path.join('.git'))
    FileUtils.mkdir_p(repo_path)
    Dir.chdir(repo_path) do
      system('git init')
      system('git config user.name "App System"')
      system('git config user.email "system@example.com"')
    end
  end
  
  Rails.application.config.store = GitStore.new(repo_path.to_s)
end
```

### Model Pattern

The examples use a consistent model pattern:

```ruby
class MyModel
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  class << self
    def store
      Rails.application.config.store
    end
    
    def find(id)
      data = store["records/#{id}.yml"]
      return nil unless data
      new(data.merge(id: id))
    end
  end
  
  def save(author: nil, message: nil)
    store.transaction(message, git_author(author)) do
      store["records/#{id}.yml"] = to_hash
    end
  end
end
```

### Transaction Pattern

For atomic operations:

```ruby
store.transaction("Update multiple configs", author) do
  store["config/feature_a.yml"] = { enabled: true }
  store["config/feature_b.yml"] = { enabled: false }
  # All changes committed together, or all rolled back on error
end
```

## 🔑 Key Benefits

| Feature | Traditional DB | GitStore |
|---------|---------------|----------|
| Version History | Custom implementation | Built-in (Git) |
| Rollback | Complex | One command |
| Diff/Comparison | Custom | Git diff |
| Branching | Not available | Git branches |
| Audit Trail | Extra tables | Every commit |
| External Editing | Not possible | Edit files directly |
| Backup | DB dumps | Git clone |

## 💡 When to Use GitStore

**Good for:**
- Content Management Systems
- Configuration storage
- Audit-critical data
- Documentation systems
- Data that changes infrequently
- Human-readable data storage

**Not ideal for:**
- High-frequency writes
- Complex relational queries
- Large binary files
- Real-time data

## 🔒 Security Notes

When integrating these examples into your Rails application:

1. **CSRF Protection** - Ensure your `ApplicationController` has CSRF protection enabled:
   ```ruby
   class ApplicationController < ActionController::Base
     protect_from_forgery with: :exception
   end
   ```

2. **Authentication** - Add proper authentication before allowing data modifications
3. **Authorization** - Implement role-based access control for sensitive operations
4. **Input Validation** - The examples include basic validation; add more as needed
5. **Repository Access** - Restrict file system access to the Git repositories

## 📖 Further Reading

- [GitStore README](../README.md)
- [GitStore Documentation](../docs/)
- [Shinmun Blog Engine](http://www.matthias-georgi.de/shinmun) - Inspiration for GitStore
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
