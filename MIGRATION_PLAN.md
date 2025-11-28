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
- [ ] Migrate all initializers from `config/initializers/`
- [ ] Configure `config/application.rb`
- [ ] Create environment-specific configurations
- [ ] Set up credentials for API keys (Google, AWS)

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
- [ ] Enable PostgreSQL extensions (hstore, plpgsql)
- [ ] Create migrations for all 31 tables
- [ ] Create indexes according to schema.rb

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
- [ ] User (`app/models/user.rb`)
- [ ] Curriculum
- [ ] Resource
- [ ] Document
- [ ] Material

#### 3.2. Related Models
- [ ] AccessCode
- [ ] Author
- [ ] CopyrightAttribution
- [ ] DocumentBundle
- [ ] DocumentPart
- [ ] Download
- [ ] ElaBucket
- [ ] Grade
- [ ] Module
- [ ] ReadingAssignmentAuthor
- [ ] ReadingAssignmentText
- [ ] ReimportBatch
- [ ] ResourceAdditionalResource
- [ ] ResourceDownload
- [ ] ResourceReadingAssignment
- [ ] ResourceRelatedResource
- [ ] ResourceStat
- [ ] ResourceStandard
- [ ] Settings
- [ ] SocialThumbnail
- [ ] StaffMember
- [ ] Standard
- [ ] StandardLink
- [ ] Subject
- [ ] Tag, Tagging (ActsAsTaggableOn)
- [ ] Integrations::WebhookConfiguration

#### 3.3. Model Concerns
- [ ] Migrate all concerns from `app/models/concerns/lcms/engine/`
- [ ] Remove `Lcms::Engine` namespace from concerns
- [ ] Update paths in models

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
- [ ] ApplicationController
- [ ] WelcomeController
- [ ] ResourcesController
- [ ] DocumentsController
- [ ] MaterialsController
- [ ] RegistrationsController (Devise)

#### 4.2. Admin Panel (14 controllers)
- [ ] Admin::AdminController (base)
- [ ] Admin::WelcomeController
- [ ] Admin::ResourcesController
- [ ] Admin::DocumentsController
- [ ] Admin::MaterialsController
- [ ] Admin::UsersController
- [ ] Admin::CurriculumsController
- [ ] Admin::StandardsController
- [ ] Admin::AccessCodesController
- [ ] Admin::SettingsController
- [ ] Admin::BatchReimportsController

#### 4.3. API Controllers
- [ ] Api::BaseController
- [ ] Api::ResourcesController

#### 4.4. Controller Concerns
- [ ] Lcms::Engine::LocationStorable
- [ ] Other concerns

#### 4.5. Routes
- [ ] Integrate routes.rb from engine into `config/routes.rb`
- [ ] Remove `Lcms::Engine::Engine.routes.draw`
- [ ] Configure Devise routes
- [ ] Configure Resque/Solid Queue dashboard
- [ ] Check catch-all route: `get '/*slug' => 'resources#show'`

**Migration path:**
```
FROM: app/controllers/lcms/engine/*.rb
TO:   app/controllers/*.rb
```

---

### Phase 5: Background Jobs

#### 5.1. Job Classes (Priority: HIGH)
- [ ] ApplicationJob (base)
- [ ] DocumentParseJob
- [ ] DocumentGenerateJob
- [ ] DocumentGenerateGdocJob
- [ ] DocumentGeneratePdfJob
- [ ] DocumentBundleGenerateJob
- [ ] MaterialParseJob
- [ ] MaterialGenerateGdocJob
- [ ] MaterialGeneratePdfJob
- [ ] Integrations::WebhookCallJob

#### 5.2. Job Concerns
- [ ] Migrate concerns from `app/jobs/concerns/`

#### 5.3. Queue Configuration
- [ ] Decide: Resque vs Solid Queue
- [ ] Configure queue adapter in application.rb
- [ ] Configure recurring jobs (if using resque-scheduler)
- [ ] Configure Redis connection

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
- [ ] Migrate layouts from `app/views/layouts/`
- [ ] Migrate shared partials from `app/views/lcms/engine/shared/`
- [ ] Update paths in layout files

