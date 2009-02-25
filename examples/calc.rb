$: << "../lib"
require 'rmeta'

RMeta.parse(<<'EOF')
meta Calculator {
  main ::= <add>;

  add ::= <mult>:a ("+" <mult>:b => [a += b]
                   |"-" <mult>:b => [a -= b])* => [a];

  mult ::= <log>:a ("*" <log>:b => [a *= b]
                   |"/" <log>:b => [a /= b])* => [a];

  log ::= <keyword "ln"> <log>:a => [Math.log a]
        | <atom>;

  atom ::= <number>
         | <keyword "PI"> => [Math::PI]
         | <keyword "E"> => [Math::E]
         | <keyword "("> <add>:a <keyword ")"> => [a];

  number ::= ("+" | "-")?:p <_class "0-9">+:n => ["#{p}#{n}".to_i];

  keyword k ::= <_class "\s">* <_string k>:s <_class "\s">* => [s];
}
EOF

p Calculator.parse("5+6*9+(E*ln 4)")
