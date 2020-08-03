Definitions.

ADORNMENT  = in|out|nil
WORD       = [A-Za-z_]+
WHITESPACE = [\s\t\n\r]

Rules.

role          : {token, {role, TokenLine}}.
parameter     : {token, {parameter, TokenLine}}.
key           : {token, {key, TokenLine}}.
\-\>          : {token, {'->', TokenLine}}.
\:            : {token, {':', TokenLine}}.
\{            : {token, {'{', TokenLine}}.
\}            : {token, {'}', TokenLine}}.
\[            : {token, {'[', TokenLine}}.
\]            : {token, {']', TokenLine}}.
,             : {token, {',', TokenLine}}.
{ADORNMENT}   : {token, {adornment, TokenLine, list_to_atom(TokenChars)}}.
{WORD}        : {token, {word, TokenLine, list_to_bitstring(TokenChars)}}.
{WHITESPACE}+ : skip_token.

Erlang code.
% No additional code
