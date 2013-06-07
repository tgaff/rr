require File.expand_path('../../spec_helper', __FILE__)

describe 'dont_allow' do
  after do
    RR.reset
  end

  def self.tests(&block)
    specify "TimesCalledError is raised as soon as the method is called" do
      object = build_object_with_possible_method(:some_method)
      dont_allow(object).some_method
      expect { object.some_method }.to raise_error(RR::Errors::TimesCalledError)
    end

    context 'with a times-called qualifier' do
      specify "it overrides the never, erroring if the number of invocations is under the expected amount" do
        object = build_object_with_possible_method(:some_method)
        dont_allow(object).some_method.times(3)
        object.some_method
        object.some_method
        expect { RR.verify }.to raise_error(RR::Errors::TimesCalledError)
      end

      specify "it overrides the never, erroring if the number of invocations exceeds the expected amount" do
        object = build_object_with_possible_method(:some_method)
        dont_allow(object).some_method.times(3)
        object.some_method
        object.some_method
        object.some_method
        expect { object.some_method }.to raise_error(RR::Errors::TimesCalledError)
      end
    end

    context 'with a never-called qualifier' do
      it "works as long as the method is never called" do
        object = build_object_with_possible_method(:some_method)
        dont_allow(object).some_method.never
      end

      specify "TimesCalledError is raised as soon as the method is called" do
        object = build_object_with_possible_method(:some_method)
        dont_allow(object).some_method.never
        expect { object.some_method }.to raise_error(RR::Errors::TimesCalledError)
      end
    end

    context 'mocking invocations of specific argument sets' do
      context 'by passing arguments to the double definition directly' do
        argument_expectation_tests do |mocked_object, method_name, *args|
          mocked_object.__send__(method_name, *args)
        end
      end

      context 'by using #with and arguments' do
        argument_expectation_tests do |mocked_object, method_name, *args|
          mocked_object.__send__(method_name).with(*args)
        end
      end
    end

    context 'block form' do
      it "allows multiple methods to be mocked" do
        object = build_object_with_possible_methods(
          :some_method => lambda { 'existing value 1' },
          :another_method => lambda { 'existing value 2' }
        )
        y = 0
        callable = lambda { y = 1 }
        dont_allow(object) do
          some_method
          another_method(2)
          yet_another_method
          callable.call
        end
        expect { object.some_method }.to raise_error(RR::Errors::TimesCalledError)
        expect { object.another_method(2) }.to raise_error(RR::Errors::TimesCalledError)
      end

      it "yields rather than using instance_eval if a block argument is given" do
        object = build_object_with_possible_methods(
          :some_method => lambda { 'existing value 1' },
          :another_method => lambda { 'existing value 2' }
        )
        y = 0
        callable = lambda { y = 1 }
        dont_allow(object) do |o|
          o.some_method
          o.another_method(2)
          o.yet_another_method
          callable.call
        end
        expect { object.some_method }.to raise_error(RR::Errors::TimesCalledError)
        expect { object.another_method(2) }.to raise_error(RR::Errors::TimesCalledError)
        expect(y).to eq 1
      end
    end

    # btakita/rr issue #24
    # this happens when defining a double on an ActiveRecord association object
    context 'when the object being mocked is actually a proxy for another object' do
      it "places the mock on the proxy object and not the target object by mistake" do
        target_object = build_object_with_possible_method(:some_method) { 'existing value' }
        proxy_object = proxy_object_class.new(target_object)
        expect(proxy_object.methods).to match_array(target_object.methods)
        dont_allow(proxy_object).some_method
        expect { proxy_object.some_method }.to raise_error(RR::Errors::TimesCalledError)
      end

      def proxy_object_class
        Class.new do
          # This matches what AssociationProxy was like as of Rails 2
          instance_methods.each do |m|
            undef_method m unless m.to_s =~ /^(?:nil\?|send|object_id|to_a)$|^__|^respond_to|proxy_/
          end

          def initialize(target)
            @target = target
          end

          def method_missing(name, *args, &block)
            if @target.respond_to?(name)
              @target.__send__(name, *args, &block)
            else
              super
            end
          end
        end
      end
    end

    # btakita/rr issue #44
    context 'when wrapped in an array that is then flattened' do
      it "does not raise an error" do
        object = build_object_with_possible_method(:some_method)
        dont_allow(object).some_method
        expect([object].flatten).to eq [object]
      end

      it "honors a #to_ary that already exists" do
        object = build_object_with_possible_method(:some_method)
        (class << object; self; end).class_eval do
          def to_ary; []; end
        end
        dont_allow(object).some_method
        expect([object].flatten).to eq []
      end
    end
  end

  def self.argument_expectation_tests(&add_argument_expectation)
    context 'with a times-called qualifier' do
      specify "it overrides the never, erroring if the number of invocations is under the expected amount" do
        object = build_object_with_possible_method(:some_method)
        add_argument_expectation.call(dont_allow(object), :some_method, 1).times(3)
        object.some_method(1)
        object.some_method(1)
        expect { RR.verify }.to raise_error(RR::Errors::TimesCalledError)
      end

      specify "it overrides the never, erroring if the number of invocations exceeds the expected amount" do
        object = build_object_with_possible_method(:some_method)
        add_argument_expectation.call(dont_allow(object), :some_method, 1).times(3)
        object.some_method(1)
        object.some_method(1)
        object.some_method(1)
        expect { object.some_method(1) }.to raise_error(RR::Errors::TimesCalledError)
      end
    end

    context 'with a never-called qualifier' do
      it "works as long as the invocation never occurs" do
        object = build_object_with_possible_method(:some_method)
        add_argument_expectation.call(dont_allow(object), :some_method, 1).never
      end

      it "works as long as the invocation never occurs even if other invocations occur" do
        object = build_object_with_possible_method(:some_method) {|arg| }
        stub(object).some_method
        add_argument_expectation.call(dont_allow(object), :some_method, 1).never
        object.some_method(2)
      end

      specify "TimesCalledError is raised as soon as the invocation occurs" do
        object = build_object_with_possible_method(:some_method)
        add_argument_expectation.call(dont_allow(object), :some_method, 1).never
        expect { object.some_method(1) }.to raise_error(RR::Errors::TimesCalledError)
      end
    end

    specify "no error is raised if the method is never called at all" do
      object = build_object_with_possible_method(:some_method)
      add_argument_expectation.call(dont_allow(object), :some_method, 1)
    end

    specify "a DoubleNotFoundError is raised if the method is called but not with the specified arguments" do
      object = build_object_with_possible_method(:some_method)
      add_argument_expectation.call(dont_allow(object), :some_method, 1)
      expect { object.some_method }.to raise_error(RR::Errors::DoubleNotFoundError)
    end

    specify "a TimesCalledError is raised the moment the method is called with the specified arguments" do
      object = build_object_with_possible_method(:some_method)
      add_argument_expectation.call(dont_allow(object), :some_method, 1)
      expect { object.some_method(1) }.to raise_error(RR::Errors::TimesCalledError)
    end

    # it "lets you define a catch-all double by definining a stub without arguments" do
    #   object = build_object_with_possible_method(:some_method) {|arg| }
    #   stub(object).some_method
    #   add_argument_expectation.call(dont_allow(object), :some_method, 1)
    #   object.some_method(1)
    #   object.some_method(2)  # shouldn't raise an error
    # end
  end

  def build_object_with_methods(*args, &block)
    if args[0].is_a?(Symbol)
      methods = { args[0] => (block || lambda {}) }
    else
      methods = args[0]
    end
    klass = Class.new do
      methods.each do |method_name, implementation|
        define_method(method_name, &implementation)
      end
    end
    klass.new
  end
  alias :build_object_with_method :build_object_with_methods

  def build_class_with_methods(*args, &block)
    if args[0].is_a?(Symbol)
      methods = { args[0] => (block || lambda {}) }
    else
      methods = args[0]
    end
    klass = Class.new
    (class << klass; self; end).class_eval do
      methods.each do |method_name, implementation|
        define_method(method_name, &implementation)
      end
    end
    klass
  end
  alias :build_class_with_method :build_class_with_methods

  context 'with a method that exists' do
    def build_object_with_possible_methods(*args)
      build_object_with_methods(*args)
    end
    alias :build_object_with_possible_method :build_object_with_possible_methods

    def build_class_with_possible_methods(*args)
      build_class_with_methods(*args)
    end
    alias :build_class_with_possible_method :build_class_with_possible_methods

    tests
  end

  context "with a method that doesn't exist" do
    def build_object_with_possible_methods(*args)
      Object.new
    end
    alias :build_object_with_possible_method :build_object_with_possible_methods

    def build_class_with_possible_methods(*args)
      Class.new
    end
    alias :build_class_with_possible_method :build_class_with_possible_methods

    tests
  end

  context 'on class methods' do
    it "works if the method already exists on the class" do
      klass = build_class_with_method(:some_method) { 'existing value' }
      dont_allow(klass).some_method
      expect { klass.some_method }.to raise_error(RR::Errors::TimesCalledError)
    end

    it "works if the method doesn't already exist on the class" do
      klass = Class.new
      dont_allow(klass).some_method
      expect { klass.some_method }.to raise_error(RR::Errors::TimesCalledError)
    end

    it "in a parent class doesn't affect child classes" do
      parent_class = build_class_with_method(:some_method) { 'existing value' }
      child_class = Class.new(parent_class)
      dont_allow(parent_class).some_method
      expect { parent_class.some_method }.to raise_error(RR::Errors::TimesCalledError)
      expect(child_class.some_method).to eq 'existing value'
    end
  end

  it "lets you mock operator methods as well as normal ones" do
    object = Object.new
    dont_allow(object).==
    expect { object == :whatever }.to raise_error(RR::Errors::TimesCalledError)
  end
end
