Use the test-writer agent to write RSpec tests for: $ARGUMENTS

If no file is specified, ask which file needs tests.

Steps:
1. Read the source file
2. Check spec/factories/ for existing factories to reuse
3. Check spec/support/ for shared helpers
4. Write comprehensive tests covering: happy path, edge cases, error handling
5. Run the new spec to confirm it passes:

```bash
docker compose run --rm test bundle exec rspec --pattern 'spec/path/to/new_spec.rb' spec/path/to/new_spec.rb
```

Remember: ALWAYS override --pattern when running individual spec files.
