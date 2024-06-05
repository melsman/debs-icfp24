## SMLtoJs

SMLtoJs (pronounced "SML toys") is a compiler from Standard ML to
JavaScript, which allows programmers to enjoy the power of Standard ML
static typing, higher-order functions, pattern matching, and modules
for programming client-side web applications.

SMLtoJs compiles all of Standard ML, including most of the Standard ML
Basis Library. It also has good support for integrating with
JavaScript.

## Features

* All of Standard ML. SMLtoJs has support for all of Standard ML,
  including modules, pattern matching, higher-order functions,
  generative exceptions, etc.

* Standard ML Basis Library support. SMLtoJs has support for most of
  the Standard ML basis library, including the following structures:

      Array2 ArraySlice Array Bool Byte Char CharArray CharArraySlice
      CharVector CharVectorSlice Date General Int Int31 Int32 IntInf
      LargeWord ListPair List Math Option OS.Path Pack32Big
      Pack32Little Random Real StringCvt String Substring Text Time
      Timer Vector VectorSlice Word Word31 Word32 Word8 Word8Array
      Word8ArraySlice Word8Vector Word8VectorSlice

* JavaScript integration. SMLtoJs has support for calling JavaScript
  functions and for executing JavaScript statements.

* Simple DOM access support and support for installing Standard ML
  functions as DOM event handlers and timer call back functions.

* Optimization. All Modules language constructs, including functors,
  functor applications, and signature constraints, are eliminated by
  SMLtoJs at compile time. Moreover, SMLtoJs performs a series of
  compile time optimizations, including function inlining and
  specialization of higher-order recursive functions, such as map
  and foldl. Optimizations can be controlled using compile-time
  flags. As a result, SMLtoJs generates fairly efficient JavaScript
  code, although there are rooms for improvements; see below.

* Compiling in the Browser. A version of SMLtoJs can be compiled by
  SMLtoJs itself, which leads to a proper browser hosted Standard ML
  compiler.

Online Demonstration

To see SMLtoJs in action, see the [SMLtoJs homepage](http://www.smlserver.org/smltojs) for links to online
examples of compiled Standard ML and the Web browser hosted Standard
ML compiler.


## Getting the Sources

SMLtoJs compiles on Linux and Mac OS systems with MLton or
MLKit. The SMLtoJs sources are hosted at Github. To get the latest
sources, issue the following git command:

    $ git clone https://github.com/melsman/mlkit.git smltojs

This command copies the sources to the directory smltojs.

## Building SMLtoJs

To compile SMLtoJs from the sources (see above), simply type

    $ cd smltojs
    $ ./autobuild
    $ ./configure
    $ make smltojs
    $ make smltojs_basislibs

If compilation succeeds, an executable file bin/smltojs should now be
available.

## How it Works

The SMLtoJs executable `bin/smltojs` takes as argument an sml-file
(or an mlb-file referencing the sml-files and other mlb-files of the
project) and produces an html file called `run.html` provided there are
no type errors! The resulting html-file mentions the generated
JavaScript files and a file `prims.js`, which contains a set of
primitive JavaScript functions used by the generated code.

Hint: Adding the flag `-o name` as command-line argument to smltojs
results in the file name.html being generated instead of run.html.

## Testing that it Works

To compile and test the test programs, cd to the `js/test` directory
and run `make clean all`:

    $ cd js/test
    $ make clean all

You can now start Firefox or Chrome on the generated html-files; the file
all.html includes links to all the test files:

    $ firefox all.html

The examples `temp.html`, `counter.html`, and `life.html` are the most
interesting examples at the moment (more will come).

## Compilation in the Browser

To build the browser-hosted compiler, proceed as follows:

    $ cd ../../src/Compiler
    $ SML_LIB=$(HOME)/smltojs/js ../../bin/smltojs -aopt smltojs0.mlb

The last command should generate a file `run.html` which links to all
necessary JavaScript sources. Executing

    $ firefox run.html

will start up a simple IDE for the compiler.

## Issues

There is a known issue with a bug in the following test (in some cases,
the implementation pretty prints reals slightly different than
suggested by the spec):

    real
    ----
    test13c: WRONG

There are plenty of possibilities for further improvements, including:

* Functor in-lining, which may lead to improved execution speed.

* Improved constant folding. Some features are implemented with the
  `--aggressive_opt` flag to smltojs (`-aopt`).

## License and Copyright

The MLKit compiler is distributed under the GNU Public License,
version 2. See the file [MLKit-LICENSE](/doc/license/MLKit-LICENSE)
for details. The runtime system (`/src/Runtime/`) and libraries
(`basis/`) is distributed under the more liberal MIT License.
