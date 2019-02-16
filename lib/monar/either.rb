module Monar::Either
  module ToplevelSyntax
    refine Kernel do
      def Left(ex)
        Monar::Either.left(ex)
      end

      def Right(value)
        Monar::Either.right(value)
      end

      def either(&pr)
        Monar::Either.right(pr.call)
      rescue => ex
        Monar::Either.left.new(ex)
      end
    end
  end

  class << self
    def left(ex)
      Left.new(ex)
    end

    def right(value)
      Right.new(value)
    end
  end

  def value
    @value
  end

  def ==(other)
    other.is_a?(Monar::Either) && value == other.value
  end
  
  class Right
    include Monad
    include Monar::Either

    def initialize(value)
      @value = value
    end

    def fmap(&pr)
      self.pure(pr.call(@value))
    end

    def flat_map(&pr)
      pr.call(@value)
    end

    private

    def monad_class
      Monar::Either
    end

    def rescue_all(&pr)
      Right.new(pr.call)
    rescue => ex
      Left.new(ex)
    end
  end

  class Left
    include Monad
    include Monar::Either

    def initialize(ex)
      @value = ex
    end

    def fmap(&pr)
      self
    end

    def flat_map(&pr)
      self
    end

    private

    def monad_class
      Monar::Either
    end
  end
end
