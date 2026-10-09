/* Standalone CLIPS 7.0.0 reproduction: create / use / destroy environments in a loop.
   Build: cc -O2 -std=c99 -Iinclude src/*.c repro.c -lm   (CLIPS sources, main.c excluded) */
#include <stdio.h>
#include <stdlib.h>
#include "clips.h"

static const char *CONSTRUCTS[] = {
  "(deftemplate atom (slot id) (slot el) (slot open (default 1)))",
  "(deftemplate bond (slot a) (slot b) (slot order))",
  "(defrule pair ?x <- (atom (id ?i) (el ?e) (open ?o&:(> ?o 0))) ?y <- (atom (id ?j&:(> ?j ?i)) (open ?p&:(> ?p 0)))"
  "  (not (bond (a ?i) (b ?j))) => (modify ?x (open (- ?o 1))) (modify ?y (open (- ?p 1))) (assert (bond (a ?i) (b ?j) (order 1))))",
  NULL };

int main(int argc, char **argv) {
  int rounds = argc > 1 ? atoi(argv[1]) : 2000;
  for (int r = 0; r < rounds; r++) {
    Environment *env = CreateEnvironment();
    for (int k = 0; CONSTRUCTS[k]; k++) Build(env, CONSTRUCTS[k]);
    Reset(env);
    char buf[128];
    for (int i = 0; i < 6; i++) { snprintf(buf, sizeof buf, "(atom (id %d) (el %s) (open %d))", i, i % 2 ? "H" : "N", 1 + i % 3); AssertString(env, buf); }
    Run(env, -1);
    DestroyEnvironment(env);
    if (r % 250 == 0) { printf("round %d ok\n", r); fflush(stdout); }
  }
  printf("ALL %d ROUNDS COMPLETED\n", rounds);
  return 0;
}
