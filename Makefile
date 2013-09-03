all: tutorial.pp.html

%.pp.markdown: %.markdown pippo.byte
	./pippo.byte $< > $@

%.html: %.markdown
	pandoc \
	  --highlight-style=tango \
	  --standalone --css=style.css \
	  $< > $@

pippo.byte: pippo.ml
	ocamlfind ocamlc -g -package compiler-libs.toplevel -annot -linkpkg pippo.ml -o pippo.byte

clean:
	rm -f *.pp.markdown *.cmo *.cmi *.annot *.byte
