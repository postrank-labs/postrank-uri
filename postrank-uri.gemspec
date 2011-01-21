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
  s.summary     = "URI normalization, c18n, escaping, and extraction"
  s.description = s.summary

  s.rubyforge_project = "postrank-uri"

  s.add_dependency "addressable", ">= 2.2.3"
  s.add_dependency "domainatrix"
  s.add_dependency "nokogiri"
  s.add_development_dependency "rspec"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
