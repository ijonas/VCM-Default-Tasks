require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "rubygems"
require "haml"
require "mongo"
require "mongo/gridfs"

include Mongo
include GridFS

module Vamosa
  include_package 'com.vamosa.tasks'
  include_package 'com.vamosa.projects'
  include_package 'com.vamosa.content'
end

describe "Store Content in MongoDB" do
  before(:each) do
    @master_project = Vamosa::MasterProject.new("master project", "some desc")
    @sub_project = Vamosa::SubProject.new("sub project", "some desc", @master_project)
    @content_descriptor = Vamosa::ContentDescriptor.new("http://www.vamosa.com", @master_project)
    @content_descriptor.addOutboundLink("http://www.vamosa.com/a.html")
    @content_descriptor.addOutboundLink("http://www.vamosa.com/b.html")
    @content_descriptor.addOutboundLink("http://www.vamosa.com/c.html")
    @content_descriptor.addContentData("sample data 1")
    @content_descriptor.addContentData("sample data 2")
    @content_descriptor.metadata = {
      "Identify Metadata.Content-Type" => "text/html",
      "Identify Metadata.Content-Length" => "284732",
      "Identify Metadata.Status-Code" => "200",
    }
    @content_descriptor.project = @master_project
    @task = StoreContentInMongoDB.new

    @mongo_mock = mock("mongo mock")
    @mongo_mock.stub!(:db).and_return(@mongo_mock)
    @mongo_mock.stub!(:collection).and_return(@mongo_mock)
    
    @gridfs_mock = mock("gridfs mock")
  end
  it "should serialise the url" do
    @task.serialised(@content_descriptor)['url'].should == 'http://www.vamosa.com'
  end
  it "should serialise a master project into a path" do
    @task.serialised(@content_descriptor)['project-path'].should == 'master project'
  end
  it "should serialise a sub project into a path" do
    @content_descriptor.project = @sub_project
    @task.serialised(@content_descriptor)['project-path'].should == 'master project/sub project'
  end
  it "should serialise the outbound links" do
    @task.serialised(@content_descriptor)['outbound-links'].should == [
      "http://www.vamosa.com/b.html",
      "http://www.vamosa.com/c.html",
      "http://www.vamosa.com/a.html",
    ]
  end
  it "should create sub documents of the metadata classes, properties, and values" do
    @task.serialised(@content_descriptor)['Identify Metadata'].should == {
      "Content-Type" => "text/html",
      "Content-Length" => "284732",
      "Status-Code" => "200",
    }
  end
  it "should store the content descriptior in mongodb and content in gridfs" do
    Connection.should_receive(:new).and_return(@mongo_mock)
    GridStore.should_receive(:open).twice.and_return(@gridfs_mock)
    @mongo_mock.should_receive(:insert)
    
    @task.enhance(@content_descriptor, nil, nil, nil)
  end
  
end