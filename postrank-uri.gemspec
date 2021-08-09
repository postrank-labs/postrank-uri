# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "postrank-uri/version"

Gem::Specification.new do |s|
  s.name        = "postrank-uri"
  s.version     = PostRank::URI::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ilya Grigorik"]
  s.email       = ["ilya@igvita.com"]
  s.homepage    = "http://github.com/postrank-labs/postrank-uri"
  s.summary     = "URI normalization, c14n, escaping, and extraction"
  s.description = s.summary
  s.license     = 'MIT'
  s.required_ruby_version  = ">= 2.3.0"

  s.add_dependency "addressable",   ">= 2.4.0"
  s.add_dependency "public_suffix", ">= 4.0.0", "< 5"
  s.add_dependency "nokogiri",      ">= 1.8.0"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "appraisal", ">= 2.0.0", "< 3.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
