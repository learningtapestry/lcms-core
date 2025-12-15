# frozen_string_literal: true

require 'rails_helper'

describe DocTemplate::Tables::Document do
  let(:table) { described_class.new }

  describe '#parse' do
    let(:html) { HtmlSanitizer.sanitize(data) }
    let(:fragment) { Nokogiri::HTML.fragment html }

    subject { table.parse fragment }

    shared_examples 'process metadata table' do
      include_examples 'removes metadata table'

      it { expect(subject.data['type']).to eq 'lesson' }
    end

    context 'regular header' do
      let(:data) { file_fixture('tables/document-metadata.html').read }

      include_examples 'process metadata table'
    end

    context 'header with spans' do
      let(:data) { file_fixture('tables/document-metadata-2spans.html').read }

      include_examples 'process metadata table'
    end

    context '2 paragraphs header with space' do
      let(:data) { file_fixture('tables/document-metadata-2paragpraphs.html').read }

      include_examples 'process metadata table'
    end
  end
end
