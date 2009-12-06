require "java"

class Echo < com.vamosa.tasks.ParameterisedTask
  def usage()
    requiresContentDescriptor("contentDescriptor", "the default content descriptor")
    requiresContent("content", "the default content")
  end

  def enhance( contentDescriptor, content )
    $logger.info "Echoing: #{contentDescriptor}"
  end
end