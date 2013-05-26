require File.expand_path('../../spec_helper', __FILE__)

describe 'stub.instance_of' do
  it "lets you stub instance methods of the given class" do
    klass = define_class
    stub.instance_of(klass) do |o|
      o.to_s { "High Level Spec" }
    end
    expect(klass.new.to_s).to eq "High Level Spec"
  end

  it "lets you stub methods called in #initialize" do
    klass = define_class
    method_run_in_initialize_stubbed = false
    stub.instance_of(klass) do |o|
      o.method_run_in_initialize { method_run_in_initialize_stubbed = true }
    end
    klass.new
    expect(method_run_in_initialize_stubbed).to be_true
  end

  it "doesn't override #initialize" do
    klass = define_class
    block_called = false
    stub.instance_of(klass) do |o|
      o.method_run_in_initialize
    end
    instance = klass.new(1, 2) { block_called = true }
    expect(instance.initialize_arguments).to eq [1, 2]
    expect(block_called).to be_true
  end

  def define_class
    Class.new do
      attr_reader :initialize_arguments

      def initialize(*args)
        @initialize_arguments = args
        yield if block_given?
        method_run_in_initialize
      end

      def method_run_in_initialize

      end
    end
  end
end
