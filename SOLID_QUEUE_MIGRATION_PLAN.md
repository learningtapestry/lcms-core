# Migration Plan: Resque to Solid Queue

## Current State

**Currently Using:** Resque + Resque Scheduler + Redis
**Version:** Resque 2.7.0, Redis 5.4.1
**Reason for Choice:** Full compatibility with code from lcms-engine gem

## Why Migrate to Solid Queue?

### Solid Queue Advantages:
1. **Native Rails 8.1 Integration** - Official solution from Rails core team
2. **Uses PostgreSQL** - No separate Redis required for queues
3. **Infrastructure Simplification** - Fewer services to maintain
4. **Built-in Support** - Better integration with Rails ecosystem
5. **Fewer Dependencies** - Can remove Resque, Resque Scheduler

### What We Lose in Migration:
- ⚠️ Resque Web UI (need to find alternative)
- ⚠️ Battle-tested solution used for years
- ⚠️ Large community and examples

## Migration Plan

### Stage 1: Preparation (When: after main functionality stabilization)

**When to Start:**
- ✅ All jobs from engine are migrated and working on Resque
- ✅ Application is stable in development
- ✅ All main features are tested
- ✅ Have time for experiments

**Preparation Tasks:**
- [ ] Study Solid Queue documentation
- [ ] Audit all existing jobs
- [ ] Identify jobs with recurring schedules (from Resque Scheduler)
- [ ] List unique Resque features being used
- [ ] Create test environment for migration

**Time:** 1-2 days

---

### Stage 2: Installing and Configuring Solid Queue

#### 2.1. Gemfile

**Remove:**
```ruby
gem "resque", "~> 2.6"
gem "resque-scheduler", "~> 4.10"
```

**Ensure present:**
```ruby
gem "solid_queue"  # Already installed in Rails 8.1
```

#### 2.2. Database Migrations

```bash
docker compose run --rm rails bin/rails solid_queue:install
docker compose run --rm rails bin/rails db:migrate
```

This creates tables:
- `solid_queue_jobs`
- `solid_queue_scheduled_executions`
- `solid_queue_ready_executions`
- `solid_queue_claimed_executions`
- `solid_queue_blocked_executions`
- `solid_queue_failed_executions`
- `solid_queue_pauses`
- `solid_queue_processes`
- `solid_queue_semaphores`

#### 2.3. Configuration

**config/queue.yml** (create new file):
```yaml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
      concurrency_maintenance_interval: 300

  workers:
    - queues: "*"
      threads: 5
      processes: 3
      polling_interval: 0.1
```

**config/application.rb:**
```ruby
# Change from
config.active_job.queue_adapter = :resque

# To
config.active_job.queue_adapter = :solid_queue
```

#### 2.4. Docker Compose

**Remove resque service:**
```yaml
# Remove entire resque block from docker-compose.yml
```

**Update rails command:**
```yaml
rails:
  command: |
    bash -c "bundle install && bin/rails db:prepare && bin/rails solid_queue:start & rails server -b 0.0.0.0"
```

Or create separate process for Solid Queue:
```yaml
solid_queue:
  image: lcms-core:3.4.7
  command: |
    bash -c "bundle install && bin/rails solid_queue:start"
  volumes:
    - .:/app
    - bundle-3.4.7:/usr/local/bundle
  depends_on:
    - db
  environment:
    - RAILS_ENV=development
    - DATABASE_HOST=db
    - DATABASE_USERNAME=postgres
    - DATABASE_PASSWORD=postgres
    - DATABASE_NAME=lcms
```

**Time:** 2-3 hours

---

### Stage 3: Adapting Jobs

#### 3.1. Basic Jobs

Most jobs don't require changes as they use standard ActiveJob API:

```ruby
# Works in both Resque and Solid Queue
class DocumentParseJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    # ...
  end
end
```

#### 3.2. Recurring Jobs (Replacing Resque Scheduler)

**Option A: Use Solid Queue recurring tasks**

Solid Queue supports recurring jobs through configuration:

**config/queue.yml:**
```yaml
production:
  recurring:
    - class_name: CleanupOldRecordsJob
      schedule: every day at 2am

    - class_name: SendWeeklyReportJob
      schedule: every monday at 9am

    - class_name: SyncWithExternalApiJob
      schedule: every 30 minutes
```

**Option B: Use `mission_control-jobs` gem**

```ruby
# Gemfile
gem "mission_control-jobs"
```

Provides Web UI for job management.

**Option C: Use `solid_queue-recurring_tasks`**

```ruby
# Gemfile
gem "solid_queue-recurring_tasks"
```

#### 3.3. Jobs with Unique Resque Features

If jobs use:

**Resque.enqueue_at / enqueue_in:**
```ruby
# Was (Resque)
Resque.enqueue_at(1.hour.from_now, SomeJob, arg1, arg2)

# Now (Solid Queue via ActiveJob)
SomeJob.set(wait: 1.hour).perform_later(arg1, arg2)
```

**Resque hooks (before_enqueue, after_perform, etc.):**
Replace with ActiveJob callbacks:
```ruby
class SomeJob < ApplicationJob
  before_enqueue :check_something
  after_perform :log_completion

  def perform(args)
    # ...
  end

  private

  def check_something
    # ...
  end

  def log_completion
    # ...
  end
end
```

