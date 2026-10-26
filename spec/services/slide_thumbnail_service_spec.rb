# frozen_string_literal: true

require "rails_helper"

describe SlideThumbnailService do
  let(:deck_url) { "https://docs.google.com/presentation/d/deck123/edit#slide=id.p" }
  let(:slides) { instance_double(Google::Apis::SlidesV1::SlidesService) }
  let(:presentation) do
    Google::Apis::SlidesV1::Presentation.new(
      revision_id: "rev1",
      slides: %w(p1 p2 p3).map { Google::Apis::SlidesV1::Page.new(object_id_prop: it) }
    )
  end
  let(:png) { Rails.root.join("spec/fixtures/files/slide.png").binread }

  before do
    allow(Google::Apis::SlidesV1::SlidesService).to receive(:new).and_return(slides)
    allow(slides).to receive(:authorization=)
    allow(Lt::Google::Api::Auth::Cli).to receive(:new).and_return(double(credentials: :creds))
    allow(slides).to receive(:get_presentation).with("deck123", fields: "revisionId,slides.objectId").and_return(presentation)
    allow(slides).to receive(:get_presentation_page_thumbnail)
      .and_return(Google::Apis::SlidesV1::Thumbnail.new(content_url: "https://lh3.googleusercontent.com/x"))
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(png)
    allow(Net::HTTP).to receive(:get_response).with(URI("https://lh3.googleusercontent.com/x")).and_return(response)
  end

  # Test uploads are stored on disk under public/uploads.
  after { SlideThumbnail.pluck(:file_url).each { FileUtils.rm_f(Rails.public_path.join(it.delete_prefix("/"))) } }

  it "stores the slide's thumbnail and links to the slide" do
    result = described_class.call(deck_url, 3)

    expect(slides).to have_received(:get_presentation_page_thumbnail)
      .with("deck123", "p3", thumbnail_properties_mime_type: "PNG", thumbnail_properties_thumbnail_size: "LARGE")
    expect(result.slide_url).to eq "https://docs.google.com/presentation/d/deck123/edit#slide=id.p3"
    expect(result.image_url).to match(%r{/uploads/slides/\h+\.png\z})
    expect(SlideThumbnail.sole).to have_attributes(presentation_id: "deck123", slide_number: 3, revision_id: "rev1",
                                                   page_object_id: "p3", file_url: result.image_url)
  end

  it "reuses the stored thumbnail until the deck changes" do
    first = described_class.call(deck_url, 3)
    second = described_class.call(deck_url, 3)

    expect(second.image_url).to eq first.image_url
    expect(slides).to have_received(:get_presentation_page_thumbnail).once

    presentation.revision_id = "rev2"
    described_class.call(deck_url, 3)

    expect(slides).to have_received(:get_presentation_page_thumbnail).twice
  end

  it "fails for a slide the deck does not have" do
    expect { described_class.call(deck_url, 4) }.to raise_error(described_class::Error, /no slide 4/)
  end

  it "fails for a link that is not a Google Slides deck" do
    expect { described_class.call("https://www.nasa.gov/", 1) }.to raise_error(described_class::Error, /not a Google Slides link/)
  end

  it "reports a failed thumbnail download" do
    allow(Net::HTTP).to receive(:get_response).and_raise(SocketError, "getaddrinfo failed")

    expect { described_class.call(deck_url, 1) }.to raise_error(described_class::Error, /download failed \(SocketError/)
  end

  it "uses the thumbnail another parse stored first" do
    other = SlideThumbnail.new(presentation_id: "deck123", slide_number: 2, revision_id: "rev1",
                               page_object_id: "p2", file_url: "/uploads/slides/other.png")
    allow_any_instance_of(described_class).to receive(:store).and_return("/uploads/slides/lost.png")
    allow(SlideThumbnail).to receive(:create!) do
      other.save!
      raise ActiveRecord::RecordNotUnique
    end

    expect(described_class.call(deck_url, 2).image_url).to eq "/uploads/slides/other.png"
  end

  it "reports Google API errors" do
    allow(slides).to receive(:get_presentation).and_raise(Google::Apis::ClientError.new("notFound"))

    expect { described_class.call(deck_url, 1) }.to raise_error(described_class::Error, /Google Slides: notFound/)
  end
end
