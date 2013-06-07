require File.expand_path('../../spec_helper', __FILE__)

# TODO: Make similar to stub.instance_of

describe 'strong.instance_of' do
  context "when using instance_of and the method does not exist" do
    it "raises an exception" do
      expect {
        strong.stub.instance_of(StrongSpecFixture).something
        StrongSpecFixture.new
      }.to raise_error(RR::Errors::SubjectDoesNotImplementMethodError)
    end
  end

  context "when using instance_of and the method does exist" do
    it "does not raise an exception" do
      strong.stub.instance_of(StrongSpecFixture).method_with_no_arguments
    end
  end
end
