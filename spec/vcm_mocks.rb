
class ParameterisedTask
end

class OutboundLink
  attr_accessor :url
  def initialize(url)
    @url = url
  end
end

class ContentDescriptor
  attr_accessor :url, :metadata, :outboundLinks, :contents, :project
  def initialize(url)
    @url = url
    @metadata = {}
    @outboundLinks = []
    @contents = []
  end
end

class Project
  attr_accessor :name
  def initialize(name)
    @name = name
  end
  def Project.getProjectAsMasterProject(project)
    project.is_a?(MasterProject) ? project : nil      
  end
  def Project.getProjectAsSubProject(project)
    project.is_a?(SubProject) ? project : nil      
  end
end

class MasterProject < Project
  def initialize(name)
    super(name)
  end
end

class SubProject < Project
  attr_accessor :masterProject
  def initialize(name, master_project)
    super(name)
    @masterProject = master_project
  end
end
