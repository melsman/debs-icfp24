# ICFP 2024 Artifact

Name: Double-Ended Bit-Stealing for Algebraic Data Types

## Artifact Instructions

This artifact aims at replicating the results reported in the ICFP 2024 paper
Double-Ended Bit-Stealing for Algebraic Data Types.

The artifact comes in two versions, a file `debs-icfp24.tgz` containing the
sources of the artifact (along with this `README.md` file) and a QEMU image
(`debs-icfp24-image.tar.xz`) containing the sources and with all dependencies
installed. The QEMU image is set up to start with 12GB of RAM (modification in
`start.sh`) and works best under an x86_64 host architecture.

The sources in the file `debs-icfp24.tgz` appear unpacked in the QEMU image in
the folder `/home/artifact/debs-icfp24`. For detailed instructions on how to
install QEMU, please consult the section "QEMU Instructions" below. To launch
the QEMU image, download the file `debs-icfp24-image.tar.xz` and execute the
following commands:

```
$ tar xf debs-icfp24-image.tar.xz
$ cd debs-icfp24-image
$ ./start.sh -smp 2
```

### Installed Dependencies

The ICFP 2024 base QEMU image has been extended as follows:

- Debian packages: cmake make libgmp-dev time automake build-essential

- Standard ML compilers: MLton 20210117 (installed in `/home/artifact/mlton`),
  SML/NJ 110.99.4 (installed in `/home/artifact/smlnj`), MLKit 4.7.11 (installed
  in `/home/artifact/mlkit`).

- The file `/home/artifact/.profile` has been augmented to extend the PATH
  environment variable to include the paths to the binaries of the above
  Standard ML compilers and tools.

- The artifact file `debs-icfp24.tgz` has been unpacked in the folder
  `/home/artifact/debs-icfp24`.

### Getting Started

We now assume that you have started the QEMU VM image as described above and
have logged into the system using the command (password is `password`)

```
$ ssh -p 5555 artifact@localhost
```

This command will put you into a shell inside a directory containing the
experimental infrastructure (you may also just login using the terminal window
opened by QEMU).  For compiling some necessary infrastructure tools, execute
the following commands:

```
$ cd /home/artifact/debs-icfp24
$ make prepare
```

These commands should take less than a minute to run.

### List of Claims

The artifact establishes the following main claims mentioned in the paper:

1. The MLKit implementation of double-ended bit-stealing makes unboxing
   decisions as reported in the paper. These claims can be established by
   compiling a series of examples in the `debs-icfp24/demo` folder:

   ```
   $ cd /home/artifact/debs-icfp24/demo
   $ make clean && make all
   ```

   The commands will report on the unboxing decisions for the examples `exp`,
   `single`, `patricia`, `uf`, `stream`, and `opt` (also the expected unboxing
   decisions are shown) and will take less than a minute to execute.

   As a side note, source files are given to the MLKit compiler (i.e., the
   `mlkit` executable) either as a single source file or as an mlb-file
   describing a directed acyclic graph (DAG) of source code files. The MLKit
   compiler also accepts a series of flags, which can be printed using `mlkit
   --help`:

   ```
   $ mlkit --version
   ...
   ```

2. The effect of double-ended bit-stealing, as implemented in the MLKit
   compiler, is close to that reported in Figure 8 (running times) and Figure 9
   (memory usage) of the paper. To generate textual formats of the two figures,
   execute the following commands (running the benchmarks should take less than
   an hour):

   ```
   $ cd /home/artifact/debs-icfp24/src
   $ make clean && make all
   $ make minitpress
   $ make minimpress
   ```

   For Figure 8 (`make minitpress`), the column `MLKit` corresponds to `real #
   rg-cr`, the column `MLKit^dagger` corresponds to `real # rg-nhpt-cr`, and
   `MLKit^R` corresponds to `real # r-cr`. Notice, in particular, time
   improvements (`real # rg-cr` faster than `real # rg-nhpt-cr`) for the
   benchmarks `calc`, `logic`, `patricia`, and `uf`.

   For Figure 9 (`make minimpress`), again, the column `MLKit` corresponds to
   `rss # rg-cr`, the column `MLKit^dagger` corresponds to `rss # rg-nhpt-cr`,
   and `MLKit^R` corresponds to `rss # r-cr`. In general, for all benchmarks,
   memory usage (maximum resident set size) for the `rss # rg-cr` column should
   not exceed memory usage for the `rss # rg-nhpt-cr` column (up to rounding
   errors).

3. Double-ended bit-stealing as implemented in the MLKit compiler has a positive
   effect on the execution time for compiling the MLKit itself and the MLton
   compiler, as reported in Figure 10 of the paper. A textual format of Figure
   10 can be generated with the following commands, which may take several hours
   to execute:

   ```
   $ cd /home/artifact/debs-icfp24/boot
   $ make all
   $ make times_report
   ```

   The commands compile MLKit and MLton several times, respectively. In the
   textual figure generated with `make times_report`, the columns MLKitNew
   corresponds to MLKit in Figure 10 and MLKitOld corresponds to MLKit^dagger in
   Figure 10.

   The generated table should show improvements for both running time and memory
   usage, both with respect to compiling MLKit and with respect to compiling
   MLton.

4. Boxities reported when compiling the MLKit sources and the MLton sources are
   (precisely) as reported in Figure 11. A textual format of the figure can be
   generated with the following command, provided step 3 has been executed:

   ```
   $ cd /home/artifact/debs-icfp24/boot
   $ make boxity_report
   ```

## Manifest

This section describes every sub-directory and nontrivial file of
`/home/artifact/debs-icfp24/` and their purpose.