#### 6.2. Specific Views by Controller
- [ ] admin/* (many views for admin panel)
- [ ] documents/* (including gdoc subfolders)
- [ ] materials/*
- [ ] resources/*
- [ ] welcome/*

#### 6.3. Assets
- [ ] Migrate stylesheets (SCSS) from `app/assets/stylesheets/lcms/engine/`
  - application.bootstrap.scss
  - pdf.scss
  - pdf_plain.scss
  - ckeditor.scss
- [ ] Migrate JavaScript (if any in app/assets/javascripts/)
- [ ] Configure asset pipeline (Propshaft instead of Sprockets)
- [ ] Configure CKEditor assets
- [ ] Add paths for Bootstrap Icons and FontAwesome

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
- [ ] DocumentExporter::Base
- [ ] DocumentExporter::Gdoc::Base
- [ ] DocumentExporter::Gdoc::Document
- [ ] DocumentExporter::Gdoc::TeacherMaterial
- [ ] DocumentExporter::Gdoc::StudentMaterial
- [ ] DocumentExporter::Gdoc::Material
- [ ] DocumentExporter::Pdf::Base
- [ ] DocumentExporter::Pdf::Document
- [ ] DocumentExporter::Pdf::TeacherMaterial
- [ ] DocumentExporter::Pdf::StudentMaterial
- [ ] DocumentExporter::Pdf::Material
- [ ] DocumentExporter::Thumbnail

#### 7.2. DocTemplate Classes
- [ ] DocTemplate (lib/doc_template.rb)
- [ ] DocTemplate::Tables::Base
- [ ] DocTemplate::Tables::Target
- [ ] DocTemplate::Tables::MaterialMetadata

#### 7.3. Forms
- [ ] DocumentForm
- [ ] CurriculumForm
- [ ] MaterialForm
- [ ] ImportForm
- [ ] StandardForm

#### 7.4. Queries
- [ ] BaseQuery
- [ ] AdminMaterialsQuery
- [ ] AdminDocumentsQuery

#### 7.5. Uploaders (CarrierWave)
- [ ] DocumentBundleUploader
- [ ] StaffImageUploader
- [ ] SocialThumbnailUploader
- [ ] ResourceImageUploader
- [ ] BackupUploader

#### 7.6. Middleware
- [ ] RemoveSession

#### 7.7. Tasks
- [ ] ResourceTasks

#### 7.8. Other Lib Files
- [ ] ResqueJob (lib/resque_job.rb)
- [ ] All other classes from lib/

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
- [ ] Migrate all YAML files from `config/locales/`
- [ ] Update namespace keys (remove lcms.engine if needed)

**Migration path:**
```
FROM: config/locales/**/*.yml
TO:   config/locales/**/*.yml
```

#### 8.2. Tests (optional)
- [ ] Migrate specs from spec/
- [ ] Adapt factories (FactoryBot) from spec/factories/
- [ ] Update paths and namespace in tests
- [ ] Configure RSpec helpers
- [ ] Migrate test fixtures

#### 8.3. Public Files
- [ ] Migrate static files from public/
- [ ] Check paths to static resources

#### 8.4. Documentation
- [ ] Migrate docs/ if needed
- [ ] Update README with migration information

---

## Recommended Timeline

### Iteration 1: Foundation (Week 1-2)

**Goal:** Prepare basic infrastructure

1. **Day 1-2: Dependencies**
   - [x] Update Gemfile
   - [x] Bundle install
   - [x] Decide on Resque vs Solid Queue

2. **Day 3-4: Configuration**
   - [ ] Migrate initializers
   - [ ] Configure application.rb
   - [ ] Set up credentials (AWS, Google API)
   - [ ] Configure Redis

3. **Day 5-7: Database**
   - [ ] Create migrations for all tables
   - [ ] Run migrations
   - [ ] Verify schema.rb

4. **Day 8-10: Core Models**
   - [ ] Migrate User
   - [ ] Migrate Resource
   - [ ] Migrate Document
   - [ ] Migrate Material
   - [ ] Migrate Curriculum

**Completion Criteria:** Application starts, models load without errors

---

### Iteration 2: Core Functionality (Week 3-4)

**Goal:** Migrate main business logic

1. **Day 1-3: All Models**
   - [ ] Migrate remaining models
   - [ ] Migrate model concerns
   - [ ] Verify associations

2. **Day 4-6: Base Controllers**
   - [ ] WelcomeController
   - [ ] ResourcesController
   - [ ] DocumentsController
   - [ ] MaterialsController
   - [ ] ApplicationController

3. **Day 7-8: Views and Layouts**
   - [ ] Layouts
   - [ ] Shared partials
   - [ ] Basic views for controllers

4. **Day 9-10: Routes and Verification**
   - [ ] Configure routes.rb
   - [ ] Configure Devise routes
   - [ ] Verify page accessibility

**Completion Criteria:** Basic pages work, can view resources

---

### Iteration 3: Admin Panel (Week 5-6)

**Goal:** Migrate administrative interface

1. **Day 1-4: Admin Controllers**
   - [ ] Admin::AdminController
   - [ ] Admin::WelcomeController
   - [ ] Admin::ResourcesController
   - [ ] Admin::DocumentsController
   - [ ] Admin::MaterialsController
   - [ ] Admin::UsersController
   - [ ] Remaining admin controllers

2. **Day 5-7: Admin Views**
   - [ ] All views for admin panel
   - [ ] Forms
   - [ ] Tables and lists

3. **Day 8-9: Forms and Queries**
   - [ ] Migrate Forms
   - [ ] Migrate Queries
   - [ ] Verify filters and search work

4. **Day 10: Testing**
   - [ ] Verify CRUD operations
   - [ ] Verify access permissions

**Completion Criteria:** Admin panel fully functional

---

### Iteration 4: Background Processing (Week 7)

**Goal:** Configure background jobs

1. **Day 1-2: Jobs**
   - [ ] Migrate all Job classes
   - [ ] Configure queue adapter
   - [ ] Configure Redis connection

2. **Day 3-4: Lib Classes for Jobs**
   - [ ] DocumentExporter::Gdoc::*
   - [ ] DocumentExporter::Pdf::*
   - [ ] Other job dependencies

3. **Day 5: Queue Configuration**
   - [ ] Configure Resque/Solid Queue
   - [ ] Configure recurring jobs
   - [ ] Verify dashboard

4. **Day 6-7: Testing**
   - [ ] Run test jobs
   - [ ] Verify document generation
   - [ ] Verify PDF/Google Docs export

**Completion Criteria:** All background jobs work correctly

---

### Iteration 5: Assets and Polish (Week 8)

**Goal:** Complete migration and test

1. **Day 1-2: Assets**
   - [ ] Migrate CSS/SCSS
   - [ ] Migrate JavaScript
   - [ ] Configure asset pipeline
   - [ ] Configure CKEditor

2. **Day 3-4: Lib Classes**
   - [ ] DocTemplate
   - [ ] Uploaders
   - [ ] Middleware
   - [ ] Remaining lib files

3. **Day 5-6: Localization and Seeds**
   - [ ] Migrate localization
   - [ ] Migrate seeds
   - [ ] Run seeds

4. **Day 7-8: Final Testing**
   - [ ] Full smoke test of all functions
   - [ ] Verify integrations (Google Drive, AWS S3)
   - [ ] Verify search (Elasticsearch)
   - [ ] Performance testing

**Completion Criteria:** Application fully functional, ready for deployment

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
- [ ] All migrations created
- [ ] Migrations applied successfully
- [ ] Seeds working
- [ ] Data correct

### Phase 3: Models
- [ ] All models migrated
- [ ] Concerns migrated
- [ ] Associations working
- [ ] Validations in place

### Phase 4: Controllers
- [ ] Base controllers working
- [ ] Admin panel functional
- [ ] API endpoints working
- [ ] Routes configured

### Phase 5: Jobs
- [ ] All jobs migrated
- [ ] Queue working
- [ ] Jobs execute successfully
- [ ] Dashboard accessible

### Phase 6: Views & Assets
- [ ] Views rendering
- [ ] Layouts applied
- [ ] CSS loading
- [ ] JavaScript working
- [ ] CKEditor functional

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

**Last Updated:** 2025-11-28
**Version:** 1.0
**Status:** Phase 1.1 Complete
**Priority:** High
