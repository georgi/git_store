# GitStore Wiki/CMS Example

A complete Rails 8 wiki application powered by GitStore for versioned content management.

## Features

- **Full version history** - Every edit creates a Git commit
- **Rollback support** - Revert to any previous version instantly
- **Diff viewing** - See exactly what changed between versions
- **Branch support** - Draft content in branches, merge when ready
- **Git-native storage** - Content can be edited via Git or the web UI

## Quick Start

```bash
# Create a new Rails 8 application
rails new wiki_app --database=sqlite3 --css=tailwind

# Add git_store to Gemfile
echo "gem 'git_store', path: '../../../'" >> Gemfile

# Install dependencies
bundle install

# Copy the example files to your Rails app
cp -r app/* wiki_app/app/
cp -r config/routes.rb wiki_app/config/
cp -r config/initializers/* wiki_app/config/initializers/

# Initialize the content repository
mkdir -p wiki_app/content_repo
cd wiki_app/content_repo && git init

# Run the application
cd wiki_app && rails server
```

## Directory Structure

```
wiki_cms/
├── app/
│   ├── controllers/
│   │   └── pages_controller.rb    # CRUD for wiki pages
│   ├── models/
│   │   └── page.rb                # Page model using GitStore
│   ├── views/
│   │   └── pages/                 # ERB templates
│   └── helpers/
│       └── pages_helper.rb        # View helpers
├── config/
│   ├── routes.rb                  # Route configuration
│   └── initializers/
│       └── git_store.rb           # GitStore configuration
└── README.md
```

## Usage

### Creating a page

```ruby
# Via Rails console
page = Page.new(
  slug: 'getting-started',
  title: 'Getting Started Guide',
  content: '# Welcome\n\nThis is your first wiki page.',
  author: 'john@example.com'
)
page.save(message: 'Created getting started guide')
```

### Viewing history

```ruby
# Get all versions of a page
page = Page.find('getting-started')
page.history.each do |commit|
  puts "#{commit.author.name} - #{commit.message} - #{commit.author.time}"
end
```

### Rolling back

```ruby
# Revert to a previous version
page = Page.find('getting-started')
page.rollback_to(commit_id: 'abc123', message: 'Reverting bad edit')
```
