require "bundler/setup"
require "monar"
require "monar/parser"

class ArithmeticParser
  def digit
    Monar::Parser.one_of(%w(1 2 3 4 5 6 7 8 9 0))
  end

  def number
    Monar::Parser.many(digit).monad do |d|
      pure(d.join.to_i)
    end
  end

  def spaces
    space = Monar::Parser.char(" ")
    Monar::Parser.many(space)
  end

  def plus
    Monar::Parser.char("+").monad do |_|
      pure(->(a, b) { a + b })
    end
  end

  def minus
    Monar::Parser.char("-").monad do |_|
      pure(->(a, b) { a - b })
    end
  end

  def lparen
    Monar::Parser.char("(")
  end

  def rparen
    Monar::Parser.char(")")
  end

  def op_parser
    plus | minus
  end

  def chain_operator(prev = nil)
    _op_parser = op_parser
    _number = number
    _spaces = spaces
    _chain_operator = method(__method__)

    if prev
      _spaces.monad do |_|
        op <<= _op_parser
        _ <<= _spaces
        n2 <<= _number
        result <<= _chain_operator.call(op.call(prev, n2))
        pure(result)
      end | Monar::Parser.pure(prev)
    else
      number.monad do |n1|
        _ <<= _spaces
        op <<= _op_parser
        _ <<= _spaces
        n2 <<= _number
        result <<= _chain_operator.call(op.call(n1, n2))
        pure(result)
      end
    end
  end

  def get_parser
    chain_operator | number
  end
end

pp ArithmeticParser.new.get_parser.run_parser("12345 + 122 - 21000")

# expression = number.monad do |n|
  # _ <<= spaces
  # plus_op <<= plus
  # _ <<= spaces
# end

# expression_group = lparen.monad do |_|
  # _ <<= spaces
  # expression_result <<= expression
  # _ <<= spaces
  # _ <<= rparen
  # pure(expression_result)
# end

# _statement = expression_group | expression
# statement = Monar::Parser.many(_statement)


#p statement.run_parser("(12346 + 12345)")
#p statement.run_parser("(12346 + 12345) - 1234")
