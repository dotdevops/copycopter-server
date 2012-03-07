When /^I make the following revisions:$/ do |table|
  table.raw.each do |(key_with_locale, content)|
    locale_key, blurb_key = *key_with_locale.split_key_with_locale
    locale = Locale.find_by_key!(locale_key)
    blurb = Blurb.find_by_key!(blurb_key)
    localization = blurb.localizations.find_by_locale_id!(locale.id)
    localization.revise(:content => content, :published => false).save!
  end
end

Then /^no blank copy without a key should exist$/ do
  Blurb.where(:key => '').count.should == 0
end

Given /^the following copy exists:$/ do |table|
  table.hashes.each do |hash|
    project = Project.find_by_name!(hash['project'])
    draft_content = hash['draft content'] || ''
    published_content = hash['published content'] || ''
    locale = project.locales.find_or_create_by_key(hash['locale'] || 'en')
    blurb = project.blurbs.find_or_create_by_key(hash['key'] || Factory.next(:key))
    Factory :localization, :blurb => blurb, :locale => locale,
      :draft_content => draft_content, :published_content => published_content
  end
end

Given /^the following copy is published:$/ do |table|
  table.hashes.each do |hash|
    project = Project.find_by_name!(hash['project'])
    published_content = hash['content'] || ''
    locale = project.locales.find_or_create_by_key(hash['locale'] || 'en')
    blurb = project.blurbs.find_or_create_by_key(hash['key'] || Factory.next(:key))
    Factory(:localization, :blurb => blurb, :locale => locale,
      :draft_content => published_content).publish
  end
end

Then /^the following copy should exist in the "([^"]+)" project:$/ do |project_name, table|
  project = Project.find_by_name!(project_name)

  table.hashes.each do |copy_data|
    blurb = project.blurbs.find_by_key!(copy_data.delete('key'))
    locale = project.locales.find_by_key!(copy_data.delete('locale') || 'en')
    localization = blurb.localizations.find_by_locale_id!(locale.id)

    copy_data.each do |key, value|
      localization[key].should == value
    end
  end
end