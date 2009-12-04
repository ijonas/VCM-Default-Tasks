require "java"
require "rubygems"
require "mongo"
require 'mongo/gridfs'
 
include Mongo
include GridFS

module Vamosa
  include_package 'com.vamosa.tasks'
  include_package 'com.vamosa.projects'
end

class StoreContentInMongoDB < com.vamosa.tasks.ParameterisedTask

  def usage()
    requiresContentDescriptor("contentDescriptor", "the default content descriptor")
    requiresContent("content", "the default content")
    requiresString("db_name", "the database to store the content in")
    requiresString("collection_name", "the collection within the db to store the content in")
  end

  def serialise_project_path(project)

    # try converting project -> master project (null if it fails)
    master_project = Vamosa::Project.getProjectAsMasterProject(project)

    # if masterProject is null then we're dealing with a subproject
    sub_project = Vamosa::Project.getProjectAsSubProject(project) if  master_project.nil?

    # if masterProject is still null, retrieve it via the sub project
    master_project ||= sub_project.masterProject

    # create the project path
    if sub_project.nil?
      master_project.name # just return the master project
    else
      "#{master_project.name}/#{sub_project.name}"
    end
  end

  def serialise_metadata(document, metadata)
    metadata.each do |key, value|
      if key =~ /(\A.*?)\.(.*)/
        properties = document[$1] || {}
        properties[$2] = value
        document[$1] = properties
      end
    end
  end

  def serialised(cd)
    doc = {'url' => cd.url, 'project-path' => serialise_project_path(cd.project), 'outbound-links' => [], 'contents' => [] }

    # store the outbound links
    doc_links = doc['outbound-links']
    cd.outboundLinks.each { |ol| doc_links << ol.url }

    # transfer the metadata in separate sub documents
    serialise_metadata(doc, cd.metadata)

    doc
  end

  def enhance( contentDescriptor, content, db_name, collection_name )
    $logger.info "Storing #{contentDescriptor.url}"
    @connection ||= Connection.new("localhost")
    db = @connection.db(db_name)
    
    # serialiase the content descriptor
    db.collection(collection_name).insert serialised(contentDescriptor)
    
    # store the related content
    contentDescriptor.content.each do |content|
      GridStore.open(db, "#{content.getId} #{contentDescriptor.url}", "w") do |f|
        f.puts content.contentData
      end
    end
    
  end
end
