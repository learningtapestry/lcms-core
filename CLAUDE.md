# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Technology Stack

- **Backend**: Ruby on Rails 8.1.1, Ruby 3.4.7
- **Database**: PostgreSQL with `pg_search` for full-text search
- **Search**: Elasticsearch 8.x
- **Frontend**: Hotwire (Turbo, Stimulus), React 16.9, Bootstrap 5.3
- **Asset Pipeline**: esbuild for JavaScript, Sass for CSS
- **Background Jobs**: Resque with Redis, Solid Queue
- **Authentication**: Devise
- **PDF Generation**: Grover (Puppeteer-based, uses Chromium in Docker)
- **Testing**: RSpec
- **Containerization**: Docker, Docker Compose

## Docker Architecture

This project runs entirely in Docker containers. All commands must be executed inside containers using `docker compose run --rm`.

### Docker Services

- **db**: PostgreSQL 17.6 on port 5432
- **redis**: Redis 7 on port 6379
- **rails**: Main Rails application on port 3000
- **resque**: Background job workers
- **css**: CSS asset watcher
- **js**: JavaScript asset builder
- **test**: Test runner

### Docker Image

- Base image: `lcms-core:3.4.7` (built from `Dockerfile.dev`)
- Includes Ruby 3.4.7, Node.js 22, Yarn, PostgreSQL client, Chromium for PDF generation
- Uses volumes: `bundle-3.4.7`, `postgres-17.6`, `redis-7`

## Development Commands

All commands run inside disposable Docker containers with `--rm` flag.

### Setup

```bash
# Build the Docker image
docker build -f Dockerfile.dev -t lcms-core:3.4.7 .

# Start all services
docker compose up

# Install dependencies
docker compose run --rm rails bundle install
docker compose run --rm rails yarn install

# Database setup
docker compose run --rm rails rails db:create
docker compose run --rm rails rails db:migrate
docker compose run --rm rails rails db:seed
```

### Development

```bash
# Start Rails server
docker compose up rails

# Start all services (Rails, Resque, CSS/JS watchers)
docker compose up

# Start specific services
docker compose up rails resque

# Rails console
docker compose run --rm rails rails console

# Rails commands
docker compose run --rm rails rails routes
docker compose run --rm rails rails db:migrate
docker compose run --rm rails rails db:rollback
```

### Asset Compilation

```bash
# Build JavaScript
docker compose run --rm js yarn build

# Build CSS once
docker compose run --rm rails yarn build:css

# Watch CSS for changes
docker compose up css
```

### Testing

```bash
# Run all tests
docker compose run --rm test bundle exec rspec

# Run specific test file
docker compose run --rm test bundle exec rspec spec/path/to/file_spec.rb

# Run specific test by line
docker compose run --rm test bundle exec rspec spec/path/to/file_spec.rb:42

# Setup test database
docker compose run --rm -e RAILS_ENV=test rails rails db:create
docker compose run --rm -e RAILS_ENV=test rails rails db:migrate
```

### Code Quality

```bash
# Run Rubocop
docker compose run --rm rails bundle exec rubocop

# Auto-fix style issues
docker compose run --rm rails bundle exec rubocop -a

# Security scans
docker compose run --rm rails bundle exec brakeman
docker compose run --rm rails bundle exec bundler-audit
```

### Background Jobs

```bash
# Start Resque workers (via docker-compose)
docker compose up resque

# Manual Resque worker
docker compose run --rm rails env QUEUE=* bundle exec rake resque:work

# Resque scheduler
docker compose run --rm rails bundle exec rake resque:scheduler
```

### Utility Commands

```bash
# Shell access to Rails container
docker compose run --rm rails bash

# Check Ruby version
docker compose run --rm rails ruby --version

# Check syntax of Ruby files
docker compose run --rm rails ruby -c app/helpers/some_helper.rb

# Database console
docker compose run --rm rails rails dbconsole
```

## Application Architecture

### Core Domain Models

**Documents and Materials**
- `Document`: Lesson documents imported from Google Docs, with hierarchical curriculum structure
- `Material`: Supporting materials for lessons (PDFs, worksheets, etc.)
- `DocumentPart` and `MaterialPart`: Rendered content in different contexts (gdoc, PDF)
- Both use `Partable` concern for multi-format content rendering

**Resources and Curriculum**
- `Resource`: Hierarchical curriculum structure (grades, modules, units, lessons)
- Uses `closure_tree` gem for tree navigation
- Stores `hierarchical_position` for ordering

**Standards and Tagging**
- `Standard`: Educational standards that can be attached to documents/materials
- Uses `acts-as-taggable-on` for flexible tagging system

### Service Objects Pattern

Services are located in `app/services/` and follow these patterns:

**Import Services**
- `ImportService`: Base class for importing content
- `StandardsImportService`: Imports educational standards
- All import services typically inherit from base `ImportService`

**Document Processing**
- `BundleGenerator`: Creates bundled PDFs of multiple documents
- `EmbedEquations`: Processes mathematical equations
- Located in `lib/document_exporter/` and `lib/document_renderer/`

**Google Drive Integration**
- `Google::ScriptService`: Interacts with Google Apps Script
- Uses `lt-google-api` and `google-apis-drive_v3` gems

