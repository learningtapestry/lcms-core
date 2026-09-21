# frozen_string_literal: true

class SettingsForm
  # A flat group whose schema is a Hash of `leaf_key => field_type` (e.g.
  # :appearance, :pdf_renderer). Values are scalar fields edited directly; image
  # fields upload their file and store the resulting URL. Always valid.
  #
  # Image uploads happen in #commit (not #prepare), so a save rejected by an
  # invalid sibling group never uploads a file that would be orphaned.
  class FlatGroup < BaseGroup
    def initialize(key, schema)
      super(key)
      @schema = schema
    end

    def prepare(params)
      @params = params
    end

    def commit
      processed = process_image_uploads(@params)
      submitted = processed.permit(field_keys - list_keys - label_map_keys - callout_list_keys).to_h
      submitted.merge!(process_list_fields(processed))
      submitted.merge!(process_label_map_fields(processed))
      submitted.merge!(process_callout_list_fields(processed))
      # Compare against the defaults-merged values so a submission equal to the
      # current/default value is not persisted as a redundant override.
      #
      # Both sides are normalized to string keys first: the submitted list/map
      # fields are built with string keys, while current_with_defaults comes
      # back deep-symbolized from Settings.merge_with_defaults. Comparing them
      # raw means {"tip" => …} never equals {tip: …}, so every save would write
      # the shipped defaults into the DB as an explicit override — pinning them
      # against later releases.
      changes = submitted.reject { |k, v| same_value?(current_with_defaults[k.to_sym], v) }
      return if changes.empty?

      Settings.set(key, stored.merge(changes))
    end

    def reset(sub_key)
      if image_key?(sub_key)
        old_url = current_with_defaults[sub_key.to_sym]
        ImageUploader.delete_by_url(old_url)
      end
      Settings.unset_within(key, sub_key)
    end

    def to_partial_path
      "admin/settings/groups/flat"
    end

    # The schema (leaf_key => field_type) the view renders one row per.
    def fields
      @schema
    end

    # Current value of a leaf field, including defaults, for display.
    def value_for(field_key)
      current_with_defaults[field_key]
    end

    private

    # Key-agnostic equality for a settings value: scalars compare directly,
    # Hashes/Arrays-of-Hashes compare through #comparable.
    def same_value?(current, submitted)
      comparable(current) == comparable(submitted)
    end

    # Normalizes a value for comparison: string keys, plus nil-valued keys
    # dropped so a normalizer that always emits a key (normalize_callout_list
    # writes `"image" => nil` for a row with no icon) still matches a shipped
    # default that simply omits it. Nils are dropped on BOTH sides, so clearing
    # a value that IS currently set still reads as a change and gets persisted.
    def comparable(value)
      case value
      when Hash then value.deep_stringify_keys.compact.transform_values { |v| comparable(v) }
      when Array then value.map { |v| comparable(v) }
      else value
      end
    end

    def field_keys
      @schema.keys.map(&:to_s)
    end

    def image_keys
      @schema.select { |_k, type| type == :image }.keys.map(&:to_s)
    end

    def image_key?(sub_key)
      @schema[sub_key.to_sym] == :image
    end

    def list_keys
      @schema.select { |_k, type| type == :key_value_list }.keys.map(&:to_s)
    end

    def label_map_keys
      @schema.select { |_k, type| type == :label_map }.keys.map(&:to_s)
    end

    def callout_list_keys
      @schema.select { |_k, type| type == :callout_list }.keys.map(&:to_s)
    end

    # The fixed key set a :label_map field's submitted Hash may use, mirroring
    # the same coupling documented in the show/_label_map.html.erb partial.
    # `student_groupings` is currently the only :label_map field; if a second
    # one is added, turn this into a field-name => keys registry instead.
    def label_map_key_options
      DocTemplate::Tables::Activity::GROUPING_OPTIONS
    end

    def stored
      Settings.get(key) || {}
    end

    # Memoized: one read serves change detection in #commit and every leaf's
    # #value_for during render, instead of a cache fetch per field.
    def current_with_defaults
      @current_with_defaults ||= Settings.get(key, include_defaults: true) || {}
    end

    # Uploads only this group's own image fields, so an image is never
    # re-uploaded once per group the way a global scan across SETTINGS would.
    #
    # An image field only ever accepts an uploaded file. Any image key sent as a
    # plain string is dropped, never persisted as a URL: otherwise an admin could
    # write an arbitrary path/URL into a logo field, which later feeds
    # ImageUploader.delete_by_url (path traversal) and image_tag (javascript: XSS).
    def process_image_uploads(params)
      modified = params.to_unsafe_h
      image_keys.each do |k|
        if params[k].respond_to?(:tempfile)
          uploader = ImageUploader.new
          uploader.store!(params[k])
          modified[k] = uploader.url
        else
          modified.delete(k)
        end
      end
      ActionController::Parameters.new(modified)
    end

    # Permits every :key_value_list field as an array of {abbr, label} rows
    # (e.g. `lesson_types[][abbr]` / `lesson_types[][label]`) and normalizes
    # each into an ordered Hash keyed by abbreviation, ready to merge into the
    # scalar-only `submitted` hash built in #commit.
    #
    # Only a field the widget actually rendered/submitted is processed, marked
    # by a hidden `<key>_submitted` sentinel (see the _key_value_list partial).
    # Without this guard an omitted field would normalize to {} and wipe the
    # stored map — unlike scalar fields, which are simply preserved when absent
    # from the params. Submitting the sentinel with no rows still clears it.
    def process_list_fields(params)
      return {} if list_keys.empty?

      permitted = params.permit(list_keys.index_with { [:abbr, :label] }).to_h
      list_keys.each_with_object({}) do |k, result|
        next unless params.key?("#{k}_submitted")

        result[k] = normalize_list(permitted[k])
      end
    end

    # Builds the ordered abbreviation => label Hash from submitted rows.
    # Drops incomplete rows (blank abbreviation OR blank label): a mapping needs
    # both halves, and a blank-label entry would in any case be stripped on the
    # next read by Settings' deep_reject_blank_strings, silently losing the row.
    # Dedupes case-insensitively — DocumentPresenter#lesson_type_label folds keys
    # to lowercase for lookup, so two abbreviations differing only in case are
    # indistinguishable at render time; the later row wins (keeping its casing).
    def normalize_list(rows)
      Array(rows).each_with_object({}) do |row, hash|
        abbr = row["abbr"].to_s.strip
        label = row["label"].to_s.strip
        next if abbr.blank? || label.blank?

        hash.delete_if { |existing, _| existing.casecmp?(abbr) }
        hash[abbr] = label
      end
    end

    # Permits every :label_map field as a Hash restricted to its fixed key set
    # (e.g. `student_groupings[class]`) and normalizes it into a key => label
    # Hash ready to merge into `submitted`.
    #
    # Unlike :key_value_list the widget always submits a value for every fixed
    # key, so blank simply means "use the default" and no `_submitted`
    # sentinel is needed to tell that apart from "field omitted". A field
    # genuinely absent from params (e.g. a request that doesn't touch this
    # group) is left out of the result entirely here, exactly like scalar
    # fields — so it's preserved rather than wiped.
    def process_label_map_fields(params)
      return {} if label_map_keys.empty?

      permitted = params.permit(label_map_keys.index_with { label_map_key_options }).to_h
      label_map_keys.each_with_object({}) do |k, result|
        next unless params.key?(k)

        result[k] = normalize_label_map(permitted[k])
      end
    end

    # Builds the key => label Hash from the submitted map, stripping labels
    # and dropping blanks: an unconfigured key stays absent so the render
    # helper's titleized fallback applies, and a blank-label entry would in
    # any case be stripped on the next read by Settings' deep_reject_blank_strings.
    def normalize_label_map(map)
      Hash(map).each_with_object({}) do |(key, label), hash|
        label = label.to_s.strip
        hash[key] = label if label.present?
      end
    end

    # Permits every :callout_list field as an array of {type, title, image}
    # rows (e.g. `callout_types[][type]` / `[][title]` / `[][image]`) and
    # normalizes each into an ordered Array of Hashes, ready to merge into the
    # scalar-only `submitted` hash built in #commit.
    #
    # `image` is only ever an uploaded file (or absent) here: a row's `image`
    # param is either an UploadedFile (permit's scalar allowlist includes it)
    # or nothing, never a client-supplied string. #normalize_callout_list
    # resolves the actual stored URL — see its comment for why a plain string
    # is never trusted, same rationale as #process_image_uploads.
    #
    # Same `_submitted` sentinel gate as #process_list_fields: only a field
    # the widget actually rendered is processed, so an omitted field is left
    # untouched while a submitted-with-zero-rows field clears the list.
    def process_callout_list_fields(params)
      return {} if callout_list_keys.empty?

      permitted = params.permit(callout_list_keys.index_with { [:type, :title, :image] }).to_h
      callout_list_keys.each_with_object({}) do |k, result|
        next unless params.key?("#{k}_submitted")

        result[k] = normalize_callout_list(permitted[k], k)
      end
    end

    # Builds the ordered Array of {type, title, image} row Hashes from the
    # submitted rows for one :callout_list field.
    #
    # Drops rows with a blank type (a callout type needs a key to be looked up
    # by `[callout: <type>]`); a renamed type with no re-upload simply loses
    # its icon, which is an accepted trade-off. Type is folded to a lowercase
    # key to match DocTemplate::Tags::CalloutTag's marker parsing; title is
    # only stripped, since it's a display string. Dedupes by type, later row
    # wins (mirrors #normalize_list) — the image upload for a dropped/blank
    # row is simply never resolved (see the `next` below), so it's never
    # actually stored, even transiently.
    def normalize_callout_list(rows, list_key)
      existing_images = stored_callout_images(list_key)

      Array(rows).each_with_object({}) do |row, hash|
        type = row["type"].to_s.strip.downcase
        next if type.blank?

        hash.delete(type)
        hash[type] = {
          "type" => type,
          "title" => row["title"].to_s.strip,
          "image" => resolve_callout_image(row["image"], type, existing_images)
        }
      end.values
    end

    # The type => image URL map currently persisted for a :callout_list field
    # (the raw stored value, NOT the defaults-merged one — a shipped default
    # has no icon to fall back to anyway), used to keep a row's icon when its
    # submission carries no new upload.
    def stored_callout_images(list_key)
      Array(stored[list_key]).each_with_object({}) do |row, hash|
        type = row["type"].to_s.strip.downcase
        hash[type] = row["image"] if type.present?
      end
    end

    # An image field only ever accepts an uploaded file, exactly like
    # #process_image_uploads: a row's `image` sent as a plain string is never
    # persisted as a URL (arbitrary path/URL, later fed to image_tag/gdoc
    # inlining — path traversal / XSS risk). A row with no new upload instead
    # reuses whatever URL is already stored for that type, so an unrelated
    # edit (e.g. retitling) doesn't drop an existing icon — the client never
    # gets to supply that URL itself.
    def resolve_callout_image(file, type, existing_images)
      if file.respond_to?(:tempfile)
        # CalloutIconUploader, not ImageUploader: it downscales the source to
        # CalloutIconUploader::MAX_EDGE so an oversized upload cannot blow up
        # the admin row, the 24pt export icon, or the base64 payload the Gdoc
        # export inlines once per callout.
        uploader = CalloutIconUploader.new
        uploader.store!(file)
        uploader.url
      else
        existing_images[type]
      end
    end
  end
end
