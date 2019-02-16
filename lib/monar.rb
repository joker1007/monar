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
    recursive_flat_map(targets)
  end

  def pure(value)
    self.class.pure(value)
  end

  private

  def recursive_flat_map(targets, *extracted)
    t = targets.shift
    if t
      t.flat_map do |v|
        return recursive_flat_map(targets, *extracted, v)
      end
    else
      pure(@value.call(*extracted))
    end
  end

  module ClassMethods
    def pure(value)
      new(value)
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
  end

  def monad(&block)
    block_location = block.source_location
    pr = Monad.proc_cache["#{block_location[0]}:#{block_location[1]}"]
    unless pr 
      source = File.readlines(block_location[0])
      ast = RubyVM::AbstractSyntaxTree.of(block); # SCOPE
      args_tbl = ast.children[0]
      block_arg = args_tbl[0]
      block_node = ast.children[2]
      block_node_stmts, block_node_last_stmt = block_node.children[0..-2], block_node.children[-1]
      end_count = 1
      buf = block_node_stmts.inject(["self.flat_map do |#{block_arg}|\n", end_count]) do |buf, stmt_node|
        if __flat_map_target?(stmt_node)
          lvar = stmt_node.children[0]
          rhv = stmt_node.children[1].children[2]
          buf[0].concat("(#{Monad.extract_source(source, rhv.first_lineno, rhv.first_column, rhv.last_lineno, rhv.last_column).chomp}).tap { |val| raise('type_mismatch') unless val.is_a?(monad_class) }.flat_map do |#{lvar}|\n")
          buf[1] += 1
        else
          buf[0].concat("(#{Monad.extract_source(source, stmt_node.first_lineno, stmt_node.first_column, stmt_node.last_lineno, stmt_node.last_column).chomp})\n")
        end
        buf
      end
      if __flat_map_target?(block_node_last_stmt)
        lvar = block_node_last_stmt.children[0]
        rhv = block_node_last_stmt.children[1].children[2]
        buf[0].concat("(#{Monad.extract_source(source, rhv.first_lineno, rhv.first_column, rhv.last_lineno, rhv.last_column).chomp}).tap { |val| raise('type_mismatch') unless val.is_a?(monad_class) }.flat_map do |#{lvar}|\npure(#{lvar})\nend\n")
      else
        buf[0].concat("(#{Monad.extract_source(source, block_node_last_stmt.first_lineno, block_node_last_stmt.first_column, block_node_last_stmt.last_lineno, block_node_last_stmt.last_column).chomp}).tap { |x| raise('type_mismatch') unless x.is_a?(monad_class) }\n")
      end
      buf[0].concat("end\n" * buf[1])
      gen = "proc do\n" + buf[0] + "end\n"
      puts gen
      pr = instance_eval(gen, block_location[0], block_location[1] - 1)
      Monad.proc_cache["#{block_location[0]}:#{block_location[1]}"] = pr
    end
    instance_eval(&pr)
  end

  private

  def monad_class
    self.class
  end

  def __flat_map_target?(node)
    (node.type == :DASGN || node.type == :DASGN_CURR) &&
      node.children[1].type == :CALL &&
      node.children[1].children[1] == :<<
  end
end
