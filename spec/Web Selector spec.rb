require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe WebSelector do
  
  before(:each) do
    # setup some mocks
    $projectManagerService = mock("projectManagerService", :findProjectResourceByNameAndProject => nil)
    @httpClient = mock("mocked http client")
    org.apache.http.impl.client.DefaultHttpClient.should_receive(:new).and_return(@httpClient)
    
    # setup some test data
    @page_metadata = {
      "Identify Metadata.Content-Type" => "text/html",
      "Identify Metadata.Status-Code" => "200",
    }
    @project = Vamosa::Project.new("Basic Website", "Project containing basic website.")
    @homepage = Vamosa::ContentDescriptor.new("http://basicwebsite.local/index.html", @project)
    @page1 = Vamosa::ContentDescriptor.new("http://basicwebsite.local/page1.html", @project)
    @page2 = Vamosa::ContentDescriptor.new("http://basicwebsite.local/page2.html", @project)
    @page3 = Vamosa::ContentDescriptor.new("http://basicwebsite.local/subfolder1/page3.html", @project)
    @page4 = Vamosa::ContentDescriptor.new("http://basicwebsite.local/subfolder1/subfolder2/page4.html", @project)
    @page5 = Vamosa::ContentDescriptor.new("http://basicwebsite.local/subfolder1/subfolder2/page5.html", @project)
    @project.contentDescriptors.each { |cd| cd.metadata.merge @page_metadata }
    @page5.metadata["Identify Metadata.Status Code" => "404"]
  end

  it "should return an iterator" do
    WebSelector.new.iterator(@project, "http://basicwebsite.local/", 100).should be_a_kind_of(Java::Iterator)
  end

  describe "when crawling the first page" do
    before(:each) do
      @selector = WebSelector.new
      @iterator = @selector.iterator(@project, "http://basicwebsite.local/", 100)
    end
    it "should start with a non-empty crawl queue" do
      @iterator.hasNext.should be_true
    end
    it "should return the first page in the crawl queue" do
      content = IO.read("support_files/basic_site/index.html")
      metadata = {"Content-Type"=>"text/html", "Status-Code" => "200"}
      links = (@project.contentDescriptors.map { |cd| cd.url })[1..-1] # tail
      @httpClient.should_receive(:execute).and_return([content, metadata, links])
      @iterator.next.should == @homepage
      @selector.next.should == @page1
    end
    it "should remove the first entry from the crawl queue" 
    it "should add new entries for pages 1-5" 
  end

  
end

