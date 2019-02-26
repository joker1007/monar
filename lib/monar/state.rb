module Monar
  class State
    include Monad

    attr_reader :next_state

    class << self
      def pure(value)
        new(proc { |s| [value, s] })
      end

      def get
        new(proc { |s| [s, s] })
      end

      def put(st)
        new(proc { |_| [nil, st] })
      end
    end

    def initialize(next_state)
      raise ArgumentError.new("need to respond to :call") unless next_state.respond_to?(:call)
      @next_state = next_state
    end

    def fmap(&pr)
      self.class.new(
        proc do |s|
          x, s0 = run_state(s)
          pr.call(x)
          return [x, s0]
        end
      )
    end

    def flat_map(&pr0)
      self.class.new(
        proc do |s0|
          x, s1 = run_state(s0)
          pr1 = pr0.call(x)
          pr1.next_state.call(s1)
        end
      )
    end

    def run_state(s)
      @next_state.call(s)
    end
  end
end
