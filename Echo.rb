require "java"
require "rubygems"

class Echo < com.vamosa.tasks.ParameterisedTask
  def usage()
    requiresContentDescriptor("contentDescriptor", "the default content descriptor")
    requiresContent("content", "the default content")
  end

  def enhance( contentDescriptor, content )
    puts "Echoing: #{contentDescriptor}"
    $logger.info "Echoing: #{contentDescriptor}"
  end
end