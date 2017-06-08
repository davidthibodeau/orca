exception Syntax_error of Lexing.position
exception Scanning_error of Lexing.position * string

exception Violation of string (* an unexpected error condition, this should be a bug in the program *)
exception Error of string (* a generic problem with user input *)
exception NotImplemented
exception Error_loc of Location.src_pos * string (* a generic problem with user input *)
