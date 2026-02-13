# frozen_string_literal: true

seed_grades = %w(9 10 11 12)

Resource.subjects.each do |subject|
  seed_grades.each_with_index do |grade, index|
    grade_title = "G#{grade}"

    puts "----> #{subject.title}, grade: #{grade_title}"
    resource = subject.children.detect { it.short_title.to_s == grade }

    metadata = {
      subject: subject.short_title,
      grade:
    }.compact

    if resource
      resource.title = "#{subject.title} G#{grade}"
      resource.level_position = index
      resource.metadata = metadata
      resource.save!
    else
      subject.children.create!(
        short_title: grade,
        title: grade_title,
        level_position: index,
        curriculum: Curriculum.default,
        curriculum_type: 'grade',
        tree: true,
        metadata:
      )
    end
  end
end
