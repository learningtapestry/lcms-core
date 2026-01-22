# frozen_string_literal: true

require "rails_helper"

require "lt/lcms/lesson/downloader/gdoc"

feature "Admin adds a material" do
  given(:sample_path) { "spec/features/admin/materials/sample-materials" }

  given(:downloaded_file) { Struct.new :last_modifying_user, :modified_time, :name, :version }

  given(:samples) do
    {
      gdoc: {
        file_name: "vocabulary-chart.html",
        url: "https://docs.google.com/document/d/1YTQxmi2rb405wx00xJY6NKD0VYQ5BhxLdSs4jR8o1a4/edit"
      }
    }
  end

  given(:user) { create :admin }

  background do
    login_as user
    allow_any_instance_of(MaterialForm).to receive(:google_credentials)
  end

  scenario "GDoc material" do
    data = samples[:gdoc]

    # stub GDoc download
    file_content = File.read File.join(sample_path, data[:file_name])
    base_klass = Lt::Lcms::Lesson::Downloader::Base
    gdoc_klass = Lt::Lcms::Lesson::Downloader::Gdoc
    allow_any_instance_of(base_klass).to receive(:file).and_return(downloaded_file.new(nil, nil, data[:file_name]))
    allow_any_instance_of(gdoc_klass).to receive_message_chain(:download, :content).and_return(file_content)

    visit new_admin_material_path
    expect(page).to have_field :material_form_link

    fill_in :material_form_link, with: data[:url]
    find("#material_form_async").uncheck
    click_button "Parse"

    expect(Material.last.name).to eql(data[:file_name])
  end
end
