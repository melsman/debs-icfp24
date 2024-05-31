# MLKit Bootstrapping Measurements

Running `make` in this directory generates bootstrapped compilers for
MLKit and MLKit^dagger and compiles the MLKit five times for each
configuration. The running times and memory usage is stored in log
files:

- MLKit^dagger: `bootstrap0-mlkit-v1.log` ... `bootstrap0-mlkit-v6.log`

- MLKit: `bootstrap1-mlkit-v1.log` ... `bootstrap1-mlkit-v6.log`

The `*v1.log` files are not to be included in reported
measurements. We use the following terminal commands to extract
wall-clock times from the log files for MLKit^dagger and MLKit,
respectively:

```
  $ grep ' real       ' bootstrap0-mlkit-v*.log  | grep -v v1 | sed -r 's/.* ([0-9]+.[0-9]+) real.*/\1/'
  ...
  $ grep ' real       ' bootstrap1-mlkit-v*.log  | grep -v v1 | sed -r 's/.* ([0-9]+.[0-9]+) real.*/\1/'
  ...
```

We can now use the tools in `tools.sml` to calculate the average and
relative standard deviation for the two configurations:

```
. val mlkit_time_old = [395.74,391.98,396.04,399.11,399.00] |> Stat.average_rsd;
> val mlkit_time_old = {avg=396.374,rsd=0.737721818199} : {avg: real, rsd: real}
. val mlkit_time_new = [362.58,366.73,365.96,364.50,365.43] |> Stat.average_rsd;
> val mlkit_time_new = {avg=365.04,rsd=0.437404043749} : {avg: real, rsd: real}
```

For memory usage, we exract the maximum resident set sizes as follows:

```
 $ grep 'maximum resident set size' bootstrap0-mlkit-v*.log  | grep -v v1 | sed -r 's/.* ([0-9]+)  maximum.*/\1/'
 ...
 $ grep 'maximum resident set size' bootstrap1-mlkit-v*.log  | grep -v v1 | sed -r 's/.* ([0-9]+)  maximum.*/\1/'
 ...
```

We calculate the average and relative standard deviation for the two
configurations as follows:

```
. val mlkit_rss_old = [734941184,734593024,734699520,735051776,734519296] |> map real |> Stat.average_rsd;
> val mlkit_rss_old = {avg=734760960.0,rsd=0.0309929829672} : {avg: real, rsd: real}
. val mlkit_rss_new = [570904576,571056128,570978304,571023360,570970112] |> map real |> Stat.average_rsd;
> val mlkit_rss_new = {avg=570986496.0,rsd=0.0100813260468} : {avg: real, rsd: real}
```

## Speedup and Memory Usage Improvement

Speedup (wall-clock times): 100.0 * (396.374 / 365.04 - 1.0) =  8.58 %

Memory usage improvement: 100.0 * (734760960.0 / 570986496.0 - 1.0) = 28.70 %

# Compiling MLton with Different Configurations of MLKit

Running `make mlton-compile` in this directory compiles MLton with the
different configurations of MLKit (MLKit and MLKit^dagger). It does so
5 times for each configuration. The running times and memory usage is
stored in log files:

- MLKit^dagger: `mlton-mlkit-comp-0-1.log` ... `mlton-mlkit-comp-0-5.log`

- MLKit: `mlton-mlkit-comp-1-1.log` ... `mlton-mlkit-comp-1-1.log`

We use the following terminal commands to extract wall-clock times
from the log files for MLKit^dagger and MLKit, respectively:

```
  $ grep ' real   ' mlton-mlkit-comp-0-*.log | sed -r 's/.* ([0-9]+.[0-9]+) real.*/\1/'
  ...
  $ grep ' real   ' mlton-mlkit-comp-1-*.log | sed -r 's/.* ([0-9]+.[0-9]+) real.*/\1/'
  ...
```

We can now use the tools in `tools.sml` to calculate the average and
relative standard deviation for the two configurations:

```
. val mlton_time_old = [1697.99,1699.10,1662.16,1637.81,1665.08] |> Stat.average_rsd;
> val mlton_time_old = {avg=1672.428,rsd=1.55997581946} : {avg: real, rsd: real}
. val mlton_time_new = [1572.79,1605.27,1558.58,1556.96,1517.82] |> Stat.average_rsd;
> val mlton_time_new = {avg=1562.284,rsd=2.01838182792} : {avg: real, rsd: real}
```

For memory usage, we exract the maximum resident set sizes as follows:

```
 $ grep 'maximum resident set size' mlton-mlkit-comp-0-*.log | sed -r 's/.* ([0-9]+)  maximum.*/\1/'
 ...
 $ grep 'maximum resident set size' mlton-mlkit-comp-1-*.log | sed -r 's/.* ([0-9]+)  maximum.*/\1/'
 ...
```

We calculate the average and relative standard deviation for the two
configurations as follows:

```
. val mlton_rss_old = [4856647680,4852195328,4835713024,4859981824,4852813824] |> map real |> Stat.average_rsd;
> val mlton_rss_old = {avg=4851470336.0,rsd=0.192775713294} : {avg: real, rsd: real}
. val mlton_rss_new = [4483158016,4483280896,4482895872,4482789376,4482818048] |> map real |> Stat.average_rsd;
> val mlton_rss_new = {avg=4482988441.6,rsd=0.00488094704236} : {avg: real, rsd: real}
```

## Speedup and Memory Usage Improvement

Speedup (wall-clock times): MLton Time: 7.05019061835

Memory usage improvement: MLton RSS: 8.21955932299

# Boxities

We can generate a boxity decision report from the generated log files
using `make boxity_report`:

```
-----------------------------------------------------------------------------------------------
Program / Compiler & hub & lub & enum & boxed & single k & single hub & single lub & single box
MLKit / MLKit Old  &   0 &  52 &   72 &   227 &       83 &          6 &         15 &         62
MLKit / MLKit New  & 127 &  52 &   72 &    45 &      138 &          7 &         16 &        115
MLton / MLKit Old  &   0 &  51 &  116 &   254 &      293 &          8 &         11 &        274
MLton / MLKit New  & 129 &  48 &  116 &   112 &      309 &          8 &         11 &        257
-----------------------------------------------------------------------------------------------
```

Notice that "MLKit Old" (also called MLKit^dagger) is compiled with
MLKit^dagger itself (bootstrapped) and generates code with high-bit
tagging disabled.
