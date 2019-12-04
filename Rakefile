require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec

require 'appraisal'

#---------------------------------------------------------------------------------------------------
# Monkey patch Bundler gem_helper so we release to our gem server instead of rubygems.org
module Bundler
  class GemHelper
    def rubygem_push(path)
      sh("gem push --verbose --host https://artifactory.elstc.co/artifactory/api/gems/swiftype-gems --key elastic '#{path}'")
      Bundler.ui.confirm "Pushed #{name} #{version} to artifactory"
    end
  end
end
