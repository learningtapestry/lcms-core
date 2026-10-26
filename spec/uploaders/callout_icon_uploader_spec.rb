# frozen_string_literal: true

require "rails_helper"

RSpec.describe CalloutIconUploader do
  # Exercises the real MiniMagick processing rather than stubbing it: the point
  # of this class is that an oversized upload comes back downscaled, and a stub
  # would assert nothing about that.
  let(:uploader) { described_class.new }
  let(:tmpdir) { Dir.mktmpdir }

  after do
    uploader.remove!
    FileUtils.remove_entry(tmpdir)
  end

  # ImageMagick 7 renamed `convert` to `magick`, keeping the old name only as a
  # deprecated alias, so resolve whichever this machine actually has instead of
  # pinning one. Both Dockerfile.dev and CI install ImageMagick 6 today; this
  # keeps the fixture working when that changes.
  IMAGEMAGICK_CLI = %w(magick convert).find do |bin|
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, bin)) }
  end

  def source(width, height)
    # Naming the real cause: "failed to build fixture" sent a CI run hunting a
    # broken uploader when ImageMagick was simply not installed on the runner.
    raise "ImageMagick is not installed (looked for `magick` and `convert`)" if IMAGEMAGICK_CLI.nil?

    path = File.join(tmpdir, "icon-#{width}x#{height}.png")
    # Shelling out to ImageMagick directly: mini_magick 5 reworked the
    # MiniMagick::Tool API, and generating the fixture is not what is under test.
    raise "failed to build fixture" unless system(IMAGEMAGICK_CLI, "-size", "#{width}x#{height}", "xc:orange", path)

    File.open(path)
  end

  def stored_dimensions
    image = MiniMagick::Image.open(uploader.file.path)
    [image.width, image.height]
  end

  it "downscales an oversized square icon to the max edge" do
    uploader.store!(source(1024, 1024))

    expect(stored_dimensions).to eq([described_class::MAX_EDGE, described_class::MAX_EDGE])
  end

  it "preserves aspect ratio for a non-square icon" do
    uploader.store!(source(1024, 512))

    width, height = stored_dimensions
    expect(width).to eq(described_class::MAX_EDGE)
    expect(height).to eq(described_class::MAX_EDGE / 2)
  end

  it "leaves an already-small icon untouched rather than upscaling it" do
    uploader.store!(source(48, 48))

    expect(stored_dimensions).to eq([48, 48])
  end

  it "inherits the parent's raster-only extension allowlist" do
    # SVG stays excluded (stored XSS via inline script) — see ImageUploader.
    expect(uploader.extension_allowlist).to match_array(%w(jpg jpeg png gif webp))
  end
end
