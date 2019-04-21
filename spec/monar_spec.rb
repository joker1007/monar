require "prime"

RSpec.describe Monar do
  using Monar::Maybe::ToplevelSyntax

  describe Monar::Maybe do
    it "acts as monad" do
      calc = ->(val) do
        Just(val).monadic_eval do |x, a, b, c = 1, *foo, n, m, d: nil, **opts|
          a = x; b = :hoge
          y <<= pure(a + 14)
          z <<= case y
                when :prime?.to_proc
                  Monar::Maybe.just(y)
                when 20
                  Monar::Maybe.just(y)
                else
                  Monar::Maybe.nothing
                end
          pure z
        end
      end

      expect(calc.call(3)).to eq(Just(17))
      expect(calc.call(6)).to eq(Just(20))
      expect(calc.call(2)).to eq(Nothing())
    end

    it "returns Nothing if exception is occured in monad" do
      calc = ->(val) do
        Just(val).monadic_eval do |x|
          a = x
          y <<= pure(a + 14)
          raise "error"
          z <<= case y
                when :prime?.to_proc
                  Monar::Maybe.just(y)
                when 20
                  Monar::Maybe.just(y)
                else
                  Monar::Maybe.nothing
                end
          pure z
        end
      end

      expect(calc.call(3)).to eq(Nothing())
    end

    it "acts as monad_plus (guard)" do
      calc = ->(val) do
        Just(val).monadic_eval do |x|
          a = x
          y <<= pure(a + 14)
          guard y == 17
          pure y
        end
      end

      expect(calc.call(3)).to eq(Just(17))
      expect(calc.call(4)).to eq(Nothing())
      expect(calc.call(2)).to eq(Nothing())
    end

    it "acts as monad_plus (mplus)" do
      expect(Just(2).mplus(Just(4))).to eq(Just(6))
      expect(Just(2).mplus(Nothing())).to eq(Nothing())
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
        Right(val).monadic_eval do |x|
          a = x.odd? ? x : x / 2
          y <<= pure(a + 14)
          rescue_all { y.prime? ? y : raise("not prime") }
        end
      end

      expect(calc.call(3)).to eq(Right(17))
      expect(calc.call(7).value).to be_a(RuntimeError)
    end

    it "returns Left(ex) if exception is occured in monad" do
      calc = ->(val) do
        Right(val).monadic_eval do |x|
          a = x.odd? ? x : x / 2
          y <<= pure(a + 14)
          raise "error"
          rescue_all { y.prime? ? y : raise("not prime") }
        end
      end

      result = calc.call(3)
      expect(result).to be_a(Monar::Either::Left)
      expect(result.value).to be_a(RuntimeError)
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
        val.monadic_eval do |x|
          a = x.odd? ? x : x / 2
          y <<= [a + 14]
          z <<= [y, y + 1, y + 2]
          pure z
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

      array_plus_3 = [->(a, b, c) { a + b + c }]
      expect(array_plus_3.ap([2, 3], [4, 8], [10, 20])).to eq([16, 26, 20, 30, 17, 27, 21, 31])
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
      rescue => ex
        if rejected?
          self
        else
          Concurrent::Promises.rejected_future(ex)
        end
      end

      private

      # def rescue_in_monad(ex)
        # Concurrent::Promises.rejected_future(ex)
      # end
    end

    it "acts as monad" do
      calc = ->(val) do
        val.monadic_eval do |x|
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
        val.monadic_eval do |x|
          a = x.odd? ?
            x :
            x / 2
          b = Concurrent::Promises.future { sleep 2; 11 }
          c = Concurrent::Promises.future { sleep 1; raise "failed" }
          d <<= b
          e <<= c
          y <<= pure(a + d + e)
          pure(y + 2)
        end
      end

      result = calc.call(Concurrent::Promises.make_future(5))
      expect(result.reason).to be_a(RuntimeError)
      expect(result.reason.message).to eq("failed")
    end

    it "returns rejected Future if exception is occured in monad" do
      calc = ->(val) do
        val.monadic_eval do |x|
          a = x.odd? ?
            x :
            x / 2
          b = Concurrent::Promises.future { sleep 2; 11 }
          raise "error"
          c = Concurrent::Promises.future { sleep 1; raise "failed" }
          d <<= b
          e <<= c
          y <<= pure(a + d + e)
          pure(y + 2)
        end
      end

      result = calc.call(Concurrent::Promises.make_future(5))
      expect(result.reason).to be_a(RuntimeError)
      expect(result.reason.message).to eq("error")
    end
  end

  describe Monar::State do
    it "acts as monad" do
      state = Monar::State.pure(5).monadic_eval do |n|
        status <<= get
        _ <<= if status != :saved
                result = n * 10
                put(:saved)
              else
                pure(nil)
              end
        pure(result)
      end

      val, st = state.run_state(:not_saved)
      expect(val).to eq(50)
      expect(st).to eq(:saved)

      val, st = state.run_state(:saved)
      expect(val).to eq(nil)
      expect(st).to eq(:saved)
    end
  end

  describe Monar::Parser do
    describe ".anychar" do
      it "return consumed char and remained string" do
        parser = Monar::Parser.anychar
        expect(parser.run_parser("foo")).to eq([["f", "oo"]])
      end

      it "combinatable" do
        parser = Monar::Parser.anychar.monadic_eval do |a|
          b <<= Monar::Parser.anychar
          pure([a, b])
        end
        expect(parser.run_parser("abc")).to eq([[["a", "b"], "c"]])
      end
    end

    describe ".satisfy" do
      it "return consumed char and remained string" do
        parser = Monar::Parser.satisfy(->(char) { char == "f" })
        expect(parser.run_parser("foo")).to eq([["f", "oo"]])
        expect(parser.run_parser("bar")).to eq([])
      end
    end

    describe ".char" do
      it "return consumed char and remained string" do
        parser = Monar::Parser.char("f")
        expect(parser.run_parser("foo")).to eq([["f", "oo"]])
        expect(parser.run_parser("bar")).to eq([])
      end

      it "combinate" do
        parser = Monar::Parser.char("f").monadic_eval do |c1|
          c2 <<= Monar::Parser.char("o")
          c3 <<= Monar::Parser.char("o")
          pure([c1, c2, c3])
        end
        expect(parser.run_parser("foo")).to eq([[["f", "o", "o"], ""]])
        expect(parser.run_parser("bar")).to eq([])
      end
    end

    describe ".string" do
      it "return consumed char and remained string" do
        parser = Monar::Parser.string("foo")
        expect(parser.run_parser("foo")).to eq([["foo", ""]])
      end

      it "combinate" do
        parser = Monar::Parser.string("foo").monadic_eval do |cs1|
          cs2 <<= Monar::Parser.string("bar")
          c <<= Monar::Parser.char("2")
          pure([cs1, cs2, c].join)
        end
        expect(parser.run_parser("foobar2")).to eq([["foobar2", ""]])
        expect(parser.run_parser("foobar")).to eq([])
      end
    end

    describe ".one_of" do
      it "return consumed char and remained string" do
        parser = Monar::Parser.one_of(%w(x y z))
        expect(parser.run_parser("abc")).to eq([])
        expect(parser.run_parser("xyz")).to eq([["x", "yz"]])
      end

      it "combinate" do
        parser = Monar::Parser.one_of(%w(x y z)).monadic_eval do |c1|
          c2 <<= Monar::Parser.one_of(%w(a y z))
          pure([c1, c2].join)
        end
        expect(parser.run_parser("ax")).to eq([])
        expect(parser.run_parser("xa")).to eq([["xa", ""]])
        expect(parser.run_parser("xy")).to eq([["xy", ""]])
      end
    end

    describe "#|" do
      it "combine with other parser" do
        parser1 = Monar::Parser.char("a")
        parser2 = Monar::Parser.char("z")
        combined = parser1 | parser2
        expect(combined.run_parser("abc")).to eq([["a", "bc"]])
      end

      it "combine with other parser and return multi candidates" do
        parser1 = Monar::Parser.char("a")
        parser2 = Monar::Parser.string("bcd")
        combined = parser1 | parser2
        expect(combined.run_parser("abc")).to eq([["a", "bc"]])
        expect(combined.run_parser("bcd")).to eq([["bcd", ""]])
      end

      it "combinate" do
        parser = Monar::Parser.one_of(%w(x y z)).monadic_eval do |c1|
          char_or_string <<= Monar::Parser.one_of(%w(b y z)) | Monar::Parser.string("arahabika")
          pure([c1, char_or_string].join)
        end
        expect(parser.run_parser("ax")).to eq([])
        expect(parser.run_parser("xb")).to eq([["xb", ""]])
        expect(parser.run_parser("xy")).to eq([["xy", ""]])
        expect(parser.run_parser("zarahabika")).to eq([["zarahabika", ""]])
      end
    end

    describe ".many" do
      it "can parse many sequence by a parser" do
        base_parser = Monar::Parser.char("a")
        parser = Monar::Parser.many(base_parser)
        expect(parser.run_parser("aaaab")).to eq([[["a", "a", "a", "a"], "b"]])
        expect(parser.run_parser("baaaab")).to eq([[[], "baaaab"]])
      end

      it "combinate" do
        base_parser = Monar::Parser.one_of(%w(1 2 3 4 5 6 7 8 9 0))
        parser = Monar::Parser.many(base_parser).monadic_eval do |digits|
          pure(digits.join.to_i)
        end

        expect(parser.run_parser("12345a")).to eq([[12345, "a"]])
      end
    end

    describe ".many1" do
      it "can parse many sequence by a parser" do
        base_parser = Monar::Parser.char("a")
        parser = Monar::Parser.many1(base_parser)
        expect(parser.run_parser("aaaab")).to eq([[["a", "a", "a", "a"], "b"]])
        expect(parser.run_parser("baaaab")).to eq([])
      end

      it "combinate" do
        base_parser = Monar::Parser.one_of(%w(1 2 3 4 5 6 7 8 9 0))
        parser = Monar::Parser.many1(base_parser).monadic_eval do |digits|
          pure(digits.join.to_i)
        end

        expect(parser.run_parser("12345a")).to eq([[12345, "a"]])
        expect(parser.run_parser("a12345")).to eq([])
      end
    end
  end
end
