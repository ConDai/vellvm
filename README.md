# Vellvm for DSSS

Vellvm II is a Coq formalization of the semantics of (a subset of) the
LLVM compiler IR that is intended for _formal verification_ of
LLVM-based software.  It is being developed at the
University of Pennsylvania as part of the DeepSpec project.

See:  [Vellvm](http://www.cis.upenn.edu/~stevez/vellvm/)
      [DeepSpec](http://deepspec.org)
      [LLVM](http://llvm.org)

# Participants
 - Steve Zdancewic
 - Dmitri Garbuzov 
 - William Mansky
 - Christine Rizkallah
 - Richard Zhang

## Past Contributors
 - Vivien Durey 
 - Milo Martin
 - Santosh Nagarakatte 
 - Jianzhou Zhao

---

# Structure of the repository

/src/coq  - Coq formalization (see StepSemantics.v)

/src/ml   - OCaml glue code for working with llvm

/src/ml/extracted - OCaml code extracted from the files in /src/coq directory

/src/doc - coqdoq  [not useful yet]

/lib  - for 3rd party libraries [separately installed]

/lib/paco
/lib/lf

/tests - various LLVM source code tests

# Installing / Compiling Vellvm

Assumes:
 - coqc   : version 8.6   (and coqdep, etc.)
 - ocamlc : version 4.04  (probably works with 4.02 or later)
 - OPAM packages: ocamlbuild, menhir, llvm  (for llvm v. 3.8)
 - paco  library  in /lib/paco   [available here](http://plv.mpi-sws.org/paco/)
 - lf : [Logical Foundations](http://www.cis.upenn.edu/~bcpierce/sf/current/index.html)

Compilation:

1. clone the vellvm git repo
2. install 3rd party libraries in /lib
- /lib/paco  should contain the paco library
- /lib/lf    should contain the Logical Foundations development 
3. run `make` in the /src directory

# Running

Do `src/vellvm -help` from the command line.

Try `src/vellvm -interpret tests/ll/factorial.ll`.
