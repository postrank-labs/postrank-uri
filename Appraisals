nokogiri_versions = ["1.8", "1.9", "1.10"]

nokogiri_versions.each do |version|
  appraise "nokogiri-#{version}" do
    gem "nokogiri", "~> #{version}.0"
  end
end

addressable_versions = ["2.4", "2.5", "2.6"]

addressable_versions.each do |version|
  appraise "addressable-#{version}" do
    gem "addressable", "~> #{version}.0"
  end
end
