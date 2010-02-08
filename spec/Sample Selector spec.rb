require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module Java
  include_package 'java.util'
end

describe "Sample Selector" do
  it "should return an iterator" do
    SampleSelector.new.iterator(Vamosa::Project.new).should be_a_kind_of(Java::Iterator)
  end
end

describe "Sample Selector's iterator" do
  before(:each) do
    @selector = SampleSelector.new.iterator(Vamosa::Project.new)
  end
  it "should return a content descriptor if it has any" do
    @selector.hasNext.should be_true
    @selector.next.should_not be_nil
  end
  it "should return nil if there are no content descriptors" do
    @selector.hasNext.should be_true
    @selector.next
    @selector.next
    @selector.next
    @selector.next
    @selector.next
    @selector.hasNext.should be_false
    lambda{@selector.next}.should raise_error(NativeException)
   end
end