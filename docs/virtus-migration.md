# Migrating from Virtus to ActiveModel::Attributes

This guide covers the migration of DocTemplate objects and form classes from
the `virtus` gem to Rails-native `ActiveModel::Attributes`.

## Key differences

### Attribute declaration

```ruby
# Before (Virtus)
class MyObject
  include Virtus.model
  attribute :name, String
  attribute :items, Array[String], default: []
  attribute :metadata, Hash, default: {}
  attribute :active, Boolean, default: false
end

# After (ActiveModel::Attributes)
class MyObject
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :items, :json_array, default: -> { [] }
  attribute :metadata, :json_hash, default: -> { {} }
  attribute :active, :boolean, default: false
end
```

### Important changes

1. **Type symbols instead of classes** — use `:string`, `:integer`, `:boolean`
   instead of `String`, `Integer`, `Boolean`.

2. **Collection defaults must use lambdas** — `default: []` creates a shared
   mutable object. Always use `default: -> { [] }` or `default: -> { {} }`.

3. **Custom types for collections** — Virtus `Array[Type]` and `Hash` are
   replaced with custom types `:json_array` and `:json_hash` registered in
   `config/initializers/custom_types.rb`.

4. **No automatic filtering of unknown attributes** — Virtus silently ignores
   unknown keys. With `ActiveModel::Attributes` you need to filter manually:
   ```ruby
   def initialize(attrs = {})
     known = self.class.attribute_names.map(&:to_s)
     super(attrs.to_h.select { |k, _| known.include?(k.to_s) })
   end
   ```

5. **`attribute_set` is removed** — use `attribute_names` (returns an array of
   strings) or `attribute_types` (returns a hash of name → type) instead.

6. **`nil` handling for booleans** — Virtus coerced `nil` to `false` for
   `Boolean` attributes with `default: false`. `ActiveModel` applies the
   default only when the key is absent; explicitly passing `nil` keeps the
   value as `nil`.

## Migration checklist

- [ ] Replace `include Virtus.model` with `include ActiveModel::Model` and
      `include ActiveModel::Attributes`
- [ ] Change type declarations from class names to symbols
- [ ] Replace `Array[Type]` with `:json_array` and `Hash` with `:json_hash`
- [ ] Wrap collection defaults in lambdas (`default: -> { [] }`)
- [ ] Add unknown-attribute filtering to `initialize` if needed
- [ ] Replace `attribute_set.map(&:name)` with `attribute_names`
- [ ] Update references from `Activity::Activity` to `Activity::Item`
- [ ] Run tests to verify boolean `nil` handling matches expectations