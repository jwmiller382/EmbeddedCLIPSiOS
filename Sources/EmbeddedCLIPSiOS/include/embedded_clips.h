//
//  embedded_clips.h
//  EmbeddedCLIPSiOS
//
//  Created by John W Miller on 12/19/24.
//

#ifndef _H_EMBEDDED_CLIPS
#define _H_EMBEDDED_CLIPS

#include "clips.h"
#include <stdlib.h>

// ---------------------------------------------------------------------------
// Instance-based API
//
// Each CLIPSInstance owns its own CLIPS Environment and output buffer,
// so multiple instances can coexist safely (one per thread).
// ---------------------------------------------------------------------------

#define CLIPS_OUTPUT_BUFFER_SIZE 4096

typedef struct {
    Environment *env;
    char output[CLIPS_OUTPUT_BUFFER_SIZE];
} CLIPSInstance;

// Lifecycle
CLIPSInstance* clips_instance_create(void);
CLIPSInstance* clips_instance_create_with_file(const char* clpFilePath);
void           clips_instance_destroy(CLIPSInstance* inst);
int            clips_instance_is_valid(CLIPSInstance* inst);
const char*    clips_instance_reset(CLIPSInstance* inst);
const char*    clips_instance_clear(CLIPSInstance* inst);

// Fact Management
const char* clips_instance_assert_fact(CLIPSInstance* inst, const char* fact);
const char* clips_instance_retract_fact(CLIPSInstance* inst, long long factIndex);
const char* clips_instance_get_all_facts(CLIPSInstance* inst);

// Template Management
const char* clips_instance_define_template(CLIPSInstance* inst, const char* def);

// Rule Management
const char* clips_instance_define_rule(CLIPSInstance* inst, const char* def);
const char* clips_instance_deactivate_rule(CLIPSInstance* inst, const char* name);

// Agenda Management
const char* clips_instance_get_agenda(CLIPSInstance* inst);
const char* clips_instance_refresh_agenda(CLIPSInstance* inst);
const char* clips_instance_clear_rule_from_agenda(CLIPSInstance* inst, const char* name);

// Execution Control
const char* clips_instance_run(CLIPSInstance* inst, long long limit);
void        clips_instance_halt(CLIPSInstance* inst);

// Debugging
void clips_instance_enable_watch(CLIPSInstance* inst, const char* item, int enable);

// Global Variables
const char* clips_instance_define_global(CLIPSInstance* inst, const char* def);
const char* clips_instance_get_global(CLIPSInstance* inst, const char* name);
const char* clips_instance_set_global(CLIPSInstance* inst, const char* name, const char* value);

// Batch Processing
const char* clips_instance_batch(CLIPSInstance* inst, const char* filename);

// Save and Load State
const char* clips_instance_save_facts(CLIPSInstance* inst, const char* filename);
const char* clips_instance_load_facts(CLIPSInstance* inst, const char* filename);
const char* clips_instance_save_environment(CLIPSInstance* inst, const char* filename);
const char* clips_instance_load_environment(CLIPSInstance* inst, const char* filename);

// Utility
const char* clips_instance_evaluate(CLIPSInstance* inst, const char* expression);
const char* clips_instance_execute_command(CLIPSInstance* inst, const char* command);
const char* clips_instance_build(CLIPSInstance* inst, const char* construct);

#endif /* _H_EMBEDDED_CLIPS */
