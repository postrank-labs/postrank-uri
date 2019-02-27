nokogiri_versions = ["1.8", "1.9", "1.10"]

nokogiri_versions.each do |version|
  appraise "nokogiri-#{version}" do
    gem "nokogiri", "~> #{version}.0"
  end
end

appraise "addressable-2.3" do
  gem "addressable", "~> 2.3.0"
end

appraise "addressable-2.4" do
  gem "addressable", "~> 2.4.0"
end

appraise "addressable-2.5" do
  gem "addressable", "~> 2.5.0"
end
