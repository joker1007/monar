if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7.0")
  class RubyVM::AbstractSyntaxTree::Node
    def deconstruct
      [type, *children]
    end
  end
end
