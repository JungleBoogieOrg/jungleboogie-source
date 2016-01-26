Definitions.

R_MODULE = module
R_CLASS = class
R_INT = int
R_LONG = long
R_USTRING = ustring
R_BUFFER = buffer
R_VECTOR = vector
R_BOOLEAN = boolean

Dig = [0-9]
Big = [A-Z]
Small = [a-z]
% WS = [\000-\s]
ANY = ({Small}|{Big}|{Dig})
MOD_ELEM = {Small}({ANY})*
MODULE = {MOD_ELEM}(\.{MOD_ELEM})*
CLASS = {Big}({ANY})*
QUAL_CLASS = {MODULE}\.{CLASS}
TYPE_OR_ID = {Small}({ANY})*
WS = ([\s\t])
ANY_PLUS_WS = (.|[\s\t])
INCOMMENT = ([^*/]|[^*]/|\*[^/])

Rules.

% //{ANY_PLUS_WS}*\n : {token, {comment, TokenChars, TokenLine}}.
% /\*{INCOMMENT}*\*/ : {token, {comment, TokenChars, TokenLine}}.
//{ANY_PLUS_WS}*\n : skip_token.
/\*{INCOMMENT}*\*/ : skip_token.

; : {token, {semicolon, TokenLine}}.
{ : {token, {lbrack, TokenLine}}.
} : {token, {rbrack, TokenLine}}.
< : {token, {lt, TokenLine}}.
> : {token, {gt, TokenLine}}.
{R_MODULE} : {token, {module, TokenLine}}.
{R_CLASS} : {token, {class, TokenLine}}.
{R_INT} : {token, {int, TokenLine}}.
{R_LONG} : {token, {long, TokenLine}}.
{R_USTRING} : {token, {ustring, TokenLine}}.
{R_BUFFER} : {token, {buffer, TokenLine}}.
{R_VECTOR} : {token, {vector, TokenLine}}.
{R_BOOLEAN} : {token, {boolean, TokenLine}}.

{TYPE_OR_ID} : {token, {type_or_id_name, TokenChars, TokenLine}}.
{CLASS} : {token, {class_name, TokenChars, TokenLine}}.
{QUAL_CLASS} : {token, {qual_class_name, TokenChars, TokenLine}}.
{MODULE} : {token, {module_name, TokenChars, TokenLine}}.
{WS}*\n : skip_token.
{WS}+ : skip_token.

Erlang code.

