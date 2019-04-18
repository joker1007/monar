# Monar

This gem is implementation of Monad and Monad syntax in Ruby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'monar'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install monar

## Usage

**This usage is unstable. It may be changed.**

At first, Define `flat_map` in any object And include `Monad` module.

```ruby
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

  # If this monad may returns more than 2 kinds object
  # Please indicate parent class by `monad_class` method.
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
```

Use `monadic_eval`.

```ruby
Just.new(val).monadic_eval do |x|
  a = x
  y <<= pure(a + 14)
  raise "error"
  z <<= case y
        when :prime?.to_proc
          Just.new(y)
        when 20
          Just.new(y)
        else
          Nothing.new
        end
end
```

The block given for `monadic_eval` must return same `monad_class` object.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joker1007/monar.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