* `demo/`: The demo programs and a Makefile containing targets for compiling and
  executing the programs with MLKit.

* `mlkit-bench/`: Programs for running benchmarks and for displaying tables
  (based on produced json-files).

* `src/`: The benchmark programs reside in this folder together with a Makefile
  used for executing the benchmarks and for showing result tables.

* `boot`: Machinery for measuring compile time and memory usage for compiling
  MLKit and MLton with different configurations of MLKit (with and without
  double-ended bit-stealing).

* `Makefile`: The commands executed when running `make`.  You can extract the
  commands if you need to run them out of order.

* `LICENSE`: License for the artifact source code. Notice that embedded sources
  for MLKit and MLton are distributed under the licenses located in the folders
  `mlkit-src` and `mlton-src`, respectively.

* `mlkit_src`: Source code for the MLKit.

* `mlton_src`: Source code for the MLton compiler, modified to compile
  efficiently with MLKit's recompilation management (some toplevel
  build-functors have been converted into structures).

* `Dockerfile`: A file that documents how to extend a basic Debian distribution
  with installed versions of MLton, SML/NJ, and MLKit.

* `README.md`: This file.

## MLKit Source Code Overview

The source code for the MLKit compiler is Standard ML and the runtime system
(target code is x86_64 machine code) is written primarily in C. There is almost
full support for the Standard ML Basis Library.

As mentioned above, the source code is available in the folder
`debs-icfp24/mlkit-src` (version 4.7.11). Below, we will briefly describe the
major source code components that contribute to double-ended bit-stealing in
MLKit:

- `src/Compiler/Lambda/CompileDec.sml`: The inference algorithm that determines
  boxities for algebraic data types appears in this file (the main function is
  `unbox_datbinds`). Decisions about boxities are recorded directly in type
  names associated with the algebraic data types. This file is responsible for
  the compilation of the AST-representation of Standard ML programs into a typed
  intermediate language (`LAMBDA_EXP`).

- `src/Compiler/Regions`: After `LAMBDA_EXP` (and a series of optimisations),
  programs are compiled into explicit region-annotated terms (the language
  `REGION_EXP`). This translation is the process of *region inference*, a typed-
  and effect-based transformation. Region-annotated algebraic data types are
  compiled from their non-region annotated counterparts using information about
  boxities in the type names associated with the algebraic data types (file
  `src/Compiler/Regions/RType.sml`). Moreover, in `REGION_EXP`, constructors
  associated with unboxed types (unary and nullary) are not associated with
  regions.

- `src/Compiler/Backend/X64/CodeGenX64.sml`: For generating code for switches
  (simple pattern matches) and for constructing and deconstructing constructed
  values, the implementation takes into account the boxity of the relevant
  algebraic data type.

- `src/Runtime/GC.c`: For reference-tracing garbage collection, the garbage
  collector needs to untag unboxed tagged values appropriately and, in
  particular, deal correctly with double-ended bit-stealing.

### Related GitHub Issues and Pull Requests

The MLKit is maintained on GitHub in the following repository:

https://github.com/melsman/mlkit

Double-ended bit-stealing in the MLKit is implemented mainly under the following
GitHub Pull Request:

https://github.com/melsman/mlkit/pull/149

It was first suggested in the following GitHub issue:

https://github.com/melsman/mlkit/issues/99


## QEMU Instructions

The ICFP 2024 Artifact Evaluation Process is using a Debian QEMU image as a base
for artifacts. The Artifact Evaluation Committee (AEC) will verify that this
image works on their own machines before distributing it to authors.  Authors
are encouraged to extend the provided image instead of creating their own. If it
is not practical for authors to use the provided image then please contact the
AEC co-chairs before submission.

QEMU is a hosted virtual machine monitor that can emulate a host processor via
dynamic binary translation. On common host platforms QEMU can also use a host
provided virtualization layer, which is faster than dynamic binary translation.

QEMU homepage: https://www.qemu.org/

### Installation

#### OSX
``brew install qemu``

#### Debian and Ubuntu Linux
``apt-get install qemu-kvm``

On x86 laptops and server machines you may need to enable the "Intel
Virtualization Technology" setting in your BIOS, as some manufacturers leave
this disabled by default. See Debugging.md for details.

#### Arch Linux
``pacman -Sy qemu``

See the [Arch wiki](https://wiki.archlinux.org/title/QEMU) for more info.

See `Debugging.md` if you have problems logging into the artifact via SSH.

#### Windows 10

Download and install QEMU via the links at

https://www.qemu.org/download/#windows.

Ensure that `qemu-system-x86_64.exe` is in your path.

Start Bar -> Search -> "Windows Features"
          -> enable "Hyper-V" and "Windows Hypervisor Platform".

Restart your computer.

#### Windows 8

See Debugging.md for Windows 8 install instructions.

### Startup

The artifact provides a `start.sh` script to start the VM on unix-like systems
and `start.bat` for Windows. Running this script will open a graphical console
on the host machine, and create a virtualized network interface.  On Linux you
may need to run with `sudo` to start the VM. If the VM does not start then check
`Debugging.md`

Once the VM has started you can login to the guest system from the host.
Whenever you are asked for a password, the answer is `password`. The default
username is `artifact`.

```
$ ssh -p 5555 artifact@localhost
```

You can also copy files to and from the host using scp.

```
$ scp -P 5555 artifact@localhost:somefile .
```

### Shutdown

To shutdown the guest system cleanly, login to it via ssh and use

```
$ sudo shutdown now
```

### Debugging

See `Debugging.md` for advice on resolving potential problems.
