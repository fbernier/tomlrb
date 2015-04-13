class Tomlrb::GeneratedParser
token IDENTIFIER STRING DATETIME NUMBER TRUE FALSE
rule
  expressions
    : expressions expression
    | expression
    ;
  expression
    : table
    | array_of_tables
    | assignment
    | inline_table_assignment
    ;
  table
    : '[' identifier ']' { @handler.set_context(val[1]) }
    ;
  inline_table_assignment
    : inline_table_start inline_table_end
    ;
  inline_table_start
    : identifier '=' '{' { @handler.set_context(val[0]) }
    ;
  inline_table_end
    : inline_values '}'
    ;
  inline_values
    : inline_values ',' assignment
    | assignment
    ;
  assignment
    : identifier '=' value { @handler.assign(val[0]) }
    ;
  array
    : start_array array_continued
    ;
  array_continued
    : ']' { @handler.end_array }
    | value array_next
    ;
  array_next
    : ']' { @handler.end_array }
    | ',' array_continued
    ;
  start_array
    : '[' { @handler.start_array }
    ;
  end_array
    : ']'
    ;
  array_of_tables
    : '[' '[' identifier ']' ']' { @handler.set_context(val[2], is_array_of_tables: true) }
    ;
  value
    : scalar { @handler.push(val[0]) }
    | array
    ;
  scalar
    : string
    | literal
    ;
  literal
    | NUMBER { n = val[0]; result = n.count('.') > 0 ? n.to_f : n.to_i }
    | TRUE   { result = true }
    | FALSE  { result = false }
    | DATETIME { result = Time.parse(val[0]) }
    ;
  string
    : STRING
    ;
  identifier:
    : IDENTIFIER
    ;
