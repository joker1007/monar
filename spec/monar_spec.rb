require "prime"

RSpec.describe Monar do
  using Monar::Maybe::ToplevelSyntax

  describe Monar::Maybe do
    it "acts as monad" do
      calc = ->(val) do
        Just(val).monad do |x|
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

      expect(calc.call(3)).to eq(Just(17))
      expect(calc.call(6)).to eq(Just(20))
      expect(calc.call(2)).to eq(Nothing())
    end

    it "acts as applicative" do
      maybe_plus = Just(:+.to_proc)

      expect(maybe_plus.ap(Just(2), Just(4))).to eq(Just(6))
      expect(maybe_plus.ap(Just(2), Nothing())).to eq(Nothing())
    end

    it "can apply function having 3+ args" do
      maybe_calc = Just(->(a, b, c) { a * b + c })
      expect(maybe_calc.ap(Just(2), Just(4), Just(5))).to eq(Just(13))
      expect(maybe_calc.ap(Just(2), Nothing(), Just(5))).to eq(Nothing())
    end
  end

  using Monar::Either::ToplevelSyntax
  describe Monar::Either do
    it "acts as monad" do
      calc = ->(val) do
        Right(val).monad do |x|
          a = x.odd? ? x : x / 2
          y <<= pure(a + 14)
          z <<= rescue_all { y.prime? ? y : raise("not prime") }
        end
      end

      expect(calc.call(3)).to eq(Right(17))
      expect(calc.call(7).value).to be_a(RuntimeError)
    end

    it "acts as applicative" do
      either_plus = Right(:+.to_proc)

      expect(either_plus.ap(Right(2), Right(4))).to eq(Right(6))
      expect(either_plus.ap(Right(2), Left("hoge"))).to eq(Left("hoge"))
    end

    it "can apply function having 3+ args" do
      either_calc = Right(->(a, b, c) { a * b + c })

      expect(either_calc.ap(Right(2), Right(4), Right(5))).to eq(Right(13))
      expect(either_calc.ap(Right(2), Left("hoge"), Right(5))).to eq(Left("hoge"))
    end
  end
end
