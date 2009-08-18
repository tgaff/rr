module RR
  # RR::DoubleInjection is the binding of an subject and a method.
  # A double_injection has 0 to many Double objects. Each Double
  # has Argument Expectations and Times called Expectations.
  class DoubleInjection
    include Space::Reader

    LAZY_METHOD_DEFINITIONS = [
      (lambda do |subject|
        subject.respond_to?(:descends_from_active_record?) && subject.descends_from_active_record?
      end)
    ]

    MethodArguments = Struct.new(:arguments, :block)
    attr_reader :subject, :method_name, :doubles, :subject_class
    
    def initialize(subject, method_name, subject_class)
      @subject = subject
      @subject_class = subject_class
      @method_name = method_name.to_sym
      if object_has_method?(method_name)
        if LAZY_METHOD_DEFINITIONS.any? {|definition| definition.call(subject)} && !subject.methods.include?(method_name)
          subject.send(method_name)
        end
        subject_class.__send__(:alias_method, original_method_alias_name, method_name)
      end
      @doubles = []
    end

    # RR::DoubleInjection#register_double adds the passed in Double
    # into this DoubleInjection's list of Double objects.
    def register_double(double)
      @doubles << double
    end

    # RR::DoubleInjection#bind injects a method that acts as a dispatcher
    # that dispatches to the matching Double when the method
    # is called.
    def bind
      returns_method = <<-METHOD
        def #{@method_name}(*args, &block)
          arguments = MethodArguments.new(args, block)
          RR::Space.double_injection(self, :#{@method_name}).call_method(arguments.arguments, arguments.block)
        end
      METHOD
      subject_class.class_eval(returns_method, __FILE__, __LINE__ - 5)
      self
    end

    # RR::DoubleInjection#verify verifies each Double
    # TimesCalledExpectation are met.
    def verify
      @doubles.each do |double|
        double.verify
      end
    end

    # RR::DoubleInjection#reset removes the injected dispatcher method.
    # It binds the original method implementation on the subject
    # if one exists.
    def reset
      if object_has_original_method?
        subject_class.__send__(:alias_method, @method_name, original_method_alias_name)
        subject_class.__send__(:remove_method, original_method_alias_name)
      else
        subject_class.__send__(:remove_method, @method_name)
      end
    end

    def call_original_method(*args, &block)
      @subject.__send__(original_method_alias_name, *args, &block)
    end

    def object_has_original_method?
      object_has_method?(original_method_alias_name)
    end

    def call_method(args, block)
      space.record_call(subject, method_name, args, block)
      if double = find_double_to_attempt(args)
        double.call(self, *args, &block)
      else
        double_not_found_error(*args)
      end
    end
    
    protected
    def find_double_to_attempt(args)
      matches = DoubleMatches.new(@doubles).find_all_matches(args)

      unless matches.exact_terminal_doubles_to_attempt.empty?
        return matches.exact_terminal_doubles_to_attempt.first
      end

      unless matches.exact_non_terminal_doubles_to_attempt.empty?
        return matches.exact_non_terminal_doubles_to_attempt.last
      end

      unless matches.wildcard_terminal_doubles_to_attempt.empty?
        return matches.wildcard_terminal_doubles_to_attempt.first
      end

      unless matches.wildcard_non_terminal_doubles_to_attempt.empty?
        return matches.wildcard_non_terminal_doubles_to_attempt.last
      end

      unless matches.matching_doubles.empty?
        return matches.matching_doubles.first # This will raise a TimesCalledError
      end

      return nil
    end

    def double_not_found_error(*args)
      message =
        "On subject #{subject},\n" <<
        "unexpected method invocation:\n" <<
        "  #{Double.formatted_name(@method_name, args)}\n" <<
        "expected invocations:\n" <<
        Double.list_message_part(@doubles)
      raise Errors::DoubleNotFoundError, message
    end

    def original_method_alias_name
      "__rr__original_#{@method_name}"
    end

    def object_has_method?(method_name)
      @subject.methods.include?(method_name.to_s) || @subject.respond_to?(method_name)
    end
  end
end
