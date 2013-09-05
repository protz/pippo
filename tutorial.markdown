{%
  let optok = "{" ^ "%";;
  let cltok = "%" ^ "}";;
%}
Presentation
============

Pippo takes a document in any format, and executes any code found between
`{%=optok%}` and `{%=cltok%}` in an OCaml top-level session. Anything outside of
these sections is printed on the standard output transparently.

There is only one top-level session per file, meaning that the OCaml sections
are threaded, as if you were entering the commands in a top-level yourself. In
order to be useful, the OCaml code should use `print_*` statements; the output
of these statements will be interleaved with the non-OCaml sections.

Installation
============

Pippo can be downloaded from [github](https://github.com/protz/pippo). The
project contains a sample Makefile that allows you to pre-process a Markdown
file, namely the tutorial that you're reading. Because Pippo uses compiler
internal modules, it currently only works with OCaml 4.01.0 (in RC at the time
of this writing).

Usage
=====

The `{%=optok%}` and `{%=cltok%}` markers must be on a single, non-indented, Unix-style line.

For instance, writing:

```
  This is some markdown code.

  {%=optok%}
    for i = 1 to 10 do
      Printf.printf "%d<br>" i
    done
  {%=cltok%}
```

In a Markdown document, such as the present one, will result in:

<div class="sample">

This is some markdown code.

{%
  for i = 1 to 10 do
    Printf.printf "%d<br>" i
  done
%}

</div>

Advanced
========

The `pippo.ml` file contains a special `inject_value` function. It
allows you to make any value defined in `pippo.ml` available **in the OCaml
sections**. Just pass it the name of the value, its type, and the OCaml value
itself. As an example, `pippo.ml` contains the following code:

```ocaml
  inject_value
    "__version"
    "unit -> unit"
    (fun () ->
      print_endline "This is pippo v0.1");
```

meaning that if one writes in a document, such as this one:

```
  {%=optok%}
    __version ();
  {%=cltok%}
```

then the result is:

<div class="sample">

{%
  __version ();
%}

</div>

You are encouraged to customize `pippo.ml` and add your own useful functions. Of
course, one can always do:

```
  {%=optok%}
    #load "mylib.cma"
  {%=cltok%}
```

but it's more fun playing with the compiler internals.
