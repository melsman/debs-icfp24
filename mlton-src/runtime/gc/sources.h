/* Copyright (C) 2019,2021 Matthew Fluet.
 * Copyright (C) 1999-2006 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 */

#if (defined (MLTON_GC_INTERNAL_TYPES))

typedef uint32_t GC_sourceNameIndex;
#define PRISNI PRIu32
#define FMTSNI "%"PRISNI

typedef uint32_t GC_sourceSeqIndex;
#define PRISSI PRIu32
#define FMTSSI "%"PRISSI

#define UNKNOWN_SOURCE_SEQ_INDEX  0
#define GC_SOURCE_SEQ_INDEX       1

typedef uint32_t GC_sourceIndex;
#define PRISI PRIu32
#define FMTSI "%"PRISI

#define UNKNOWN_SOURCE_INDEX  0
#define GC_SOURCE_INDEX       1

typedef const struct GC_source {
  const GC_sourceNameIndex sourceNameIndex;
  const GC_sourceSeqIndex successorSourceSeqIndex;
} *GC_source;

struct GC_sourceMaps {
  volatile GC_sourceSeqIndex curSourceSeqIndex;
  /* sourceNames is an array of cardinality sourceNamesLength;
   * the collection of source names from the program.
   */
  const char * const *sourceNames;
  uint32_t sourceNamesLength;
  /* sourceSeqs is an array of cardinality sourceSeqsLength;
   * each entry describes a sequence of source names as a length
   * followed by the sequence of indices into sources.
   */
  const uint32_t * const *sourceSeqs;
  uint32_t sourceSeqsLength;
  /* sources is an array of cardinality sourcesLength;
   * each entry describes a source name and successor sources as
   * the pair of an index into sourceNames and an index into
   * sourceSeqs.
   */
  GC_source sources;
  uint32_t sourcesLength;
};

#endif /* (defined (MLTON_GC_INTERNAL_TYPES)) */

#if (defined (MLTON_GC_INTERNAL_FUNCS))

static inline GC_sourceSeqIndex getCachedStackTopFrameSourceSeqIndex (GC_state s);

static inline const char * getSourceName (GC_state s, GC_sourceIndex i);

static void showSources (GC_state s);

#endif /* (defined (MLTON_GC_INTERNAL_FUNCS)) */

#if (defined (MLTON_GC_INTERNAL_BASIS))

PRIVATE const char * GC_sourceName (GC_state s, GC_sourceIndex i);

#endif /* (defined (MLTON_GC_INTERNAL_BASIS)) */
