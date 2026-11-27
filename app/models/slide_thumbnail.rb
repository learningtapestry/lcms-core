# frozen_string_literal: true

# == Schema Information
#
# Table name: slide_thumbnails
#
#  id              :bigint           not null, primary key
#  file_url        :string           not null
#  slide_number    :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  page_object_id  :string           not null
#  presentation_id :string           not null
#  revision_id     :string           not null
#
# Indexes
#
#  index_slide_thumbnails_on_slide_revision  (presentation_id,slide_number,revision_id) UNIQUE
#
# A stored thumbnail of one slide of a Google Slides deck, at one revision of
# the deck (see SlideThumbnailService).
class SlideThumbnail < ApplicationRecord
  validates :presentation_id, :revision_id, :page_object_id, :file_url, presence: true
  validates :slide_number, numericality: { only_integer: true, greater_than: 0 }
end
