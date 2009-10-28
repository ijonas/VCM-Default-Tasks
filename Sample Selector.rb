require "java"

class SampleSelector < com.vamosa.tasks.ParameterisedTask
  def usage()
    requiresProject("project", "the default to select content from")
  end

  def iterator(project)
    puts "iterator is called"
    @content_descriptors = java.util.ArrayList.new
    @content_descriptors.add com.vamosa.content.ContentDescriptor.new("http://www.vamosa.com/a.html", project)
    @content_descriptors.add com.vamosa.content.ContentDescriptor.new("http://www.vamosa.com/b.html", project)
    @content_descriptors.add com.vamosa.content.ContentDescriptor.new("http://www.vamosa.com/c.html", project)
    @content_descriptors.add com.vamosa.content.ContentDescriptor.new("http://www.vamosa.com/d.html", project)
    @content_descriptors.add com.vamosa.content.ContentDescriptor.new("http://www.vamosa.com/e.html", project)
    puts("@content_descriptors contains #{@content_descriptors}")
    @content_descriptors.iterator
  end
end