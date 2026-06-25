# frozen_string_literal: true

# Orchestrates a multi-group admin settings save. Each SETTINGS entry becomes a
# group object (FlatGroup or FormGroup) that knows how to apply, validate, reset
# and render itself, so neither the controller nor the view branches on the
# shape of the SETTINGS value. `save` applies every group inside one transaction
# and rolls back if any group is invalid, so a rejected submit never leaves a
# partial write.
class SettingsForm
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def groups
    @groups ||= SETTINGS.map { |key, schema| self.class.group_for_schema(key, schema) }
  end

  # Two-phase, all-or-nothing save. Every group stages its input (#prepare)
  # with no side effects; if anything is invalid we return without writing or
  # uploading anything — so a rejected submit leaves no partial write and no
  # orphaned upload. Only once the whole form validates do we #commit, wrapped
  # in a transaction for DB atomicity.
  def save
    groups.each { |group| group.prepare(params) }
    return false unless valid?

    ActiveRecord::Base.transaction do
      groups.each(&:commit)
    end
    true
  end

  def valid?
    groups.all?(&:valid?)
  end

  # The group that owns a settings key: a flat group whose schema contains the
  # leaf key, or a form group whose own key matches. Used to reset a single key.
  def self.group_for(key)
    SETTINGS.each do |group_key, schema|
      if schema == :form
        return group_for_schema(group_key, schema) if group_key.to_s == key.to_s
      elsif schema.key?(key.to_sym)
        return group_for_schema(group_key, schema)
      end
    end
    nil
  end

  def self.group_for_schema(key, schema)
    schema == :form ? FormGroup.new(key) : FlatGroup.new(key, schema)
  end
end
