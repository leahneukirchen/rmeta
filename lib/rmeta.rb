class RMeta
  def self.load(file)
    parse(File.read(file))
  end

  def self.parse(string)
    require 'rmeta.grammar'
    code = RMeta::Grammar.parse(string).to_code
    Object.module_eval code
  end

  class CharStream < String
    def head
      return nil  if empty?
      self[0..0]
    end
    
    def tail
      CharStream.new(self[1..-1].to_s)
    end
  end
  
  class ParseError < RuntimeError; end
  
  class Parser
    def self.parse(obj)
      case obj
      when String
        new(CharStream.new(obj)).main
      else
        new(obj).main
      end
    end
    
    def initialize(stream)
      @stream = stream
    end
    
    def _anything
      v = @stream.head || raise(ParseError)
      @stream = @stream.tail
      v
    end
    
    def _exactly(t)
      if @stream.head == t
        @stream = @stream.tail
        t
      else
        raise ParseError
      end
    end
    
    def _string(str)
      str.split('').each { |c| _exactly c }
    end
    
    def _rx(rx)
      s = @stream
      c = _anything
      if c !~ rx
        @stream = s
        raise ParseError
      else
        c
      end
    end
    
    def _class(c)
      _rx(/[#{c}]/m)
    end
    
    def _maybe
      s = @stream
      begin
        yield
      rescue ParseError
        @stream = s
        nil
      end
    end
    
    def _many
      r = []
      loop {
        begin
          s = @stream
          r << yield
        rescue ParseError
          @stream = s
          break
        end
      }
      r
    end
    
    def _one_or_many
      first = yield
      rest = _many { yield }
      [first] + rest
    end
    
    def _or(*fns)
      fns.each { |f|
        begin
          s = @stream
          case f
          when Symbol
            return __send__(f)
          else
            return instance_eval(&f)
          end
        rescue ParseError
          @stream = s
        end
      }
      raise ParseError
    end
    
    def _not
      begin
        s = @stream
        yield
      rescue ParseError
        @stream = s
        true
      else
        raise ParseError
      end
    end
    
    def _pred
      if yield
        true
      else
        raise ParseError
      end
    end
    
    def _eof
      _not { _anything }
    end

    def apply(s)
      __send__ s
    end
  end


  class Compiler < Parser
    
    def to_code
      r = ""
      r << "class #{@name} < #{@superclass}\n"
      @rules.each { |id, (args, term)| r << compile_rule(id, args, term) }
      r << "end\n"
    end
    
    def compile_rule(id, args, term)
      r = "def #{id}(#{args.join(", ")})\n"
      r << "  " << compile(term)
      r << "\nend\n\n"
    end
    
    def compile(term)
      case term.first
      when :seq
        term[1..-1].map { |t|
          compile(t)
        }.join("; ")
      when :lit
        "_string(#{term[1].dump})"
      when :ref
        term[1].to_s + "(" + term[2..-1].map { |t|
          case t.first
          when :lit
            t[1].dump
          when :var
            t[1]
          end
        }.join(", ") + ")"
      when :not, :many, :one_or_many, :maybe
        "_#{term[0]} { #{compile term[1]} }"
      when :alt
        "_or " + term[1..-1].map { |t| "lambda { #{compile(t)} }" }.join(", ")
      when :bind
        term[1] + " = (" + compile(term[2]) + ")"
      when :code
        compile(term[2]) + "; (" + term[1] + ")"
      else
        raise "can't compile #{term.inspect}"
      end
    end
  end
end
