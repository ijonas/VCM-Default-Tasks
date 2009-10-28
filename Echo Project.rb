require "java"

class SampleSelector < com.vamosa.tasks.ParameterisedTask
  def usage()
    requiresProject("project", "the default to select content from")
  end

  def enhance( project )
    $logger.info "You are currently executing against #{project.name}"
  end
end