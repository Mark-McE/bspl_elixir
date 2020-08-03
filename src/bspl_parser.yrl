Nonterminals protocol roles params param msgs msg.
Terminals '{' '}' '[' ']' ',' ':' '->' role parameter key adornment word.
Rootsymbol protocol.

protocol -> word '{' role roles parameter params msgs '}'
    : {value('$1'), [{roles, '$4'}, {params, '$6'}, {messages, '$7'}]}.

roles -> word           : [value('$1')].
roles -> word ',' roles : [value('$1')|'$3'].

params -> param             : ['$1'].
params -> param ',' params  : ['$1'|'$3'].
param -> adornment word     : {value('$1'), value('$2'), nonkey}.
param -> adornment word key : {value('$1'), value('$2'), key}.

msgs -> msg      : ['$1'].
msgs -> msg msgs : ['$1'|'$2'].
msg -> word '->' word ':' word '[' params ']'
    : {value('$1'), value('$3'), value('$5'), '$7'}.

Erlang code.

value({_Token, _Line, Value}) -> Value.