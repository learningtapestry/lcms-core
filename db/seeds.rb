# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

dir = File.expand_path('seeds', __dir__)

seeds = %w(
  authors.seeds.rb
  curriculums.seeds.rb
  subjects.seeds.rb
  development/users.seeds.rb
  development/grades.seeds.rb
  development/standards.seeds.rb
).freeze

seeds.map { |s| File.join dir, s }.each(&method(:load))
