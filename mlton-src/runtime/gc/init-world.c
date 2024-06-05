/* Copyright (C) 2011-2012,2014,2016,2020 Matthew Fluet.
 * Copyright (C) 1999-2008 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 */

/* ---------------------------------------------------------------- */
/*                          Initialization                          */
/* ---------------------------------------------------------------- */

size_t sizeofInitialBytesLive (GC_state s) {
  size_t total;

  total = 0;
  total += s->staticHeaps.dynamic.size;
  total += sizeofStackWithMetaData (s, sizeofStackInitialReserved (s)) + sizeofThread (s);
  return total;
}

void initWorld (GC_state s) {
  pointer start;
  GC_thread thread;

  s->lastMajorStatistics.bytesLive = sizeofInitialBytesLive (s);
  createHeap (s, &s->heap,
              sizeofHeapDesired (s, s->lastMajorStatistics.bytesLive, 0),
              s->lastMajorStatistics.bytesLive);
  setCardMapAndCrossMap (s);
  start = alignFrontier (s, s->heap.start);
  s->frontier = start;
  s->limitPlusSlop = s->heap.start + s->heap.size;
  s->limit = s->limitPlusSlop - GC_HEAP_LIMIT_SLOP;
  GC_memcpy (s->staticHeaps.dynamic.start, start, s->staticHeaps.dynamic.size);
  s->frontier = start + s->staticHeaps.dynamic.size;
  translateHeap (s, s->staticHeaps.dynamic.start, start, s->staticHeaps.dynamic.size);
  assert ((size_t)(s->frontier - start) <= s->lastMajorStatistics.bytesLive);
  s->heap.oldGenSize = (size_t)(s->frontier - s->heap.start);
  setGCStateCurrentHeap (s, 0, 0);
  thread = newThread (s, sizeofStackInitialReserved (s));
  switchToThread (s, pointerToObjptr((pointer)thread - offsetofThread (s), s->heap.start));
}
