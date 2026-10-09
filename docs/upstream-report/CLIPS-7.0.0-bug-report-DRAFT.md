# CLIPS 7.0.0: environment hangs under -O2 (strict-aliasing in the memory pool) + NULL `&ptr->header` in GetNext* functions

*DRAFT for John to review and send. Suggested channel: the CLIPS project on SourceForge (clipsrules — Discussion ▸ Help,
or the bug tracker), addressed to the maintainer. Attach `clips7_pool_repro.c` and `clips7_fix.patch` from this folder.*

---

**Subject:** CLIPS 7.0.0 hangs at -O2 in DeallocateFactData (memory-pool strict aliasing) — reproduction and two-line fix

Hello,

We embed CLIPS 7.0.0 (VERSION_STRING "7.0.0", CREATION_DATE_STRING "9/18/24") in a deterministic reasoning application
and found two defects while porting it to ARM64 Linux. Both are reproducible with the attached standalone program,
which uses only the public CLIPS API and no code of ours.

## 1. Hang (corrupted pool list) under optimisation

**Symptom.** Built with `-O2` (clang 21, aarch64 Linux), the program below hangs in its first round. A debugger shows
an infinite loop in `DeallocateFactData` (factmngr.c, the inner loop over a fact's `patternMatch` list), called from
`DestroyEnvironment`: the list has become circular. On x86_64 macOS the same build intermittently aborts instead, with
`nanov2_guard_corruption_detected` at a later, unrelated allocation.

**Isolation (same source, same machine):**

| Build of unmodified CLIPS 7.0.0 | 3,000 rounds of create / build / assert / run / destroy |
|---|---|
| `-O0` | completes |
| `-O2` | **hangs in round 0** |
| `-O2 -fno-strict-aliasing` | completes |
| `-O2`, memory pool disabled (`-DMEM_TABLE_SIZE=0`) | completes |
| `-O2`, only change: `may_alias` on `struct memoryPtr` | completes |

With the pool disabled, AddressSanitizer reports no error, so this is not a conventional double free: it needs both the
pool and optimisation.

**Cause.** The pool threads its free list through recycled blocks (`get_struct` / `rtn_struct`, `struct memoryPtr` in
memalloc.h): a block last used as one struct type is read and written as a `memoryPtr`. That is type punning, which C's
strict-aliasing rule permits the optimiser to reorder; under -O2 the reordering corrupts the lists.

**Suggested fix** (memalloc.h), which keeps the pool and full optimisation:

```c
#if defined(__GNUC__) || defined(__clang__)
#define CLIPS_MAY_ALIAS __attribute__((__may_alias__))
#else
#define CLIPS_MAY_ALIAS
#endif
struct CLIPS_MAY_ALIAS memoryPtr
  {
   struct memoryPtr *next;
  };
```

(Compiling with `-fno-strict-aliasing` also works, but cannot be required of every embedder — e.g. Swift Package Manager
forbids such flags in versioned dependencies.)

## 2. Undefined behaviour: `&ptr->header` with ptr == NULL

UndefinedBehaviorSanitizer reports, on every `CreateEnvironment`:

```
classcom.c:356: runtime error: member access within null pointer of type 'Defclass'
  GetNextDefclass ← CreateSystemClasses (classini.c) ← Clear (constrct.c) ← InitializeEnvironment ← CreateEnvironment
```

`GetNext<Construct>(theEnv, NULL)` means "first item", but nine such functions pass `&ptr->header` before
`GetNextConstructItem` tests for NULL. It works because `header` is at offset 0, but it is undefined behaviour and
licenses the optimiser to assume `ptr != NULL`. The same pattern is in classcom.c (GetNextDefclass), defins.c
(GetNextDefinstances), dffctdef.c (GetNextDeffacts), dffnxfun.c (GetNextDeffunction), genrccom.c (GetNextDefgeneric),
globldef.c (GetNextDefglobal), ruledef.c (GetNextDefrule), tabledef.c (GetNextDeftable), tmpltdef.c
(GetNextDeftemplate). Suggested form:

```c
return (Defclass *) GetNextConstructItem(theEnv,((theDefclass == NULL) ? NULL : &theDefclass->header),
                                         DefclassData(theEnv)->DefclassModuleIndex);
```

This one did not by itself cause the hang (`-fno-delete-null-pointer-checks` did not cure it), but it is real UB on
every environment creation.

## Reproduction

`clips7_pool_repro.c` (attached): two deftemplates, one rule, six facts, `Run`, `DestroyEnvironment`, in a loop.

```
cc -O2 -std=c99 -I<clips>/include <clips>/src/*.c clips7_pool_repro.c -lm -o repro
./repro 3000      # hangs at -O2 on aarch64 Linux; completes with either fix
```

Our copy of the sources has small local changes (a thread-local Eval depth counter, a platform define), so the attached
patch may need minor offsets against your tree; the two changes above are the whole fix.

Thank you for CLIPS — it has been a dependable foundation for our work.

John W. Miller
AppProved Software Corporation
