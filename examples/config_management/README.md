# GitStore Configuration Management Example

A Rails 8 application for versioned configuration management powered by GitStore.

## Features

- **Version-controlled configs** - Every config change is a Git commit
- **Instant rollback** - Revert bad configurations immediately
- **Audit trail** - Track who changed what and when
- **PR-based workflow** - Review config changes before deployment
- **Environment support** - Manage configs per environment

## Quick Start

```bash
# Create a new Rails 8 application
rails new config_manager --database=sqlite3 --css=tailwind

# Add git_store to Gemfile
echo "gem 'git_store', path: '../../../'" >> Gemfile

# Install dependencies
bundle install

# Copy the example files
cp -r app/* config_manager/app/
cp -r config/* config_manager/config/

# Initialize the configuration repository
mkdir -p config_manager/config_repo
cd config_manager/config_repo && git init

# Run the application
cd config_manager && rails server
```

## Directory Structure

```
config_management/
├── app/
│   ├── controllers/
│   │   └── configs_controller.rb    # Config CRUD
│   ├── models/
│   │   └── config_entry.rb          # Config model
│   └── views/
│       └── configs/                 # ERB templates
├── config/
│   ├── routes.rb
│   └── initializers/
│       └── git_store.rb
└── README.md
```

## Usage Examples

### Managing Application Settings

```ruby
# Store a feature flag configuration
ConfigEntry.set(
  'features/dark_mode.yml',
  {
    enabled: true,
    rollout_percentage: 50,
    allowed_users: ['admin@example.com']
  },
  author: current_user,
  message: 'Enable dark mode for 50% of users'
)

# Read the configuration
config = ConfigEntry.get('features/dark_mode.yml')
# => { enabled: true, rollout_percentage: 50, ... }
```

### Environment-Specific Configs

```ruby
# Set production database config
ConfigEntry.set(
  'environments/production/database.yml',
  {
    adapter: 'postgresql',
    pool: 25,
    timeout: 5000
  },
  author: current_user,
  message: 'Increase connection pool for production'
)

# Get all configs for an environment
ConfigEntry.for_environment('production')
```

### Rolling Back Bad Configs

```ruby
# Oops! The new config broke something
config = ConfigEntry.find('features/dark_mode.yml')
config.rollback_to(
  commit_id: 'abc123',
  author: current_user,
  message: 'Rollback: Dark mode causing crashes'
)
```

### Comparing Configurations

```ruby
# See what changed between versions
config = ConfigEntry.find('features/dark_mode.yml')
diff = config.diff_with('abc123')
puts diff
# -rollout_percentage: 50
# +rollout_percentage: 100
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /configs | List all configs |
| GET | /configs/:path | Get config value |
| POST | /configs | Create config |
| PATCH | /configs/:path | Update config |
| DELETE | /configs/:path | Delete config |
| GET | /configs/:path/history | Version history |
| POST | /configs/:path/rollback | Rollback to version |

## Security Considerations

1. **Access Control** - Implement authentication/authorization for config changes
2. **Sensitive Data** - Use Rails credentials for secrets, not this system
3. **Validation** - Validate configs before saving to prevent invalid states
4. **Audit Logging** - All changes are tracked in Git history
