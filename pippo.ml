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
  Toploop.initialize_toplevel_env ();
  Toploop.input_name := "//toplevel//";
  Topdirs.dir_directory (Sys.getenv "OCAML_TOPLEVEL_PATH");
;;


(** Send a phrase to the top-level, and print any relevant type error. *)
let send_phrase (phrase: string): unit =
  (* Report an error message in a readable format. *)
  let error f =
    Format.pp_print_string Format.err_formatter "Error parsing the following phrase:\n";
    Format.pp_print_string Format.err_formatter phrase;
    Format.pp_print_newline Format.err_formatter ();
    f ();
    Format.pp_print_newline Format.err_formatter ();
    exit 1
  in

  try
    (* Parse the phrase. May raise Syntaxerr.error. *)
    let p = !Toploop.parse_toplevel_phrase (Lexing.from_string phrase) in

    (* Send it to the top-level. May raise Typecore.error. *)
    let res = Toploop.execute_phrase false Format.std_formatter p in
    if res then
      ()
    else
      failwith "Error sending phrase to the toplevel"
  with
  | Typecore.Error (_loc, env, e) ->
      (* Print any error message. *)
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
      val_loc = Location.none
    }
  in

  (* Register [name] in the global type-checking environment for the top-level. *)
  Toploop.toplevel_env :=
    Env.add_value (Ident.create name) vd !Toploop.toplevel_env;

  (* Instantiate the weak type variable. *)
  send_phrase (Printf.sprintf "ignore (%s: %s);;" name typ);
;;


type state = Text | OCaml


(** Loop over the lines of a file. Enters OCaml code sections when faced with {%
 * and exits them when faced with %}. *)
let iter_lines (ic: in_channel): unit =
  let state = ref Text in
  let buf = Buffer.create 2048 in
  while true do
    let line = input_line ic in
    match line, !state with
    | "{%", Text ->
        state := OCaml
    | "%}", OCaml ->
        Buffer.add_char buf '\n';
        Buffer.add_string buf ";;";
        send_phrase (Buffer.contents buf);
        Buffer.clear buf;
        state := Text
    | _, Text ->
        print_endline line
    | _, OCaml ->
        Buffer.add_string buf line;
        Buffer.add_char buf '\n'
  done
;;


let _ =
  if Array.length Sys.argv <> 2 then begin
    print_endline "Usage: %s FILE\n\n  Preprocesses FILE.";
    exit 1
  end;
  
  (* Global initialization. *)
  init ();
  (* Disable the "this function application is partial" warning, since that's
   * what our little trick with weak variables + ignore () above uses. *)
  Warnings.parse_options false "-5";
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
