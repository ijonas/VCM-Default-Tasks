vcm_libs = "/Users/ijonas/code/vamosa/ContentMigrator/target/exploded/WEB-INF/lib"
vcm_libs_glob = "#{vcm_libs}/*.jar"
Dir["#{vcm_libs_glob}"].each do |jar| 
  require jar 
end

require "/Users/ijonas/code/vamosa/ContentMigrator/target/ContentMigrator-3.0.0.jar"
require File.expand_path(File.dirname(__FILE__) + '/../Store Content in MongoDB')
