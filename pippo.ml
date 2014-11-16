(*****************************************************************************)
(*  pippo, a pretty interesting pre-processor using OCaml                    *)
(*  Copyright (C) 2013 Jonathan Protzenko                                    *)
(*                                                                           *)
(*  This program is free software: you can redistribute it and/or modify     *)
(*  it under the terms of the GNU General Public License as published by     *)
(*  the Free Software Foundation, either version 3 of the License, or        *)
(*  (at your option) any later version.                                      *)
(*                                                                           *)
(*  This program is distributed in the hope that it will be useful,          *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(*  GNU General Public License for more details.                             *)
(*                                                                           *)
(*  You should have received a copy of the GNU General Public License        *)
(*  along with this program.  If not, see <http://www.gnu.org/licenses/>.    *)
(*                                                                           *)
(*****************************************************************************)


(** Initialize the top-level loop. *)
let init () =
  (* Toploop.set_paths (); *)
  Toploop.initialize_toplevel_env ();
  Toploop.input_name := "//toplevel//";
  Topdirs.dir_directory (Sys.getenv "OCAML_TOPLEVEL_PATH");
;;


(** Send a phrase to the top-level, and print any relevant type error. *)
let send_phrase (phrase: string): unit =
  (* Report an error message in a readable format. *)
  let error f =
    f ();
    Format.pp_print_newline Format.err_formatter ();
    Format.pp_print_string Format.err_formatter "The offending phrase is:\n";
    Format.pp_print_string Format.err_formatter phrase;
    Format.pp_print_newline Format.err_formatter ();
    exit 1
  in

  try
    (* Parse the phrase. May raise Syntaxerr.error. *)
    let p = !Toploop.parse_toplevel_phrase (Lexing.from_string phrase) in

    (* Send it to the top-level. May raise Typecore.error. *)
    ignore (Toploop.execute_phrase false Format.err_formatter p);
  with
  | Symtable.Error e ->
      error (fun () -> Symtable.report_error Format.err_formatter e);
  | Typetexp.Error (loc, env, e) ->
      Location.print_error Format.err_formatter loc;
      error (fun () -> Typetexp.report_error env Format.err_formatter e);
  | Typecore.Error (loc, env, e) ->
      Location.print_error Format.err_formatter loc;
      error (fun () -> Typecore.report_error env Format.err_formatter e);
  | Syntaxerr.Error e ->
      error (fun () -> Syntaxerr.report_error Format.err_formatter e);
  | Lexer.Error (e, loc) ->
      error (fun () ->
        Location.print_error Format.err_formatter loc;
        Lexer.report_error Format.err_formatter e;
      );
;;


(** Inject a value into the top-level; the type must be provided. *)
let inject_value (name: string) (typ: string) (value: 'a): unit =
  (* This is, ahem, not the cleanest possible way to achieve this. *)
  let value = Obj.repr value in

  (* Add [name] into the Symtable of the toplevel's value. *)
  Toploop.setvalue name value;

  (* Create a value descriptor suitable for injection into the type environment.
   * The -1 makes sure it creates a weak type variable. *)
  let vd =
    let open Types in {
      val_type = Btype.newty2 (Ctype.get_current_level () - 1) (Tvar None);
      (* val_type = Ctype.newvar (); *)
      val_kind = Val_reg;
      val_loc = Location.none;
      val_attributes = [];
    }
  in

  (* Register [name] in the global type-checking environment for the top-level. *)
  Toploop.toplevel_env :=
    Env.add_value (Ident.create name) vd !Toploop.toplevel_env;

  (* Disable the "this function application is partial" warning, since that's
   * what our little trick with weak variables + ignore () above uses. *)
  Warnings.parse_options false "-5";
  (* Instantiate the weak type variable. *)
  send_phrase (Printf.sprintf "ignore (%s: %s);;" name typ);
  (* Re in-state the warning. *)
  Warnings.parse_options false "+5";
;;


type state = Text | OCaml


let split haystack needle =
  let r = Str.regexp needle in
  Str.split r haystack
;;


let send_phrase_if phrase =
  let phrase = String.trim phrase in
  if String.length phrase > 0 then
    send_phrase (phrase ^ "\n;;")
;;


(** Loop over the lines of a file. Enters OCaml code sections when faced with {%
 * and exits them when faced with %}. *)
let iter_lines (ic: in_channel): unit =
  let tok = Str.regexp "\\({%=\\|{%\\|%}\\)" in
  let state = ref Text in
  let buf = Buffer.create 2048 in
  let process_token token =
    match token, !state with
    | "{%", Text ->
        state := OCaml
    | "%}", OCaml ->
        let contents = Buffer.contents buf in
        Buffer.clear buf;
        let phrases = split contents ";;" in
        List.iter send_phrase_if phrases;
        state := Text
    | _, Text ->
        print_string token
    | _, OCaml ->
        Buffer.add_string buf token;
  in
  let rec process_line line =
    try
      let i = Str.search_forward tok line 0 in
      let m = Str.matched_string line in
      let l = String.length m in
      let before = String.sub line 0 i in
      let after = String.sub line (i + l) (String.length line - i - l) in
      process_token before;
      if m = "{%=" then begin
        process_token "{%";
        process_token "print_string ";
      end else begin
        process_token m;
      end;
      process_line after
    with Not_found ->
      process_token (line ^ "\n")
  in
  while true do
    let line = input_line ic in
    process_line line
  done
;;


let _ =
  if Array.length Sys.argv <> 2 then begin
    print_endline "Usage: %s FILE\n\n  Preprocesses FILE.";
    exit 1
  end;
  
  (* Global initialization. *)
  init ();
  (* Bump the current level artificially. *)
  send_phrase "let _ = ();;";
  (* Test the [inject_value] function. *)
  inject_value
    "__version"
    "unit -> unit"
    (fun () ->
      print_endline "This is pippo v0.1");

  (* Chew lines one by one. *)
  let f = Sys.argv.(1) in
  let ic = open_in f in
  try
    iter_lines ic
  with End_of_file ->
    close_in ic;
    ()
;;
