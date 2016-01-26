Nonterminals jute module_section module_body class_section class_body type attrib.
Terminals semicolon lbrack rbrack lt gt type_or_id type_or_id_name 
    class class_name qual_class_name module module_name
    int long ustring buffer boolean vector.
Rootsymbol jute.
Endsymbol eof.

jute -> module_section : ['$1'].
jute -> module_section jute : ['$1'] ++ '$2'.

module_section -> module module_name lbrack module_body rbrack : {module, '$2', '$4'}.
module_body -> class_section : ['$1']. 
module_body -> class_section module_body : ['$1'] ++ '$2'.

type -> int : int.
type -> boolean : boolean.
type -> long : long.
type -> ustring : ustring.
type -> buffer : buffer.
type -> vector lt type gt : {vector, '$3'}.
type -> class_name : {class, '$1'}.
type -> qual_class_name : {class, '$1'}.

attrib -> type type_or_id_name semicolon : {attrib, '$1', '$2'}.

class_section -> class class_name lbrack class_body rbrack : {class, '$2', '$4'}.
class_body -> attrib class_body : ['$1'] ++ '$2'.
class_body -> attrib : ['$1'].

