# frozen_string_literal: true

namespace :db do # rubocop:disable Metrics/BlockLength
  desc "Backs up the database."
  task backup: [:environment] do
    config = ActiveRecord::Base.connection_db_config.configuration_hash

    backup_folder = File.join(Dir.home, "database_backups", Time.now.strftime("%Y_%m_%d"))
    backup_name = "lcms_core_#{Time.now.to_i}.dump"
    backup_path = File.join(backup_folder, backup_name)

    FileUtils.mkdir_p(backup_folder)

    backup_cmd = [
      "PGPASSWORD=#{config[:password]}",
      "pg_dump",
      "--port=#{config[:port]}",
      "--host=#{config[:host] || 'localhost'}",
      "--username=#{config[:username]}",
      "--no-owner",
      "--no-acl",
      "--format=c",
      "-n public",
      "-d #{config[:database]}",
      "> #{backup_path}"
    ].join(" ")

    puts "Backing up #{Rails.env} database."

    raise "pg_dump failed" unless system(backup_cmd)
    raise "Backup is empty" if !File.exist?(backup_path) || File.size(backup_path).zero?

    puts "-> Backup created in #{backup_path} (#{File.size(backup_path)} bytes)."
  end

  desc "Dumps the database. Will create a dump file in db/dump/content.dump or a custom path."
  task :dump, [:dump_path] => [:environment] do |_t, args|
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    dump_path = args[:dump_path] || "#{Rails.root}/db/dump/content.dump"

    dump_cmd = [
      "PGPASSWORD=#{config[:password]}",
      "pg_dump",
      "--port=#{config[:port]}",
      "--host=#{config[:host]}",
      "--username=#{config[:username]}",
      "--clean",
      "--no-owner",
      "--no-acl",
      "--format=c",
      "-n public",
      "-d #{config[:database]}",
      "> #{dump_path}"
    ].join(" ")

    puts "Dumping #{Rails.env} database to #{dump_path}."

    raise "pg_dump failed" unless system(dump_cmd)
    raise "Dump is empty" if !File.exist?(dump_path) || File.size(dump_path).zero?

    puts "-> Dump created at #{dump_path} (#{File.size(dump_path)} bytes)."
  end

  desc "Runs pg_restore. Requires a dump file in db/dump/content.dump or a custom path."
  task :pg_restore, [:dump_path] => [:environment] do |_t, args|
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    dump_path = args[:dump_path] || "#{Rails.root}/db/dump/content.dump"

    restore_cmd = <<-BASH
      PGPASSWORD=#{config[:password]} \
      pg_restore \
        --port=#{config[:port]} \
        --host=#{config[:host]} \
        --username=#{config[:username]} \
        --no-owner \
        --no-acl \
        -n public \
        --dbname=#{config[:database]} #{dump_path}
    BASH

    puts "Restoring #{Rails.env} database from #{dump_path}."

    raise unless system(restore_cmd)
  end

  desc "Drops, creates and restores the database from a dump."
  task restore: %i(drop create environment pg_restore)
end