**Time:** 3-5 days (depends on number of jobs)

---

### Stage 4: Testing

#### 4.1. Unit Tests

Update tests if they depend on Resque:

```ruby
# Was
require 'resque_spec'

# Now - use standard ActiveJob tests
require 'rails_helper'

RSpec.describe SomeJob do
  include ActiveJob::TestHelper

  it 'enqueues job' do
    expect {
      SomeJob.perform_later(arg)
    }.to have_enqueued_job(SomeJob).with(arg)
  end
end
```

#### 4.2. Integration Tests

- [ ] Verify job enqueueing
- [ ] Verify job execution
- [ ] Verify retry logic
- [ ] Verify scheduled jobs
- [ ] Verify recurring jobs
- [ ] Load testing

#### 4.3. Manual Testing

- [ ] Run all critical jobs manually
- [ ] Verify document generation (PDF, Google Docs)
- [ ] Verify document parsing
- [ ] Verify webhooks
- [ ] Verify email sending

**Time:** 2-3 days

---

### Stage 5: Monitoring and Web UI

#### 5.1. Mission Control Jobs (Recommended)

```ruby
# Gemfile
gem "mission_control-jobs"
```

```ruby
# config/routes.rb
mount MissionControl::Jobs::Engine, at: "/jobs"
```

Provides:
- List of jobs (pending, running, failed)
- View job parameters
- Retry failed jobs
- Statistics

#### 5.2. Alternatives

- **Avo** - admin panel with Solid Queue support
- **ActiveAdmin** - can add pages for Solid Queue
- **Custom dashboard** - build your own based on `SolidQueue::Job` model

**Time:** 1-2 days

---

### Stage 6: Deployment and Rollback

#### 6.1. Deployment Plan

1. **Staging environment:**
   - Deploy with Solid Queue
   - Full testing
   - Monitor for a week

2. **Production deployment:**
   - Deploy during low-traffic time
   - Gradual transition (canary deployment if possible)
   - 24/7 monitoring first days

#### 6.2. Rollback Plan

**If something goes wrong:**

1. **Quick rollback:**
```bash
# In Gemfile restore
gem "resque", "~> 2.6"
gem "resque-scheduler", "~> 4.10"

# In config/application.rb
config.active_job.queue_adapter = :resque

# Restore resque service in docker-compose.yml
# Start
docker compose up -d
```

2. **Data migration:**
- Jobs in Solid Queue queues need to be recreated manually
- Or write rake task to migrate pending jobs

**Time:** 1-2 days (+ week of monitoring)

---

## Readiness Criteria for Migration

### Before starting migration ensure:
- ✅ All jobs from engine are migrated
- ✅ Application is stable
- ✅ Full test coverage exists
- ✅ Monitoring and alerts are in place
- ✅ Rollback plan exists
- ✅ Staging environment for tests exists
- ✅ Time for experiments (minimum 2 weeks)

### Signs NOT to migrate now:
- ❌ Application is unstable
- ❌ Active feature development ongoing
- ❌ No time for thorough testing
- ❌ Resque works well with no issues
- ❌ Team not familiar with Solid Queue

---

## Overall Time Estimate

| Stage | Time | Priority |
|-------|------|----------|
| 1. Preparation | 1-2 days | Low |
| 2. Installation and setup | 2-3 hours | Medium |
| 3. Adapting Jobs | 3-5 days | High |
| 4. Testing | 2-3 days | Critical |
| 5. Monitoring and UI | 1-2 days | Medium |
| 6. Deployment and rollback | 1-2 days + week monitoring | Critical |
| **TOTAL** | **2-3 weeks** | |

---

## Risks and Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Job loss during migration | Medium | High | Thorough testing, rollback plan |
| Recurring job issues | Medium | Medium | Use proven solution (Mission Control) |
| Performance issues | Low | High | Load testing on staging |
| Legacy code incompatibility | Low | Medium | Code review of all jobs |
| Monitoring difficulties | Medium | Low | Use Mission Control Jobs |

---

## Recommendation

**When to migrate:**
- After completing migration of all functionality from engine
- When application has been stable for 2-3 months
- When staging environment exists
- When have 2-3 weeks for calm migration

**Alternative:**
- If Resque works well, can **keep as is**
- Solid Queue is nice-to-have, but not must-have
- Resque is battle-tested solution, used in production by many companies

---

## Useful Links

- [Solid Queue GitHub](https://github.com/basecamp/solid_queue)
- [Solid Queue Guide](https://github.com/basecamp/solid_queue/blob/main/README.md)
- [Mission Control Jobs](https://github.com/basecamp/mission_control-jobs)
- [Rails Guides: Active Job](https://guides.rubyonrails.org/active_job_basics.html)
- [Migrating from Sidekiq to Solid Queue](https://dev.to/rails/migrating-from-sidekiq-to-solid-queue) (similar process)

---

**Date Created:** 2025-11-28
**Version:** 1.0
**Status:** Planned (not started)
**Priority:** Low (after main functionality stabilization)
