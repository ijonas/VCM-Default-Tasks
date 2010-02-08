require "logger"

# load the Vamosa Content Migrator 3.0 3rd party libraries
vcm_libs = "/Users/ijonas/code/vamosa/ContentMigrator/target/exploded/WEB-INF/lib"
vcm_libs_glob = "#{vcm_libs}/*.jar"
Dir["#{vcm_libs_glob}"].each do |jar| 
  require jar 
end

# load the Vamosa Content Migrator 3.0 code library
require "/Users/ijonas/code/vamosa/ContentMigrator/target/ContentMigrator-3.0.0.jar"


# Setup some basic shortcuts to commonly used Java code
module Vamosa
  include_package 'com.vamosa.content'
  include_package 'com.vamosa.projects'
end
module Java
  include_package 'java.util'
end

# load the *.rb source files from the parent folder
Dir["#{File.expand_path(File.dirname(__FILE__) + '/..')}/*.rb"].each do |ruby_file| 
  require ruby_file 
end

# All logger output prints to the console
$logger = Logger.new(STDOUT)


