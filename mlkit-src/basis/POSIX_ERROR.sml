(** Symbolic names for POSIX errors.

The structure Posix.Error provides symbolic names for errors that may
be generated by the POSIX library, and various related functions.

*)

signature POSIX_ERROR =
  sig
    type syserror = OS.syserror

    val toWord      : syserror -> SysWord.word
    val fromWord    : SysWord.word -> syserror

    val errorMsg    : syserror -> string
    val errorName   : syserror -> string
    val syserror    : string -> syserror option

    val acces       : syserror
    val again       : syserror
    val badf        : syserror
    val badmsg      : syserror
    val busy        : syserror
    val canceled    : syserror
    val child       : syserror
    val deadlk      : syserror
    val dom         : syserror
    val exist       : syserror
    val fault       : syserror
    val fbig        : syserror
    val inprogress  : syserror
    val intr        : syserror
    val inval       : syserror
    val io          : syserror
    val isdir       : syserror
    val loop        : syserror
    val mfile       : syserror
    val mlink       : syserror
    val msgsize     : syserror
    val nametoolong : syserror
    val nfile       : syserror
    val nodev       : syserror
    val noent       : syserror
    val noexec      : syserror
    val nolck       : syserror
    val nomem       : syserror
    val nospc       : syserror
    val nosys       : syserror
    val notdir      : syserror
    val notempty    : syserror
    val notsup      : syserror
    val notty       : syserror
    val nxio        : syserror
    val perm        : syserror
    val pipe        : syserror
    val range       : syserror
    val rofs        : syserror
    val spipe       : syserror
    val srch        : syserror
    val toobig      : syserror
    val xdev        : syserror
  end

(**

[eqtype syserror] POSIX error type. This type is identical to the type
OS.syserror.

[toWord syserror]
[fromWord w]

These functions convert between syserror values and non-zero word
representations. Note that there is no validation that a syserror
value generated using fromWord corresponds to an error value supported
by the underlying system.

[errorMsg sy] returns a string that describes the system error sy.

[errorName err] returns a unique name used for the syserror value.

[syserror s] returns the syserror whose name is s if it exists. If e
is a syserror, we have SOME(e) = syserror(errorName e).

[acces] An attempt was made to access a file in a way that is
forbidden by its file access permissions.

[again] A resource is temporarily unavailable, and later calls to the
same routine may complete normally.

[badf] A bad file descriptor was out of range or referred to no open
file, or a read (write) request was made to a file which was only open
for writing (reading).

[badmsg] The implementation has detected a corrupted message.

[busy] An attempt was made to use a system resource that was being
used in a conflicting manner by another process.

[canceled] The associated asynchronous operation was canceled before
completion.

[child] A wait related function was executed by a process that had no
existing or unwaited-for child process.

[deadlk] An attempt was made to lock a system resource which would
have resulted in a deadlock situation.

[dom] An input argument was outside the defined domain of a
mathematical function.

[exist] An existing file was specified in an inappropriate context;
for instance, as the new link in a link function.

[fault] The system detected an invalid address in attempting to use an
argument of a system call.

[fbig] The size of a file would exceed an implementation-defined
maximum file size.

[inprogress] An asynchronous process has not yet completed.

[intr] An asynchronous signal (such as a quit or a term (terminate)
signal) was caught by the process during the execution of an
interruptible function.

[inval] An invalid argument was supplied.

[io] Some physical input or output error occurred.

[isdir] An illegal operation was attempted on a directory, such as
opening a directory for writing.

[loop] A loop was encountered during pathname resolution due to
symbolic links.

[mfile] An attempt was made to open more than the maximum number of
file descriptors allowed in this process.

[mlink] An attempt was made to have the link count of a single file
exceed a system-dependent limit.

[msgsize] An inappropriate message buffer length was used.

[nametoolong] The size of a pathname string, or a pathname component,
was longer than the system-dependent limit.

[nfile] There were too many open files.

[nodev] An attempt was made to apply an inappropriate function to a
device; for example, trying to read from a write-only device such as a
printer.

[noent] A component of a specified pathname did not exist, or the
pathname was an empty string.

[noexec] A request was made to execute a file that, although it had
the appropriate permissions, was not in the format required by the
implementation for executable files.

[nolck] A system-imposed limit on the number of simultaneous file and
record locks was reached.

[nomem] The process image required more memory than was allowed by the
hardware or by system-imposed memory management constraints.

[nospc] During a write operation on a regular file, or when extending
a directory, there was no free space left on the device.

[nosys] An attempt was made to use a function that is not available in
this implementation.

[notdir] A component of the specified pathname existed, but it was not
a directory, when a directory was expected.

[notempty] A directory with entries other than "." and ".." was
supplied when an empty directory was expected.

[notsup] The implementation does not support this feature of the
standard.

[notty] A control function was attempted for a file or a special file
for which the operation was inappropriate.

[nxio] Input or output on a special file referred to a device which
did not exist, or made a request beyond the limits of the device. This
error may occur when, for example, a tape drive is not online.

[perm] An attempt was made to perform an operation limited to
processes with appropriate privileges or to the owner of a file or
some other resource.

[pipe] A write was attempted on a pipe or FIFO for which there was no
process to read the data.

[range] The result of a function was too large to fit in the available
space.

[rofs] An attempt was made to modify a file or directory on a file
system which was read-only at that time.

[spipe] An invalid seek operation was issued on a pipe or FIFO.

[srch] No such process could be found corresponding to that specified
by a given process ID.

[toobig] The sum of bytes used by the argument list and environment
list was greater than the system-imposed limit.

[xdev] A link to a file on another file system was attempted.

[Discussion]

The string representation of a syserror value, as returned by
errorName, is the name of the error. Thus, errorName badmsg =
"badmsg".

The name of a corresponding POSIX error can be derived by capitalizing
all letters and adding the character ``E'' as a prefix. For example,
the POSIX error associated with nodev is ENODEV. The only exception to
this rule is the error toobig, whose associated POSIX error is E2BIG.

*)
