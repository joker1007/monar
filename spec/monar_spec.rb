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

    it "can be applied by Proc core_ext" do
      calc = ->(a, b, c) { a * b + c }

      expect(calc.apply_as(Monar::Either::Right, Right(2), Right(4), Right(5))).to eq(Right(13))
      expect(calc.apply_as(Monar::Either::Right, Right(2), Left("hoge"), Right(5))).to eq(Left("hoge"))
    end
  end

  describe Array do
    Array.include(Monad)
    def Array.pure(value)
      [value]
    end

    it "acts as monad" do
      calc = ->(*val) do
        val.monad do |x|
          a = x.odd? ? x : x / 2
          y <<= [a + 14]
          z <<= [y, y + 1, y + 2]
        end
      end

      expect(calc.call(1, 2, 3)).to eq([15, 16, 17, 15, 16, 17, 17, 18, 19])
      expect(calc.call(7, 8)).to eq([21, 22, 23, 18, 19, 20])
    end

    it "acts as applicative" do
      array_plus = [:+.to_proc]

      expect(array_plus.ap([2, 3], [4])).to eq([6, 7])
      expect(array_plus.ap([2, 3], [5, 6, 7])).to eq([7, 8, 9, 8, 9, 10])
      expect(array_plus.ap([2, 3], [])).to eq([])

      array_multi_calc = [:+.to_proc, :*.to_proc]

      expect(array_multi_calc.ap([2, 3], [4])).to eq([6, 8, 7, 12])
    end

    it "can apply function having 3+ args" do
      array_calc = [->(a, b, c) { a * b + c }]

      expect(array_calc.ap([2, 3], [4], [5, 6, 7])).to eq([13, 14, 15, 17, 18, 19])
      expect(array_calc.ap([2, 3], [], [5, 6, 7])).to eq([])
    end

    it "can be applied by Proc core_ext" do
      plus = :+.to_proc

      expect(plus.apply_as(Array, [2, 3], [4])).to eq([6, 7])
    end
  end

  require "concurrent-ruby"
  describe Concurrent::Promises::Future do
    Concurrent::Promises::Future.include(Monad)
    class Concurrent::Promises::Future
      class << self
        def pure(value)
          Concurrent::Promises.make_future(value)
        end
      end

      def flat_map(&pr)
        yield value!
      rescue
        self
      end
    end

    it "acts as monad" do
      calc = ->(val) do
        val.monad do |x|
          a = x.odd? ? x : x / 2
          b = Concurrent::Promises.future { sleep 2; 11 }
          c = Concurrent::Promises.future { sleep 1; 3 }
          d <<= b
          e <<= c
          y <<= pure(a + d + e)
          pure(y + 2)
        end
      end
      expect(calc.call(Concurrent::Promises.make_future(5)).value).to eq(21)
    end

    it "acts as monad (rejected)" do
      calc = ->(val) do
        val.monad do |x|
          a = x.odd? ? x : x / 2
          b = Concurrent::Promises.future { sleep 2; 11 }
          c = Concurrent::Promises.future { sleep 1; raise "failed" }
          d <<= b
          e <<= c
          y <<= pure(a + d + e)
          pure(y + 2)
        end
      end
      expect(calc.call(Concurrent::Promises.make_future(5)).reason).to be_a(RuntimeError)
    end
  end
end
