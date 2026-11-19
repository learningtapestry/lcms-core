# frozen_string_literal: true

require "rails_helper"

describe DocTemplate::Tags::StandardTag do
  let(:original_content) do
    <<-HTML
      <ul class="lst-kix_nxend745gryj-0 start">
        <li class='preserved-cls'><span>Use words and phrases acquired through conversations, reading and being read to, and responding to the text </span><span>[</span><span>#{standard_name}</span><span>].</span></li>
        <li><span>Prior to listening to </span><span>The Fisherman and His Wife</span><span>, orally predict which character has magical powers and then compare the actual outcome to the prediction</span><span>.</span></li>
      </ul>
    HTML
  end
  let(:standard_name) { "L.2.6" }
  let(:tag) { described_class.new }
  let(:node) do
    html = Nokogiri::HTML original_content
    html.at_xpath("*//li") # it's the parent node of the one containing the tag itself
  end

  subject { tag.parse(node, {}).content }

  it "looks the standard up by its exact code, in the lesson's subject" do
    expect(Standard).to receive(:find_by_code).with(standard_name, subject: "ela").and_call_original
    tag.parse(node, metadata: { "subject" => "ela" })
  end

  it "shows the matching standard's description" do
    create(:standard, name: "L.2.6", description: "Use words and phrases.")
    create(:standard, name: "L.2.6a", description: "Wrong one.")

    expect(subject).to include("Use words and phrases.")
    expect(subject).not_to include("Wrong one.")
  end

  describe "tag names" do
    it "recognizes ELA, math and science codes" do
      %w(rl.2.4 ela.rl.2.4 8.ee.1 k.cc.1 hsa-ced.a.2 hs-ess2-3).each do |code|
        expect(code).to match(described_class::TAG_NAME)
      end
    end

    it "leaves other tags and plain numbers alone" do
      (DocTemplate::Template.tags.keys.grep(String) + %w(1.5 2-3)).each do |name|
        expect(name).not_to match(described_class::TAG_NAME)
      end
    end
  end

  it "renders corresponding template" do
    expect(ERB).to receive_message_chain(:new, :result).and_return("")
    subject
  end

  context "when node is a list" do
    subject { tag.parse(node, {}).render }

    it "preserves <li> markup with class" do
      expect(subject).to include '<li class="preserved-cls">'
      expect(subject).to include "</li>"
    end
  end
end
