all: tutorial.pp.html

%.pp.markdown: %.markdown pippo.byte
	./pippo.byte $< > $@

%.html: %.markdown
	pandoc \
	  --highlight-style=tango \
	  --standalone --css=style.css \
	  $< > $@

pippo.byte: pippo.ml
	# This is pretty much what ocamlmktop does, except we don't load
	# topstart.cmo, otherwise it turns pippo into an ocaml interpreter.
	ocamlc \
	  -verbose \
	  -g -annot \
	  -I +compiler-libs \
	  -linkall ocamlcommon.cma ocamlbytecomp.cma ocamltoplevel.cma str.cma \
	  pippo.ml -o pippo.byte

clean:
	rm -f *.pp.markdown *.cmo *.cmi *.annot *.byte
