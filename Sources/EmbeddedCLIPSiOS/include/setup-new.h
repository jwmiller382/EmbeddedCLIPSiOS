//
//  setup.h
//  EmbeddedCLIPSiOS
//
//  Created by John W Miller on 12/20/24.
//

/* Setup Configuration for Embedded CLIPS */

/* Enable Basic Constructs */
#define DEFRULE_CONSTRUCT 1          /* Enable defrule for rule definitions */
#define DEFTEMPLATE_CONSTRUCT 1      /* Enable deftemplate for defining templates */
#define DEFFACTS_CONSTRUCT 1         /* Enable deffacts for predefined facts */
#define DEFGLOBAL_CONSTRUCT 1        /* Enable defglobal for global variables */

/* Enable Fact Management */
#define FACT_MGR 1                   /* Enable fact management subsystem */

/* Enable Debugging Support */
#define DEBUGGING_FUNCTIONS 1        /* Enable debugging features (e.g., agenda, rules) */

/* Enable Object-Oriented Features (Optional) */
#define OBJECT_SYSTEM 1              /* Enable object system for defining classes and objects */

/* Enable Loading and Saving */
#define BLOAD_AND_BSAVE 1            /* Enable both binary loading and saving */
#define BLOAD 1                      /* Enable binary loading */
#define BSAVE 1                      /* Enable binary saving */

/* Enable Constraint Checking */
#define CONSTRAINT_CHECKING 1        /* Enable runtime constraint checking */

/* Enable Miscellaneous Features */
#define EXTENDED_MATH_FUNCTIONS 1    /* Enable extended math functions */
#define MULTIFIELD_FUNCTIONS 1       /* Enable multifield manipulation functions */

/* Disable Deprecated Features */
#define OLD_CONSTRUCTS 0             /* Disable old/deprecated constructs */

/* Platform-Specific Configurations */
#ifdef __APPLE__
    #define APPLE_ENVIRONMENT 1     /* Enable Apple-specific configurations */
#endif

/* End of Configuration */
