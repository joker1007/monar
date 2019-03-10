module Monar
  class Parser
    include Monad

    # @param process [Proc (String -> [Object, String])]
    def initialize(process)
      @process = process
    end

    class << self
      def pure(value)
        new(proc { |string| [[value, string]] })
      end

      def mzero
        new(proc { |string| [] })
      end

      def anychar
        new(
          proc do |string|
            string == "" ? [] : [[string[0], string[1..-1]]]
          end
        )
      end

      # @param cond [Proc (Char -> TrueClass | FalseClass)]
      def satisfy(cond)
        anychar.flat_map do |char|
          if cond.call(char)
            pure(char)
          else
            mzero
          end
        end
      end

      def char(c)
        satisfy(->(char) { char == c })
      end

      def string(str)
        return pure "" if str == ""

        c, tail = str[0], str[1..-1]
        char(c).monad do |c1|
          cs <<= self.class.string(tail)
          pure [c1, *cs].join
        end
      end

      def one_of(chars)
        satisfy(->(char) { chars.include?(char) })
      end
    end

    def flat_map(&pr)
      self.class.new(
        proc do |str0|
          result0 = run_parser(str0)
          result0.flat_map do |consumed, remained|
            next_parser = pr.call(consumed)
            next_parser.run_parser(remained)
          end
        end
      )
    end

    def |(other)
      self.class.new(
        proc do |str|
          result0 = run_parser(str)
          result1 = other.run_parser(str)
          result0.empty? ? result1 : result0
        end
      )
    end

    def run_parser(string)
      @process.call(string)
    end
  end
end
