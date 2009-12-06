require "java"

module Vamosa
  include_package 'com.vamosa.content'
end

module Java
  include_package 'java.util'
end

class SampleSelector < com.vamosa.tasks.ParameterisedTask
  def usage()
    requiresProject("project", "the default to select content from")
  end

  def iterator(project)
    puts "iterator is called"
    @content_descriptors = Java::ArrayList.new
    @content_descriptors.add Vamosa::ContentDescriptor.new("http://www.vamosa.com/a.html", project)
    @content_descriptors.add Vamosa::ContentDescriptor.new("http://www.vamosa.com/b.html", project)
    @content_descriptors.add Vamosa::ContentDescriptor.new("http://www.vamosa.com/c.html", project)
    @content_descriptors.add Vamosa::ContentDescriptor.new("http://www.vamosa.com/d.html", project)
    @content_descriptors.add Vamosa::ContentDescriptor.new("http://www.vamosa.com/e.html", project)
    puts("@content_descriptors contains #{@content_descriptors}")
    @content_descriptors.iterator
  end
end