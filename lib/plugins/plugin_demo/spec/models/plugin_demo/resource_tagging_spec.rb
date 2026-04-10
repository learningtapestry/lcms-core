# frozen_string_literal: true

require "rails_helper"

describe "Resource tagging via PluginDemo" do
  let(:resource) { create(:resource) }

  it "adds tag_list to Resource" do
    expect(resource).to respond_to(:tag_list)
  end

  it "allows tagging a resource" do
    resource.tag_list.add("math", "science")
    resource.save!

    expect(resource.reload.tag_list).to contain_exactly("math", "science")
  end

  it "finds resources by tag" do
    resource.tag_list.add("algebra")
    resource.save!

    expect(Resource.tagged_with("algebra")).to include(resource)
  end
end
