require File.expand_path('../../spec_helper', __FILE__)

describe 'mock.strong' do
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

  context 'for a method that exists' do
    context 'comparing the arity between the method and double definition' do
      it "succeeds if both have no arity" do
        object = build_object_with_method(:some_method) { }
        mock.strong(object).some_method
        object.some_method
      end

      it "fails if the former has no arity and the latter does" do
        object = build_object_with_method(:some_method) { }
        expect { mock.strong(object).some_method(1) }.to \
          raise_error(RR::Errors::SubjectHasDifferentArityError)
        RR.reset
      end

      it "fails if the former has arity but the latter doesn't" do
        object = build_object_with_method(:some_method) {|arg| }
        expect { mock.strong(object).some_method }.to \
          raise_error(RR::Errors::SubjectHasDifferentArityError)
        RR.reset
      end

      it "succeeds if both have a finite number of arguments" do
        object = build_object_with_method(:some_method) {|arg| }
        mock.strong(object).some_method(1)
        RR.reset
      end

      it "succeeds if both have a variable number of arguments" do
        object = build_object_with_method(:some_method) {|*args| }
        mock.strong(object).some_method(1)
        mock.strong(object).some_method(1, 2)
        mock.strong(object).some_method(1, 2, 3)
        RR.reset
      end

      it "succeeds if both have finite and variable number of arguments" do
        object = build_object_with_method(:some_method) {|arg1, arg2, *rest| }
        mock.strong(object).some_method(1, 2)
        mock.strong(object).some_method(1, 2, 3)
        RR.reset
      end

      it "fails if the finite arguments are not matched before the variable arguments" do
        object = build_object_with_method(:some_method) {|arg1, arg2, *rest| }
        expect { mock.strong(object).some_method(1) }.to \
          raise_error(RR::Errors::SubjectHasDifferentArityError)
        RR.reset
      end
    end

    specify "TimesCalledError is raised at the verify step if the method is never called" do
      object = build_object_with_method(:some_method)
      mock.strong(object).some_method
      expect { RR.verify }.to raise_error(RR::Errors::TimesCalledError)
    end

    context 'with a times-called qualifier' do
      specify "TimesCalledError is raised at the verify step if the method is called too few times" do
        object = build_object_with_method(:some_method)
        mock.strong(object).some_method.times(3)
        object.some_method
        object.some_method
        expect { RR.verify }.to raise_error(RR::Errors::TimesCalledError)
      end

      specify "TimesCalledError is raised as soon as the method is called one too many times" do
        object = build_object_with_method(:some_method)
        mock.strong(object).some_method.times(3)
        object.some_method
        object.some_method
        object.some_method
        expect { object.some_method }.to raise_error(RR::Errors::TimesCalledError)
        RR.reset
      end
    end

    context 'with a never-called qualifier' do
      it "works as long as the method is never called" do
        object = build_object_with_method(:some_method)
        mock.strong(object).some_method.never
      end

      specify "TimesCalledError is raised as soon as the method is called" do
        object = build_object_with_method(:some_method)
        mock.strong(object).some_method.never
        expect { object.some_method }.to raise_error(RR::Errors::TimesCalledError)
        RR.reset
      end
    end

    context 'setting implementation' do
      it "without giving a block is the same as returning nil" do
        object = build_object_with_method(:some_method) { 'value' }
        mock.strong(object).some_method
        expect(object.some_method).to eq nil
      end

      it "by giving a block works" do
        method_called = false
        object = build_object_with_method(:some_method) { 'value' }
        mock.strong(object).some_method { method_called = true; 'bar' }
        expect(object.some_method).to eq 'bar'
        expect(method_called).to eq true
      end

      it "by using #returns works" do
        method_called = false
        object = build_object_with_method(:some_method) { 'value' }
        mock.strong(object).some_method.returns { method_called = true; 'bar' }
        expect(object.some_method).to eq 'bar'
        expect(method_called).to eq true
      end
    end

    context 'mocking invocations of specific argument sets' do
      context 'by passing arguments to the double definition directly' do
        it "defines the double just for that specific invocation" do
          object = build_object_with_method(:some_method) {|arg| 'value' }
          mock.strong(object).some_method(1).returns { 'bar' }
          expect(object.some_method(1)).to eq 'bar'
        end

        specify "DoubleNotFoundError is raised the moment the method is called but not with the specified arguments" do
          object = build_object_with_method(:some_method) {|arg| }
          mock.strong(object).some_method(1)
          expect { object.some_method }.to raise_error(RR::Errors::DoubleNotFoundError)
          RR.reset
        end

        it "lets you define a catch-all double by definining a stub without arguments" do
          object = build_object_with_method(:some_method) {|arg| }
          stub(object).some_method
          mock.strong(object).some_method(1)
          object.some_method(1)
          object.some_method(2)  # shouldn't raise an error
        end
      end

      context 'by using #with and arguments' do
        it "doesn't work (although it probably should)" do
          object = build_object_with_method(:some_method) {|arg| 'value' }
          expect { mock.strong(object).some_method.with(1) }.to \
            raise_error(RR::Errors::SubjectHasDifferentArityError)
        end
      end
    end

    context '#yields' do
      context 'without arguments' do
        it "inserts a yield that passes no arguments" do
          object = build_object_with_method(:some_method)
          mock.strong(object).some_method.yields
          x = 0
          object.some_method { x = 1 }
          expect(x).to eq 1
        end

        it "does not affect setting the implementation otherwise" do
          object = build_object_with_method(:some_method) { 'existing value' }
          mock.strong(object).some_method { 'value' }.yields
          expect(object.some_method { }).to eq 'value'
        end

        it "also lets you set the implementation in preference to #returns" do
          object = build_object_with_method(:some_method) { 'existing value' }
          mock.strong(object).some_method.yields { 'value' }
          expect(object.some_method { }).to eq 'value'
        end
      end

      context 'with arguments' do
        it "inserts a yield that passes those arguments" do
          object = build_object_with_method(:some_method)
          mock.strong(object).some_method.yields(1)
          x = 0
          object.some_method {|a| x = a }
          expect(x).to eq 1
        end

        it "does not affect setting the implementation otherwise" do
          object = build_object_with_method(:some_method) { 'existing value' }
          mock.strong(object).some_method { 'value' }.yields(1)
          expect(object.some_method { }).to eq 'value'
        end

        it "also lets you set the implementation in preference to #returns" do
          object = build_object_with_method(:some_method) { 'existing value' }
          mock.strong(object).some_method.yields(1) { 'value' }
          expect(object.some_method { }).to eq 'value'
        end
      end
    end

    context 'block form' do
      it "allows multiple methods to be mocked" do
        object = build_object_with_methods(
          :some_method => lambda { 'existing value 1' },
          :another_method => lambda { 'existing value 2' }
        )
        mock.strong(object) do
          some_method { 'value 1' }
          another_method { 'value 2' }
        end
        expect(object.some_method).to eq 'value 1'
        expect(object.another_method).to eq 'value 2'
      end

      it "yields rather than using instance_eval if a block argument is given" do
        object = build_object_with_methods(
          :some_method => lambda { 'existing value 1' },
          :another_method => lambda { 'existing value 2' }
        )
        y = 0
        callable = lambda { y = 1 }
        mock.strong(object) do |o|
          o.some_method { 'value 1' }
          o.another_method { 'value 2' }
          callable.call
        end
        expect(object.some_method).to eq 'value 1'
        expect(object.another_method).to eq 'value 2'
        expect(y).to eq 1
      end
    end

    context 'mocking sequential invocations of a method' do
      it "works" do
        object = build_object_with_method(:some_method)
        mock.strong(object).some_method { 'value 1' }.twice.ordered
        mock.strong(object).some_method { 'value 2' }.once.ordered
        expect(object.some_method).to eq 'value 1'
        expect(object.some_method).to eq 'value 1'
        expect(object.some_method).to eq 'value 2'
      end

      it "works when using #then instead of #ordered" do
        object = build_object_with_method(:some_method)
        mock.strong(object).
          some_method { 'value 1' }.once.then.
          some_method { 'value 2' }.once
        expect(object.some_method).to eq 'value 1'
        expect(object.some_method).to eq 'value 2'
      end
    end

    # btakita/rr issue #24
    # this happens when defining a double on an ActiveRecord association object
    context 'when the object being mocked is actually a proxy for another object' do
      it "doesn't work" do
        target_object = build_object_with_method(:some_method) { 'existing value' }
        proxy_object = proxy_object_class.new(target_object)
        expect(proxy_object.methods).to match_array(target_object.methods)
        expect { mock.strong(proxy_object).some_method }.to raise_error(RR::Errors::SubjectDoesNotImplementMethodError)
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
        object = build_object_with_method(:some_method)
        mock.strong(object).some_method
        object.some_method
        expect([object].flatten).to eq [object]
      end

      it "honors a #to_ary that already exists" do
        object = build_object_with_method(:some_method)
        (class << object; self; end).class_eval do
          def to_ary; []; end
        end
        mock.strong(object).some_method
        object.some_method
        expect([object].flatten).to eq []
      end
    end
  end

  context "with a method that doesn't exist" do
    it "doesn't work" do
      object = Object.new
      expect { mock.strong(object).some_method }.to \
        raise_error(RR::Errors::SubjectDoesNotImplementMethodError)
    end
  end

  context 'on class methods' do
    it "works if the method already exists on the class" do
      klass = build_class_with_method(:some_method) { 'existing value' }
      mock.strong(klass).some_method { 'value' }
      expect(klass.some_method).to eq 'value'
    end

    it "doesn't work if the method doesn't already exist on the class" do
      klass = Class.new
      expect { mock.strong(klass).some_method }.to \
        raise_error(RR::Errors::SubjectDoesNotImplementMethodError)
    end

    it "in a parent class doesn't affect child classes" do
      parent_class = build_class_with_method(:some_method) { 'existing value' }
      child_class = Class.new(parent_class)
      mock.strong(parent_class).some_method { 'value' }
      parent_class.some_method
      expect(child_class.some_method).to eq 'existing value'
    end
  end

  it "lets you stub operator methods as well as normal ones" do
    object = Object.new
    mock.strong(object).==(anything) { 'value' }
    expect(object == :whatever).to eq 'value'
  end
end
