require File.expand_path('../../spec_helper', __FILE__)

describe 'stub' do
  # what if the method exists?
  # what if the method doesn't exist?
  # what if a block is given in order to define the return value of the method?
  # what if .returns is used to define the return value?
  # what if an argument expectation is defined?
  # what if an argument expectation is defined with .with?
  # what about ordered calls?
  # what if the subject being stubbed is a proxy object? (e.g. AR association objects)
  # what if you pass a block to #stub with a block arg?
  # what if you pass a block to #stub without a block arg?
  # what if the method being stubbed is an operator?
  # what if you mock a method with arguments and then stub it with no args?
  # what if you call .yields on a Double with no arguments?
  # what if you call .yields on a Double with arguments?
  # what if you chain .yields calls?
  # what if you try to call #flatten on a Double?

  # what if we are doing all of this with a class method instead of an instance method? (except the proxy one)

  context 'setting implementation' do
    it "without giving a block is the same as returning nil" do
      object = object_with_method(:some_method, 'value')
      stub(object).some_method
      expect(object.some_method).to eq nil
    end

    it "by giving a block works" do
      method_called = false
      object = object_with_method(:some_method, 'value')
      stub(object).some_method { method_called = true; 'bar' }
      expect(method_called).to eq true
      expect(object.some_method).to eq 'bar'
    end

    it "by using #returns works" do
      method_called = false
      object = object_with_method(:some_method) { 'value' }
      stub(object).some_method.returns { method_called = true; 'bar' }
      expect(method_called).to eq true
      expect(object.some_method).to eq 'bar'
    end
  end

  context 'stubbing invocations of specific argument sets' do
    context 'by passing arguments to the double definition directly' do
      it "defines the double just for that specific invocation" do
        object = object_with_method(:some_method) {|arg| 'value' }
        stub(object).some_method(1) { 'bar' }
        expect(object.some_method(1)).to eq 'bar'
      end

      it "raises an error if an unstubbed invocation occurs" do
        object = object_with_method(:some_method) {|arg| }
        stub(object).some_method(1)
        expect { object.some_method(2) }.to raise_error(RR::Errors::DoubleNotFoundError)
      end

      it "lets you define a catch-all double by omitting the argument set" do
        object = object_with_method(:some_method) {|arg| }
        stub(object).some_method(1)
        stub(object).some_method
        object.some_method(2)  # shouldn't raise an error
      end
    end

    context 'by using #with and arguments' do
      it "defines the double just for that specific invocation" do
        object = object_with_method(:some_method) {|arg| 'value' }
        stub(object).some_method.with(1) { 'bar' }
        expect(object.some_method(1)).to eq 'bar'
      end

      it "raises an error if an unstubbed invocation occurs" do
        object = object_with_method(:some_method) {|arg| }
        stub(object).some_method.with(1)
        expect { object.some_method(2) }.to raise_error(RR::Errors::DoubleNotFoundError)
      end

      it "lets you define a catch-all double by omitting the #with" do
        object = object_with_method(:some_method) {|arg| }
        stub(object).some_method.with(1)
        stub(object).some_method
        object.some_method(2)  # shouldn't raise an error
      end
    end
  end

  context 'block form' do
    it "allows multiple methods to be stubbed" do
      object = object_with_methods(
        :some_method => lambda { 'existing value 1' },
        :another_method => lambda { 'existing value 2' }
      )
      stub(object) do
        some_method { 'value 1' }
        another_method { 'value 2' }
      end
      expect(object.some_method).to eq 'value 1'
      expect(object.another_method).to eq 'value 2'
    end

    it "yields rather than using instance_eval if a block argument is given" do
      object = object_with_methods(
        :some_method => lambda { 'existing value 1' },
        :another_method => lambda { 'existing value 2' }
      )
      y = 0
      callable = lambda { y = 1 }
      stub(object) do |o|
        o.some_method { 'value 1' }
        o.another_method { 'value 2' }
        callable.call
      end
      expect(object.some_method).to eq 'value 1'
      expect(object.another_method).to eq 'value 2'
      expect(y).to eq 1
    end
  end

  it "lets you stub operator methods as well as normal ones" do
    object = Object.new
    stub(object).== { 'value' }
    expect(object == :whatever).to eq 'value'
  end

  context 'stubbing sequential invocations of a method' do
    it "works" do
      object = object_with_method(:some_method)
      stub(object).some_method { 'value 1' }.once.ordered
      stub(object).some_method { 'value 2' }.once.ordered
      expect(subject.some_method).to eq 'value 1'
      expect(subject.some_method).to eq 'value 2'
    end

    it "works when using #then instead of #ordered and chaining" do
      object = object_with_method(:some_method)
      stub(object).
        some_method { 'value 1' }.once.then.
        some_method { 'value 2' }.once
      expect(subject.some_method).to eq 'value 1'
      expect(subject.some_method).to eq 'value 2'
    end
  end

  # btakita/rr issue #24
  # this happens when defining a double on an ActiveRecord association object
  context 'when the object being stubbed is actually a proxy for another object' do
    it "places the stub on the proxy object and not the target object" do
      target_object = target_object_class.new
      proxy_object = proxy_object_class.new(target_object)
      #expect(proxy.methods).to match_array(proxy_target.methods)
      stub(proxy_object).some_method { 'value'}
      expect(proxy.some_object).to eq 'value'
    end

    def target_object_class
      Class.new do
        def some_method
          'existing value'
        end
      end
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
          @target.send(name, *args, &block)
        end
      end
    end
  end












  it "creates a stub DoubleInjection Double" do
    stub(subject).foobar {:baz}
    expect(subject.foobar("any", "thing")).to eq :baz
  end

  it "stubs via inline call" do
    stub(subject).to_s {"a value"}
    expect(subject.to_s).to eq "a value"
  end

  describe ".once.ordered" do
    it "returns the values in the ordered called" do
      stub(subject).to_s {"value 1"}.once.ordered
      stub(subject).to_s {"value 2"}.once.ordered

      expect(subject.to_s).to eq "value 1"
      expect(subject.to_s).to eq "value 2"
    end
  end

  context "when the subject is a proxy for the object with the defined method" do
    it "stubs the method on the proxy object" do
      proxy_target = Class.new {def foobar; :original_foobar; end}.new
      proxy = Class.new do
        def initialize(target)
          @target = target
        end

        instance_methods.each do |m|
          unless m =~ /^_/ || m.to_s == 'object_id' || m.to_s == 'method_missing'
            alias_method "__blank_slated_#{m}", m
            undef_method m
          end
        end

        def method_missing(method_name, *args, &block)
          @target.send(method_name, *args, &block)
        end
      end.new(proxy_target)
      expect(proxy.methods).to match_array(proxy_target.methods)

      stub(proxy).foobar {:new_foobar}
      expect(proxy.foobar).to eq :new_foobar
    end
  end

  it "stubs via block with argument" do
    stub subject do |d|
      d.to_s {"a value"}
      d.to_sym {:crazy}
    end
    expect(subject.to_s).to eq "a value"
    expect(subject.to_sym).to eq :crazy
  end

  it "stubs via block without argument" do
    stub subject do
      to_s {"a value"}
      to_sym {:crazy}
    end
    expect(subject.to_s).to eq "a value"
    expect(subject.to_sym).to eq :crazy
  end

  it "stubs methods without letters" do
    stub(subject).__send__(:==) {:equality}
    expect((subject == 55)).to eq :equality
  end

  context "mock then stub" do
    it "stubs any calls not matching the mock" do
      mock(subject).foobar(3) {:baz3}
      stub(subject).foobar {:baz}
      expect(subject.foobar(3)).to eq :baz3
      expect(subject.foobar(4)).to eq :baz
    end
  end

  context "stub that yields" do
    context "when yields called without any arguments" do
      it "yields only once" do
        called_from_block = mock!.some_method.once.subject
        block_caller = stub!.bar.yields.subject
        block_caller.bar { called_from_block.some_method }
      end
    end

    context "when yields called with an argument" do
      it "yields only once" do
        called_from_block = mock!.some_method(1).once.subject
        block_caller = stub!.bar.yields(1).subject
        block_caller.bar { |argument| called_from_block.some_method(argument) }
      end
    end

    context "when yields calls are chained" do
      it "yields several times" do
        pending "This test is failing with a TimesCalledError"

        called_from_block = mock!.some_method(1).once.then.some_method(2).once.subject
        block_caller = stub!.bar.yields(1).yields(2).subject
        block_caller.bar { |argument| called_from_block.some_method(argument) }
      end
    end
  end

  # bug #44
  describe 'when wrapped in an array that is then flattened' do
    context 'when the method being stubbed is not defined' do
      it "does not raise an error" do
        stub(subject).some_method
        expect([subject].flatten).to eq [subject]
      end

      it "honors a #to_ary that already exists" do
        subject.instance_eval do
          def to_ary; []; end
        end
        stub(subject).some_method
        expect([subject].flatten).to eq []
      end
    end

    context 'when the method being stubbed is defined' do
      before do
        subject.instance_eval do
          def some_method; end
        end
      end

      it "does not raise an error" do
        stub(subject).some_method
        expect([subject].flatten).to eq [subject]
      end

      it "honors a #to_ary that already exists" do
        eigen(subject).class_eval do
          def to_ary; []; end
        end
        stub(subject).some_method
        expect([subject].flatten).to eq []
      end
    end
  end

  def object_with_method(method_name, &implementation)
    implementation ||= lambda { }
    klass = Class.new do
      define_method(method_name, &implementation)
    end
    klass.new
  end
end
