# frozen_string_literal: true

%w(standard1 standard2 standard3).each do |standard|
  Standard.create(name: standard)
end
