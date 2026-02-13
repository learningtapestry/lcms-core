# frozen_string_literal: true

module ResourceHelpers
  def resources_sample_collection
    # Math G4 => 4 lessons
    4.times do |i|
      pos = i + 1
      dir = %W(math 4 1 1 #{pos})
      create(:resource,
             title: "Test Resource Math G4 L#{pos}",
             metadata: ::Resource.metadata_from_dir(dir))
    end

    # Math G7 => 7 lessons
    7.times do |i|
      pos = i + 1
      dir = %W(math 7 1 1 #{pos})
      create(:resource,
             title: "Test Resource Math G7 L#{pos}",
             metadata: ::Resource.metadata_from_dir(dir))
    end
  end

  def build_resources_chain(curr)
    dir = []
    parent = nil
    ::Resource.hierarchy.each_with_index do |type, idx|
      next unless curr[idx]

      dir.push curr[idx]
      res = create(:resource,
                   title: "Test Resource #{dir.join('|')}",
                   short_title: curr[idx],
                   curriculum_type: type,
                   parent:,
                   metadata: ::Resource.metadata_from_dir(dir))
      parent = res
    end
  end

  def build_or_return_resources_chain(curr)
    dir = []
    parent = nil
    ::Resource.hierarchy.each_with_index do |type, idx|
      next unless curr[idx]

      dir.push curr[idx]
      res = ::Resource.find_by(short_title: curr[idx]) ||
            FactoryBot.create(:resource,
                              title: "Test Resource #{dir.join('|')}",
                              short_title: curr[idx],
                              curriculum_type: type,
                              parent:,
                              metadata: ::Resource.metadata_from_dir(dir))
      parent = res
    end
    parent
  end
end

RSpec.configure do |config|
  config.include ResourceHelpers
end