### Background Job Architecture

Jobs are in `app/jobs/` and use Resque with ActiveJob:

**Document Processing Jobs**
- `DocumentParseJob`: Parses imported Google Docs
- `DocumentGenerateJob`: Main job that orchestrates generation
- `DocumentGeneratePdfJob`: Generates PDF versions
- `DocumentGenerateGdocJob`: Generates Google Doc versions

**Material Processing Jobs**
- `MaterialParseJob`: Parses material content
- `MaterialGenerateJob`: Orchestrates material generation
- `MaterialGeneratePdfJob`: PDF generation
- `MaterialGenerateGdocJob`: Google Doc generation

All jobs inherit from `ApplicationJob` with retry logic via `activejob-retry`.

### Template System (lib/doc_template)

The `DocTemplate` module handles document templating and parsing:

- **Configuration**: Loads from `config/lcms.yml`
- **Tag Processing**: Custom markup tags in documents (e.g., `[section: name]`)
- **Tables**: Different table renderers (`DocTemplate::Tables::*`)
- **Context Types**: Multiple output formats (gdoc, PDF)
- **XPath Functions**: Custom functions for document parsing

Key regex pattern for tags: `FULL_TAG = /\[([^\]:\s]*)?\s*:?\s*([^\]]*?)?\]/mo`

### Value Objects and Presenters

- `app/value_objects/`: Immutable data structures (uses `virtus` gem)
- `app/presenters/`: View-layer presentation logic
- `app/queries/`: Complex query objects (e.g., `AdminDocumentsQuery`, `AdminMaterialsQuery`)
- `app/forms/`: Form objects using `simple_form`

### Controller Structure

**Public Controllers**
- `DocumentsController`: Public document viewing and export
- `MaterialsController`: Public material previews (PDF, Google Doc)
- `WelcomeController`: Landing page and OAuth callbacks

**Admin Namespace** (`app/controllers/admin/`)
- Full CRUD for resources, documents, materials, users, standards
- Batch operations (bulk delete, reimport)
- Settings management

**API Namespace** (`app/controllers/api/`)
- RESTful JSON API for resources

### Frontend Architecture

**JavaScript** (`app/javascript/`)
- Entry point: `app/javascript/application.js`
- Built with esbuild, supports JSX for React components
- Uses jQuery, Lodash, Bootstrap for UI components

**Stylesheets** (`app/assets/stylesheets/`)
- Main: `application.bootstrap.scss`
- PDF-specific: `pdf.scss`, `pdf_plain.scss`
- Uses Bootstrap 5.3 with SCSS customizations

**Stimulus Controllers**: 7Hotwire Stimulus for JavaScript behavior

## Testing Strategy

- **Factories**: `spec/factories/` using FactoryBot
- **Request specs**: `spec/requests/`
- **Feature specs**: `spec/features/` using Capybara
- **Model specs**: `spec/models/`
- **Service specs**: `spec/services/`
- **Support files**: `spec/support/` for shared examples and helpers

Use `database_cleaner-active_record` for test database management.

## Code Style Guidelines

**IMPORTANT**: All generated Ruby code MUST follow Rubocop rules configured in `.rubocop.yml`.

This project uses `rubocop-rails-omakase` style guide. Key rules to follow:

- **Double quotes for strings**: Always use `"string"` not `'string'`
- **Percent literal delimiters**: Use parentheses for `%w()`, `%i()`, `%W()`, `%I()`
- **Keyword alignment**: Align `end` with the keyword that opens the block (`if`, `def`, `class`, etc.)
- **New cops enabled**: All new Rubocop cops are enabled by default

Before committing code, run Rubocop to check for style violations:
```bash
docker compose run --rm rails bundle exec rubocop
docker compose run --rm rails bundle exec rubocop -a  # Auto-fix
```

## Important Patterns and Conventions

### Concerns
- `Filterable`: Adds scope-based filtering to models
- `Partable`: Multi-format content rendering (gdoc/pdf)
- Located in `app/models/concerns/`

### Metadata Storage
Documents and materials store curriculum metadata as JSONB:
```ruby
where_metadata(:subject, "math")  # Query JSONB metadata
```

### Queue Configuration
- Queue adapter: Resque (configured in `config/application.rb`)
- Access Resque web UI at `/queue` (requires authentication)

### Asset Paths
Custom asset paths configured for:
- FontAwesome webfonts: `node_modules/@fortawesome/fontawesome-free/webfonts`
- Bootstrap icons: `node_modules/bootstrap-icons/font/fonts`

## Configuration Files

- `config/lcms.yml`: DocTemplate configuration
- `.ruby-version`: Ruby 3.4.7
- `.node-version`: Node 22.12.0
- `config/routes.rb`: Routes with admin namespace and API
- `docker-compose.yml`: Docker services configuration
- `Dockerfile.dev`: Development Docker image
- `.env.docker`, `.env.development`: Environment variables

## Dependencies Worth Noting

- **File Upload**: CarrierWave with AWS S3 support
- **Pagination**: WillPaginate with Bootstrap styling
- **Filtering**: Ransack for advanced search
- **Monitoring**: Airbrake for error tracking
- **Performance**: Bullet (dev) for N+1 query detection
- **Linting**: Rubocop with Rails Omakase style guide
