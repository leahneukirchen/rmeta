require 'lib/rmeta'

gram = File.read("lib/rmeta.rm")

class OMeta < RMeta::Compiler
  def _ws
    _many {
      _rx(/\s/m)
    }
  end

  def _token(t)
    _ws; _string(t); _ws
  end

  def constant
    _ws
    first = _rx(/[A-Z]/)
    rest = _many { _or lambda { _rx(/\w/) }, lambda { _string("::") } }
    first + rest.join
  end

  def identifier
    _ws
    first = _rx(/[a-z_]/)
    rest = _many { _rx(/\w/) }
    first + rest.join
  end

  def main
    @rules = {}
    _token("meta")
    @name = constant
    _maybe {
      _token("<:")
      @superclass = constant
    }
    _token("{")
    _many { rule }
    _token("}")
    _eof

    self
  end

  def rule
    id = identifier

    args = _many {
      identifier
    }

    _token("::=")
    e = expr
    _maybe {
      _token("=>")
      _token("[")
      code = bracketcode
      _token("]")

      e = [:code, code, e]
    }
    _token(";")
    @rules[id] = [args, e]
  end

  def bracketcode
    _many {
      _or lambda {
        _exactly("[") +
        bracketcode +
        _exactly("]")
      }, lambda {
        _not { _exactly("[") }
        _not { _exactly("]") }
        _anything
      }
    }.join
  end

  def expr
    altexpr
  end

  def altexpr
    first = seqexpr
    rest = _many {
      _token('|')
      seqexpr
    }
    if rest.empty?
      first
    else
      [:alt, first, *rest]
    end
  end

  def seqexpr
    e = _many {
      f = notexpr
      _maybe { 
        case _rx(/[*+?]/)
        when "*"
          f = [:many, f]
        when "+"
          f = [:one_or_many, f]
        when "?"
          f = [:maybe, f]
        end
      }      
      _maybe {
        _token(':') 
        v = identifier
        f = [:bind, v, f]
      }
      f
    }
    if e.size == 1
      e.first
    else
      [:seq, *e]
    end
  end

  def notexpr
    _or lambda {
      _token("~")
      [:not, notexpr]
    }, :literal, :ref, :paren
  end

  def literal
    _ws
    str = nil
    _or lambda {
      _exactly("'")
      str = _anything
      _token("'")
    }, lambda {
      _exactly('"')
      str = _many { _rx(/[^"]/) }.join
      _token('"')
    }

    [:lit, str]
  end

  def var
    [:var, identifier]
  end

  def ref
    _token('<')
    r = identifier

    args = _many {
      _or :var, :literal
    }

    _token('>')

    [:ref, r, *args]
  end

  def paren
    _token('(')
    e = expr
    _token(')')

    e
  end
end

eval(OMeta.parse(gram.gsub(/RMeta::Grammar/, "Stage1")).to_code)

s1 = Stage1.parse(gram.gsub(/RMeta::Grammar/, "Stage2")).to_code
eval(s1)
s2 = Stage2.parse(gram.gsub(/RMeta::Grammar/, "Stage2")).to_code
eval(s2)

if s1 != s2
  abort "Bootstrap failed.  Dumping to 1 and 2."
  File.open("1", "w") { |o| o << s1 }
  File.open("2", "w") { |o| o << s2 }
end

puts "Bootstrap successful.  Dumping code."
File.open("lib/rmeta.grammar.rb", "w") { |o| o << Stage2.parse(gram).to_code }
