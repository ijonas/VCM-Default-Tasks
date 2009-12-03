require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "logger"
require "rubygems"
require "mongo"

include Mongo

describe "Store Content in MongoDB" do
  before(:each) do
    @content_descriptor = ContentDescriptor.new("http://www.vamosa.com")
    @master_project = MasterProject.new("master project")
    @sub_project = SubProject.new("sub project", @master_project)
    @content_descriptor.outboundLinks << OutboundLink.new("http://www.vamosa.com/a.html")
    @content_descriptor.outboundLinks << OutboundLink.new("http://www.vamosa.com/b.html")
    @content_descriptor.outboundLinks << OutboundLink.new("http://www.vamosa.com/c.html")
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
    
    $logger = Logger.new(STDOUT)
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
      "http://www.vamosa.com/a.html",
      "http://www.vamosa.com/b.html",
      "http://www.vamosa.com/c.html",
    ]
  end
  it "should create sub documents of the metadata classes, properties, and values" do
    @task.serialised(@content_descriptor)['Identify Metadata'].should == {
      "Content-Type" => "text/html",
      "Content-Length" => "284732",
      "Status-Code" => "200",
    }
  end
  it "store content in mongodb" do
    Connection.should_receive(:new).and_return(@mongo_mock)
    @mongo_mock.should_receive(:insert)
    
    @task.enhance(@content_descriptor, nil, nil, nil)
  end
end