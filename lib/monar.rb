require "monar/version"

module Functor
  def fmap(&pr)
    map(&pr)
  end
end

module Applicative
  def self.included(base)
    base.include(Functor)
    super
    base.extend(const_get(:ClassMethods))
  end

  def ap(*targets)
    curried = ->(*extracted) { fmap { |pr| pr.call(*extracted) } }.curry(targets.size)
    applied = targets.inject(pure(curried)) do |ppr, t|
      ppr.flat_map do |pr|
        t.fmap { |v| pr.call(v) }
      end
    end
    applied.flat_map(&:itself)
  end

  def pure(*value)
    self.class.pure(*value)
  end

  private

  module ClassMethods
    def pure(*value)
      new(*value)
    end
  end
end

module Monad
  def self.included(base)
    base.include(Functor)
    base.include(Applicative)
    super
  end

  class << self
    def extract_source(source, first_lineno, first_column, last_lineno, last_column)
      lines = source[(first_lineno - 1)..(last_lineno-1)]
      first_line = lines.shift
      last_line = lines.pop

      if last_line.nil?
        first_line[first_column..last_column]
      else
        first_line[first_column..-1] + lines.join + last_line[0..last_column]
      end
    end

    def proc_cache
      @proc_cache ||= {}
    end

    def caller_local_variables
      @caller_local_variables ||= {}
    end
  end

  def monad(&block)
    raise ArgumentError.new("No block given") unless block

    proc_binding = nil
    trace = TracePoint.new(:line) do |tp|
      proc_binding = tp.binding
      throw :escape
    end

    catch(:escape) do
      trace.enable(target: block)
      yield
    ensure
      trace.disable
    end

    block_location = block.source_location
    pr = Monad.proc_cache["#{block_location[0]}:#{block_location[1]}"]
    unless pr
      source = File.readlines(block_location[0])
      ast = RubyVM::AbstractSyntaxTree.of(block); # SCOPE
      args_tbl = ast.children[0]
      args_node = ast.children[1]
      caller_local_variables = proc_binding.local_variables - args_tbl
      Monad.caller_local_variables["#{block_location[0]}:#{block_location[1]}"] = caller_local_variables
      block_arg = args_tbl[0]
      block_node = ast.children[2]
      if block_node.type == :BLOCK
        block_node_stmts, block_node_last_stmt = block_node.children[0..-2], block_node.children[-1]
      else
        block_node_stmts = []; block_node_last_stmt = block_node
      end

      caller_location = caller_locations(1, 1)[0]
      end_count = 1
      initial_buf = [
        "self.flat_map #{"\\\n" * (ast.first_lineno - caller_location.lineno)} do |#{"\\\n" * (args_node.first_lineno - ast.first_lineno)}#{block_arg}#{"\\\n" * [(block_node.first_lineno - args_node.last_lineno - 1), 0].max}|\n",
        end_count,
        args_node.last_lineno
      ]

      buf = block_node_stmts.inject(initial_buf) do |buf, stmt_node|
        __transform_node(source, buf, stmt_node)
      end

      __transform_node(source, buf, block_node_last_stmt, last_stmt: true)

      buf[0].concat("end\n" * buf[1])
      gen = "proc { |#{caller_local_variables.map(&:to_s).join(",")}|  begin; " + buf[0] + "rescue => ex; rescue_in_monad(ex); end; }\n"
      puts gen
      pr = instance_eval(gen, caller_location.path, caller_location.lineno)
      Monad.proc_cache["#{block_location[0]}:#{block_location[1]}"] = pr
    end
    instance_exec(
      *(Monad.caller_local_variables["#{block_location[0]}:#{block_location[1]}"].map { |lvar| proc_binding.local_variable_get(lvar) }),
      &pr
    )
  end

  private

  def monad_class
    self.class
  end

  def __transform_node(source, buf, node, last_stmt: false)
    if buf[2] == node.first_lineno
      buf[0].chop!.concat("; ")
    end

    if __is_bind_statement?(node)
      lvar = node.children[0]
      rhv = node.children[1].children[2]
      if node.first_lineno < rhv.first_lineno
        buf[0].concat("#{"\n" * (rhv.first_lineno - node.first_lineno)}")
      end
      buf[0].concat("(#{Monad.extract_source(source, rhv.first_lineno, rhv.first_column, rhv.last_lineno, rhv.last_column).chomp}).tap { |val| raise('type_mismatch') unless val.is_a?(monad_class) }.flat_map do |#{lvar}|\n#{"pure(#{lvar})\n" if last_stmt}")
      buf[1] += 1
    elsif __is_guard_statement?(node)
      buf[0].concat("(#{Monad.extract_source(source, node.first_lineno, node.first_column, node.last_lineno, node.last_column).chomp}).tap { |val| raise('type_mismatch') unless val.is_a?(monad_class) }.flat_map do\n")
      buf[1] += 1
    else
      buf[0].concat("(#{Monad.extract_source(source, node.first_lineno, node.first_column, node.last_lineno, node.last_column).chomp})\n")
    end

    buf[2] = node.last_lineno
    buf
  end

  def __flat_map_target?(node)
    __is_bind_statement?(node) || __is_guard_statement?(node)
  end

  def __is_bind_statement?(node)
    (node.type == :DASGN || node.type == :DASGN_CURR) &&
      node.children[1].type == :CALL &&
      node.children[1].children[1] == :<<
  end

  def __is_guard_statement?(node)
    (node.type == :FCALL && node.children[0] == :guard) ||
      (node.type == :CALL && node.children[1] == :guard)
  end

  def rescue_in_monad(ex)
    raise ex
  end
end

module MonadPlus
  def mzero
    raise NotImplementedError
  end

  def mplus(other)
    raise NotImplementedError
  end

  def guard(bool)
    if bool
      self
    else
      mzero
    end
  end
end
