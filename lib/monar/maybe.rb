module Monar::Maybe
  module ToplevelSyntax
    refine Kernel do
      def Just(value)
        Monar::Maybe.just(value)
      end

      def Nothing
        Monar::Maybe.nothing
      end
    end
  end

  class << self
    def just(value)
      Just.new(value)
    end

    def nothing
      Nothing.new
    end
  end

  def value
    @value
  end

  def ==(other)
    other.is_a?(Monar::Maybe) && value == other.value
  end

  def mzero
    Nothing.new
  end

  def mplus(other)
    Just.new(:+.to_proc).ap(self, other)
  end

  private

  def rescue_in_monad(ex)
    Nothing.new
  end
  
  class Just
    include Monad
    include MonadPlus
    include Monar::Maybe

    def initialize(value)
      @value = value
    end

    def fmap(&pr)
      self.pure(pr.call(@value))
    end

    def flat_map(&pr)
      pr.call(@value)
    end

    def monad_class
      Monar::Maybe
    end
  end

  class Nothing
    include Monad
    include MonadPlus
    include Monar::Maybe

    def initialize(*value)
    end

    def fmap(&pr)
      self
    end

    def flat_map(&pr)
      self
    end

    def mzero
      self
    end

    def mplus(_)
      self
    end

    def monad_class
      Monar::Maybe
    end
  end
end
