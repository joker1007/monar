module Monar::Maybe
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
  
  class Just
    include Monad
    include Monar::Maybe

    def initialize(value)
      @value = value
    end

    def fmap(&pr)
      self.pure(pr.call(@value))
    end

    def ap(*targets)
      t = targets.shift
      if t
        curried = @value.curry

        new_applicative = t.fmap(&curried)
        new_applicative.applicative(*targets)
      else
        self
      end
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
    include Monar::Maybe

    def initialize(*value)
    end

    def fmap(&pr)
      self
    end

    def flat_map(&pr)
      self
    end

    def monad_class
      Monar::Maybe
    end
  end
end
