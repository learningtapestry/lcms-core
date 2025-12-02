# Migration Plan: lcms-engine to Rails Application

## Table of Contents
- [Statistics and Analysis](#statistics-and-analysis)
- [Migration Phases](#migration-phases)
- [Recommended Timeline](#recommended-timeline)
- [Key Changes](#key-changes)
- [Next Steps](#next-steps)

## Statistics and Analysis

### lcms-engine Codebase Structure

**Database:**
- 31 database tables
- 1 migration (latest: 20241024102540)
- PostgreSQL extensions: hstore, plpgsql

**Code:**
- 29 models
- 25 controllers
- 14 background jobs
- 82 files in lib (services, exporters, utilities)
- 15 initializers
- 259 total files in app directory

**Key Dependencies:**
- **Authentication:** Devise (~> 4.9)
- **Search:** Elasticsearch (~> 8.0)
- **Queues:** Redis (~> 5.4) + Resque (~> 2.6)
- **Files:** CarrierWave (~> 3.0), AWS SDK S3
- **Google API:** Google Drive API, Google Apps Script API
- **Tags:** Acts As Taggable On (~> 13.0)
- **Hierarchies:** Closure Tree (~> 7.1)
- **UI:** Bootstrap, CKEditor (~> 5.1), Simple Form (~> 5.3)
- **Other:** Ransack, Will Paginate, Nokogiri, Sanitize

---

## Migration Phases

### Phase 1: Infrastructure Preparation

#### 1.1. Gemfile Update
- [x] Add all runtime dependencies from gemspec
- [x] Configure gem versions compatible with Rails 8.1
- [x] Decide: Resque vs Solid Queue for background jobs
- [x] Configure Redis

**Critical dependencies to add:**
```ruby
# Authentication
gem 'devise', '~> 4.9'

# Search
gem 'elasticsearch-model', '~> 8.0'
gem 'elasticsearch-rails', '~> 8.0'
gem 'elasticsearch-dsl', '~> 0.1.9'
gem 'pg_search', '~> 2.3'

# Background jobs
gem 'redis', '~> 5.4'
gem 'resque', '~> 2.6'  # or use Solid Queue (Rails 8.1)
gem 'resque-scheduler', '~> 4.10'
gem 'activejob-retry', '~> 0.6.3'

# File handling
gem 'carrierwave', '~> 3.0'
gem 'aws-sdk-s3', '~> 1'
gem 'aws-sdk-rails', '~> 4.0'
gem 'mini_magick', '~> 4.12'

# Google APIs
gem 'google-apis-drive_v3', '~> 0.66'
gem 'google-apis-script_v1', '~> 0.28'
gem 'lt-google-api', '~> 0.4'

# Tags & Trees
gem 'acts-as-taggable-on', '~> 13.0'
gem 'closure_tree', '~> 7.1'
gem 'acts_as_list', '~> 1.0'

# UI & Forms
gem 'simple_form', '~> 5.3'
gem 'ckeditor', '~> 5.1'
gem 'will_paginate', '~> 4.0'
gem 'will_paginate-bootstrap-style', '~> 0.3'
gem 'ransack', '~> 4.2'

# Utilities
gem 'nokogiri', '~> 1.16'
gem 'sanitize', '~> 6.1'
gem 'combine_pdf', '~> 1.0'
gem 'rubyzip', '~> 2.3'
gem 'httparty', '~> 0.22'
gem 'virtus', '~> 1.0'
gem 'lt-lcms', '~> 0.7'
```

#### 1.2. Configuration Setup
- [x] Migrate all initializers from `config/initializers/`
- [x] Configure `config/application.rb`
- [x] Create environment-specific configurations
- [x] Set up credentials for API keys (Google, AWS)

**Initializers to migrate:**
- airbrake.rb
- carrier_wave.rb
- ckeditor.rb
- devise.rb
- elasticsearch.rb
- form_tag.rb
- mime_types.rb
- rack_profiler.rb
- resque.rb
- simple_form.rb
- simple_form_bootstrap.rb
- wicked_pdf.rb
- will_paginate.rb

---

### Phase 2: Database

#### 2.1. Migrations
- [x] Enable PostgreSQL extensions (hstore, plpgsql)
- [x] Create migrations for all 31 tables
- [x] Create indexes according to schema.rb

**Tables to create:**
1. access_codes
2. authors
3. copyright_attributions
4. curriculums
5. document_bundles
6. document_parts
7. documents
8. downloads
9. ela_buckets
10. grades
11. hierarchies (closure_tree)
12. materials
13. modules
14. reading_assignment_authors
15. reading_assignment_texts
16. reimport_batches
17. resource_additional_resources
18. resource_downloads
19. resource_reading_assignments
20. resource_related_resources
21. resource_stats
22. resource_standards
23. resources
24. settings
25. social_thumbnails
26. staff_members
27. standard_links
28. standards
29. subjects
30. taggings
31. tags
32. users
33. lcms_engine_integrations_webhook_configurations

#### 2.2. Seeds
- [ ] Migrate `db/seeds.rb`
- [ ] Migrate all seed files from `db/seeds/`:
  - subjects.seeds.rb
  - authors.seeds.rb
  - curriculums.seeds.rb
  - development/ (grades, users, standards)

---

### Phase 3: Models and Business Logic

#### 3.1. Core Models (Priority: CRITICAL)
- [x] User (`app/models/user.rb`)
- [x] Curriculum
- [x] Resource
- [x] Document
- [x] Material

#### 3.2. Related Models
- [x] AccessCode
- [x] Author
- [x] CopyrightAttribution
- [x] DocumentBundle
- [x] DocumentPart
- [x] Download
- [x] ElaBucket
- [x] Grade
- [x] Module
- [x] ReadingAssignmentAuthor
- [x] ReadingAssignmentText
- [x] ReimportBatch
- [x] ResourceAdditionalResource
- [x] ResourceDownload
- [x] ResourceReadingAssignment
- [x] ResourceRelatedResource
- [x] ResourceStat
- [x] ResourceStandard
- [x] ~~Settings~~
- [x] SocialThumbnail
- [x] StaffMember
- [x] Standard
- [x] StandardLink
- [x] Subject
- [x] Tag, Tagging (ActsAsTaggableOn)
- [x] Integrations::WebhookConfiguration

#### 3.3. Model Concerns
- [x] Migrate all concerns from `app/models/concerns/lcms/engine/`
- [x] Remove `Lcms::Engine` namespace from concerns
- [x] Update paths in models

**Migration path:**
```
FROM: app/models/concerns/lcms/engine/*.rb
TO:   app/models/concerns/*.rb
```

**Actions during migration:**
1. Remove `module Lcms::Engine` wrapper
2. Update namespace in `extend ActiveSupport::Concern`
3. Update references to other classes

---

### Phase 4: Controllers and Routes

#### 4.1. Base Controllers
- [x] ApplicationController
- [x] WelcomeController
- [x] ResourcesController
- [x] DocumentsController
- [x] MaterialsController
- [x] RegistrationsController (Devise)

#### 4.2. Admin Panel (14 controllers)
- [x] Admin::AdminController (base)
- [x] Admin::WelcomeController
- [x] Admin::ResourcesController
- [x] Admin::DocumentsController
- [x] Admin::MaterialsController
- [x] Admin::UsersController
- [x] Admin::CurriculumsController
- [x] Admin::StandardsController
- [x] Admin::AccessCodesController
- [x] ~~Admin::SettingsController~~
- [x] Admin::BatchReimportsController

#### 4.3. API Controllers
- [x] Api::BaseController
- [x] Api::ResourcesController

#### 4.4. Controller Concerns
- [x] LocationStorable
- [x] Flashable
- [x] NestedReimportable
- [x] Queryable
- [x] Reimportable
- [x] GoogleCredentials

#### 4.5. Routes
- [x] Integrate routes.rb from engine into `config/routes.rb`
- [x] Remove `Lcms::Engine::Engine.routes.draw`
- [x] Configure Devise routes
- [x] Configure Resque/Solid Queue dashboard
- [x] Check catch-all route: `get '/*slug' => 'resources#show'`

**Migration path:**
```
FROM: app/controllers/lcms/engine/*.rb
TO:   app/controllers/*.rb
```

---

### Phase 5: Background Jobs

#### 5.1. Job Classes (Priority: HIGH)
- [x] ApplicationJob (base)
- [x] DocumentParseJob
- [x] DocumentGenerateJob
- [x] DocumentGenerateGdocJob
- [x] DocumentGeneratePdfJob
- [x] DocumentBundleGenerateJob
- [x] MaterialParseJob
- [x] MaterialGenerateJob
- [x] MaterialGenerateGdocJob
- [x] MaterialGeneratePdfJob
- [x] Integrations::WebhookCallJob

#### 5.2. Job Concerns
- [x] Migrate concerns from `app/jobs/concerns/`
  - NestedResqueJob
  - RetryDelayed
  - RetrySimple

#### 5.3. Queue Configuration
- [x] Decide: Resque vs Solid Queue (chose Resque)
- [x] Configure queue adapter in application.rb
- [x] Configure Redis connection
- [x] Migrate lib/resque_job.rb
- [x] Migrate lib/tasks/resque.rake

**Option A: Keep Resque**
```ruby
# config/application.rb
config.active_job.queue_adapter = :resque

# lib/tasks/resque.rake
require 'resque/tasks'
require 'resque/scheduler/tasks'
```

**Option B: Migrate to Solid Queue (Rails 8.1)**
```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue
```

**Migration path:**
```
FROM: app/jobs/lcms/engine/*.rb
TO:   app/jobs/*.rb
```

---

### Phase 6: Views and Assets

#### 6.1. Layouts and Shared Views
- [x] Migrate layouts from `app/views/layouts/`
- [x] Migrate shared partials from `app/views/lcms/engine/shared/`
- [x] Update paths in layout files

#### 6.2. Specific Views by Controller
- [x] admin/* (many views for admin panel)
- [x] documents/* (including gdoc subfolders)
- [x] materials/*
- [x] resources/*
- [x] welcome/*
- [x] devise/* (authentication views)

#### 6.3. Assets
- [x] Migrate stylesheets (SCSS) from `app/assets/stylesheets/lcms/engine/`
  - application.bootstrap.scss
  - pdf.scss
  - pdf_plain.scss
  - ckeditor.scss
- [x] Migrate JavaScript from `app/javascript/`
- [x] Update package.json with all required dependencies
- [x] Configure asset pipeline paths
- [x] Add paths for Bootstrap Icons and FontAwesome

#### 6.4. Helpers
- [x] Migrate all helper files from `app/helpers/lcms/engine/`
- [x] Migrate admin helper files
- [x] Remove Lcms::Engine namespace from helpers
- [x] Update helper references

**Asset configuration:**
```ruby
# config/application.rb
config.assets.paths << Rails.root.join('node_modules/bootstrap-icons/font')
config.assets.paths << Rails.root.join('node_modules/@fortawesome/fontawesome-free/webfonts')
```

**Migration path:**
```
FROM: app/views/lcms/engine/**/*
TO:   app/views/**/*

FROM: app/assets/*/lcms/engine/*
TO:   app/assets/*/<appropriate_path>/*
```

---

### Phase 7: Lib and Service Classes

#### 7.1. Document Exporters (CRITICAL functionality)
- [x] DocumentExporter::Base
- [x] DocumentExporter::Gdoc::Base
- [x] DocumentExporter::Gdoc::Document
- [x] DocumentExporter::Gdoc::TeacherMaterial
- [x] DocumentExporter::Gdoc::StudentMaterial
- [x] DocumentExporter::Gdoc::Material
- [x] DocumentExporter::Pdf::Base
- [x] DocumentExporter::Pdf::Document
- [x] DocumentExporter::Pdf::TeacherMaterial
- [x] DocumentExporter::Pdf::StudentMaterial
- [x] DocumentExporter::Pdf::Material
- [x] DocumentExporter::Thumbnail

#### 7.2. DocTemplate Classes
- [x] DocTemplate (lib/doc_template.rb)
- [x] DocTemplate::Tables::Base
- [x] DocTemplate::Tables::Target
- [x] DocTemplate::Tables::MaterialMetadata

#### 7.3. Forms
- [x] DocumentForm
- [x] CurriculumForm
- [x] MaterialForm
- [x] ImportForm
- [x] StandardForm

#### 7.4. Queries
- [x] BaseQuery
- [x] AdminMaterialsQuery
- [x] AdminDocumentsQuery

#### 7.5. Uploaders (CarrierWave)
- [x] DocumentBundleUploader
- [x] StaffImageUploader
- [x] SocialThumbnailUploader
- [x] ResourceImageUploader
- [x] BackupUploader

#### 7.6. Middleware
- [x] RemoveSession

#### 7.7. Tasks
- [x] ResourceTasks

#### 7.8. Other Lib Files
- [x] ResqueJob (lib/resque_job.rb)
- [x] All other classes from lib/

**Migration path:**
```
FROM: lib/*
TO:   lib/* (in main application)

FROM: app/forms/lcms/engine/*
TO:   app/forms/*

FROM: app/queries/lcms/engine/*
TO:   app/queries/*

FROM: app/uploaders/*
TO:   app/uploaders/*
```

**Important:** Configure autoload paths:
```ruby
# config/application.rb
config.autoload_paths += [
  Rails.root.join('lib'),
  Rails.root.join('app/forms'),
  Rails.root.join('app/queries')
]
```

---

### Phase 8: Additional Components

#### 8.1. Localization
- [x] Migrate all YAML files from `config/locales/`
- [x] Update namespace keys (remove lcms.engine if needed)

**Migration path:**
```
FROM: config/locales/**/*.yml
TO:   config/locales/**/*.yml
```

#### 8.2. Tests (optional)
- [x] Migrate specs from spec/
- [x] Adapt factories (FactoryBot) from spec/factories/
- [x] Update paths and namespace in tests
- [x] Configure RSpec helpers
- [x] Migrate test fixtures

#### 8.3. Public Files
- [x] Migrate static files from public/
- [x] Check paths to static resources

#### 8.4. Documentation
- [x] Migrate docs/ if needed
- [x] Update README with migration information

---

## Key Changes During Migration

### 1. Namespace

**Before (in engine):**
```ruby
module Lcms
  module Engine
    class Document < ApplicationRecord
      # ...
    end
  end
end
```

**After (in application):**
```ruby
class Document < ApplicationRecord
  # ...
end
```

**Actions:**
- Remove `module Lcms::Engine` from all classes
- Update all references between classes
- Fix autoload paths
- Update paths in tests

### 2. Routes

**Before (in engine):**
```ruby
Lcms::Engine::Engine.routes.draw do
  resources :documents
  # ...
end
```

**After (in application):**
```ruby
Rails.application.routes.draw do
  resources :documents
  # ...
end
```

**Important:**
- URL structure may change
- Verify all url helpers
- Update links in views

### 3. Asset Pipeline

**Rails 8.1 uses Propshaft instead of Sprockets**

**Before:**
```ruby
# Sprockets directives
//= require jquery
//= require_tree .
```

**After:**
```javascript
// Import maps or esbuild
import "jquery"
```

**Actions:**
- Convert manifest files
- Verify CKEditor compatibility
- Update asset paths

### 4. Job Backend

**Option A: Resque (as in engine)**
```ruby
config.active_job.queue_adapter = :resque
```

**Option B: Solid Queue (Rails 8.1 default)**
```ruby
config.active_job.queue_adapter = :solid_queue
```

**Recommendation:** Start with Resque for compatibility, then migrate to Solid Queue

### 5. Devise

**Before (in engine):**
```ruby
devise_for :users,
  class_name: 'Lcms::Engine::User',
  module: :devise
```

**After (in application):**
```ruby
devise_for :users
```

**Actions:**
- Remove class_name and module options
- Configure Devise in main application
- Verify routes and helpers

### 6. Autoload Paths

**Add to config/application.rb:**
```ruby
config.autoload_paths += [
  Rails.root.join('lib'),
  Rails.root.join('app/forms'),
  Rails.root.join('app/queries'),
  Rails.root.join('app/jobs/concerns')
]

config.eager_load_paths += [
  Rails.root.join('lib')
]
```

### 7. I18n Load Paths

**Before (in engine):**
```ruby
config.i18n.load_path += Dir[
  config.root.join('config', 'locales', '**', '*.yml')
]
```

**After (in application):**
```ruby
# Automatically loaded from config/locales/
# But if specific structure needed:
config.i18n.load_path += Dir[
  Rails.root.join('config', 'locales', '**', '*.yml')
]
```

---

## Next Steps

### Strategy Selection

**Option A: Gradual Migration (RECOMMENDED)**
- Start with base components
- Test each iteration
- Can maintain gem in parallel
- Minimize risks
- Takes longer

**Option B: Full Migration**
- Migrate everything at once
- Faster completion
- Higher risk of errors
- Harder to roll back changes

**Option C: Priority Functionality**
- Identify critical features
- Migrate only necessary parts
- Rest later or not at all
- Requires usage analysis

### Questions to Clarify

1. **Which strategy is preferred?** (A, B, or C)

2. **Background Jobs:**
   - Keep Resque?
   - Migrate to Solid Queue?
   - Use Sidekiq?

3. **Functionality Priorities:**
   - Which functions are critical?
   - What is rarely used?
   - What can be postponed?

4. **Testing:**
   - Migrate tests from engine?
   - Write new tests?
   - What coverage is required?

5. **Deployment:**
   - Is there a production environment with current engine?
   - Is data migration needed?
   - Is backward compatibility needed?

### Readiness to Start

Before starting, ensure:
- [ ] Database backup exists
- [ ] Git branch for migration is set up
- [ ] External service dependencies are understood
- [ ] AWS, Google API credentials access is available
- [ ] Project timeline is clear
- [ ] Resources for testing are allocated

---

## Useful Commands

### Analyze Engine Code
```bash
# Count files
find ../gems/lcms-engine/app -name "*.rb" | wc -l

# List all models
find ../gems/lcms-engine/app/models -name "*.rb"

# List controllers
find ../gems/lcms-engine/app/controllers -name "*.rb"

# Dependencies
cat ../gems/lcms-engine/lcms-engine.gemspec | grep add_dependency
```

### Verify Migration
```bash
# Verify model loading
rails runner "puts User.count"

# Verify routes
rails routes | grep documents

# Verify asset precompilation
rails assets:precompile

# Verify jobs
rails runner "DocumentParseJob.perform_later(1)"
```

### Debugging
```bash
# Verify autoload paths
rails runner "puts ActiveSupport::Dependencies.autoload_paths"

# Verify loaded gems
rails runner "puts Gem.loaded_specs.keys.sort"

# Verify I18n paths
rails runner "puts I18n.load_path"
```

---

## Completion Checklist

### Phase 1: Infrastructure
- [x] All gem dependencies added
- [x] Bundle install successful
- [x] Initializers migrated
- [ ] Credentials configured
- [x] Redis working

### Phase 2: Database
- [x] All migrations created
- [x] Migrations applied successfully
- [x] Seeds working
- [x] Data correct

### Phase 3: Models
- [x] All models migrated
- [x] Concerns migrated
- [x] Associations working
- [x] Validations in place

### Phase 4: Controllers
- [ ] Base controllers working
- [ ] Admin panel functional
- [ ] API endpoints working
- [ ] Routes configured

### Phase 5: Jobs
- [x] All jobs migrated
- [x] Queue working (Resque configured)
- [ ] Jobs execute successfully (blocked by missing dependencies from Phase 7)
- [ ] Dashboard accessible (not tested yet)

### Phase 6: Views & Assets
- [x] All views migrated (90 .erb files)
- [x] Layouts applied
- [x] Stylesheets migrated (CSS/SCSS)
- [x] JavaScript migrated
- [x] Helpers migrated and updated
- [x] Asset pipeline configured
- [ ] Views rendering (needs testing with Docker)
- [ ] CKEditor functional (needs testing)

### Phase 7: Lib
- [ ] Exporters working
- [ ] Uploaders functional
- [ ] Forms validating
- [ ] Queries returning data

### Phase 8: Final
- [ ] Localization working
- [ ] Tests passing
- [ ] Documentation updated
- [ ] Performance acceptable

---

**Last Updated:** 2025-11-30
**Version:** 1.3
**Status:** Phase 6 Complete (Views and Assets)
**Priority:** High
