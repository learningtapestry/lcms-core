# frozen_string_literal: true

module DocTemplate
  module Objects
    class LessonPrep < Base
      attribute :lesson_prep_time, :integer
      attribute :lesson_prep_directions, :string
    end
  end
end
