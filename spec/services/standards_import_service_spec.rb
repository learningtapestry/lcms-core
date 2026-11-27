# frozen_string_literal: true

require "rails_helper"

describe StandardsImportService do
  let(:csv) do
    <<~CSV
      Identifier,Text,Subject,Grades,Alt Names,Visual Identifier,Heading
      RL.2.2,Recount stories.,ELA,"2; 3",ela.rl.2.2,RL 2.2,Practice Standards
      8.EE.1,Know and apply properties of exponents.,Mathematics,8,,,Content Standards
      ,,,,,
    CSV
  end

  before { allow(ImportService).to receive(:call).and_return(csv) }

  it "creates a standard per row, skipping blank rows" do
    expect(described_class.call("https://docs.google.com/spreadsheets/d/x")).to eq 2

    expect(Standard.find_by(name: "RL.2.2")).to have_attributes(
      description: "Recount stories.", subject: "ela", grades: %w(2 3), alt_names: %w(ela.rl.2.2), label: "RL 2.2",
      emphasis: nil, domain: nil
    )
    expect(Standard.find_by(name: "8.EE.1")).to have_attributes(subject: "math", grades: %w(8), alt_names: [])
  end

  it "updates a standard in place by subject and code, keeping its resource links" do
    standard = create(:standard, name: "rl.2.2", subject: "ela", description: "Old")
    link = create(:resource).resource_standards.create!(standard:)

    described_class.call("x")

    expect(standard.reload).to have_attributes(name: "RL.2.2", description: "Recount stories.")
    expect(ResourceStandard.exists?(link.id)).to be true
  end

  it "removes standards missing from the sheet, with their links" do
    gone = create(:standard, name: "W.2.1", subject: "ela")
    create(:resource).resource_standards.create!(standard: gone)

    described_class.call("x")

    expect(Standard.pluck(:name)).to contain_exactly("RL.2.2", "8.EE.1")
    expect(ResourceStandard.count).to eq 0
  end

  it "treats the same code in another subject as a different standard, and leaves other subjects alone" do
    other = create(:standard, name: "RL.2.2", subject: "science")
    create(:resource).resource_standards.create!(standard: other)

    described_class.call("x")

    expect(Standard.where(name: "RL.2.2").pluck(:subject)).to contain_exactly("ela", "science")
    expect(other.resource_standards.count).to eq 1
  end

  context "without the optional columns" do
    let(:csv) { "Code,Description\nRL.2.2,New text\n" }

    it "leaves those attributes as they were, matching by code alone" do
      standard = create(:standard, name: "rl.2.2", subject: "ela", grades: %w(2), label: "Reading")

      described_class.call("x")

      expect(standard.reload).to have_attributes(name: "RL.2.2", subject: "ela", description: "New text",
                                                 grades: %w(2), label: "Reading")
    end

    it "treats the sheet as covering every subject" do
      create(:standard, name: "8.EE.1", subject: "math")

      described_class.call("x")

      expect(Standard.pluck(:name)).to eq %w(RL.2.2)
    end
  end

  context "with an empty sheet" do
    let(:csv) { "Code,Description,Subject\n,,\n" }

    it "raises and keeps the current standards" do
      create(:standard, name: "K.1")

      expect { described_class.call("x") }
        .to raise_error(StandardsImportService::ImportError, "The standards sheet has no rows")
      expect(Standard.count).to eq 1
    end
  end

  it "links lessons to the standards they list once the sheet is in" do
    resource = create(:document, metadata: { "subject" => "math", "grade" => "2", "unit-id" => "u1",
                                             "section-number" => "1", "lesson-number" => "1",
                                             "standards" => "RL.2.2" }).resource

    described_class.call("x")

    expect(resource.reload.standards.pluck(:name)).to eq %w(RL.2.2)
  end

  it "runs the after-import hook" do
    allow(described_class).to receive(:after_reimport_hook)

    described_class.call("x")

    expect(described_class).to have_received(:after_reimport_hook)
  end

  context "with a code repeated in the same subject" do
    let(:csv) { "Code,Description,Subject\nRL.2.2,a,ela\nrl.2.2,b,ELA\n" }

    it "names both rows and changes nothing" do
      kept = create(:standard, name: "K.1", subject: "ela")

      expect { described_class.call("x") }
        .to raise_error(StandardsImportService::ImportError, /Row 3 \(rl\.2\.2\): Name repeats row 2/)
      expect(Standard.pluck(:id)).to eq [kept.id]
    end
  end

  context "without the required columns" do
    let(:csv) { "Subject,Grades\nela,2\n" }

    it "raises and keeps the current standards" do
      create(:standard, name: "K.1")

      expect { described_class.call("x") }
        .to raise_error(StandardsImportService::ImportError, "The standards sheet needs code and description columns")
      expect(Standard.count).to eq 1
    end
  end
end
