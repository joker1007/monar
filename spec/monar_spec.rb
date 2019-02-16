require "prime"

RSpec.describe Monar do
  describe Monar::Maybe do
    it "acts as monad" do
      calc = ->(val) do
        Monar::Maybe.just(val).monad do |x|
          a = x
          y <<= pure(a + 14)
          z <<= case y
                when :prime?.to_proc
                  Monar::Maybe.just(y)
                when 20
                  Monar::Maybe.just(y)
                else
                  Monar::Maybe.nothing
                end
        end
      end

      expect(calc.call(3)).to eq(Monar::Maybe.just(17))
      expect(calc.call(6)).to eq(Monar::Maybe.just(20))
      expect(calc.call(2)).to eq(Monar::Maybe.nothing)
    end
  end
end
