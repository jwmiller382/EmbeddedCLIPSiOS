//
//  swiftinterface.c
//  EmbeddedCLIPSiOS
//
//  Created by John W Miller on 12/19/24.
//

#include "embedded_clips.h"
#include "clips.h"
#include "router.h"
#include "globlbsc.h"
#include <string.h>
#include <stdio.h>

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

#define OUT(inst) ((inst)->output)
#define OUTSZ     CLIPS_OUTPUT_BUFFER_SIZE
#define ENV(inst) ((inst)->env)

#define GUARD(inst) do { \
    if ((inst) == NULL || ENV(inst) == NULL) return "Instance not initialized."; \
} while(0)

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

CLIPSInstance* clips_instance_create(void) {
    CLIPSInstance *inst = (CLIPSInstance *)malloc(sizeof(CLIPSInstance));
    if (inst == NULL) return NULL;
    memset(inst, 0, sizeof(CLIPSInstance));
    inst->env = CreateEnvironment();
    if (inst->env == NULL) {
        free(inst);
        return NULL;
    }
    return inst;
}

CLIPSInstance* clips_instance_create_with_file(const char* clpFilePath) {
    CLIPSInstance *inst = clips_instance_create();
    if (inst != NULL && clpFilePath != NULL) {
        Load(inst->env, clpFilePath);
    }
    return inst;
}

void clips_instance_destroy(CLIPSInstance* inst) {
    if (inst == NULL) return;
    if (inst->env != NULL) {
        DestroyEnvironment(inst->env);
        inst->env = NULL;
    }
    free(inst);
}

int clips_instance_is_valid(CLIPSInstance* inst) {
    return (inst != NULL && inst->env != NULL) ? 1 : 0;
}

const char* clips_instance_reset(CLIPSInstance* inst) {
    GUARD(inst);
    Reset(ENV(inst));
    return "Environment reset.";
}

const char* clips_instance_clear(CLIPSInstance* inst) {
    GUARD(inst);
    Clear(ENV(inst));
    return "Environment cleared.";
}

// ---------------------------------------------------------------------------
// Fact Management
// ---------------------------------------------------------------------------

const char* clips_instance_assert_fact(CLIPSInstance* inst, const char* fact) {
    GUARD(inst);
    Fact *f = AssertString(ENV(inst), fact);
    if (f == NULL) {
        snprintf(OUT(inst), OUTSZ, "Failed to assert fact: %s", fact);
    } else {
        snprintf(OUT(inst), OUTSZ, "Fact asserted: %s", fact);
    }
    return OUT(inst);
}

const char* clips_instance_retract_fact(CLIPSInstance* inst, long long factIndex) {
    GUARD(inst);
    Fact *fact = GetNextFact(ENV(inst), NULL);
    while (fact != NULL) {
        if (fact->factIndex == factIndex) {
            Retract(fact);
            snprintf(OUT(inst), OUTSZ, "Fact retracted: %lld", factIndex);
            return OUT(inst);
        }
        fact = GetNextFact(ENV(inst), fact);
    }
    snprintf(OUT(inst), OUTSZ, "Fact not found: %lld", factIndex);
    return OUT(inst);
}

const char* clips_instance_get_all_facts(CLIPSInstance* inst) {
    GUARD(inst);
    memset(OUT(inst), 0, OUTSZ);
    OpenStringDestination(ENV(inst), "stdout", OUT(inst), OUTSZ);
    Facts(ENV(inst), "stdout", NULL, 0, -1, -1);
    CloseStringDestination(ENV(inst), "stdout");
    return OUT(inst);
}

// ---------------------------------------------------------------------------
// Template Management
// ---------------------------------------------------------------------------

const char* clips_instance_define_template(CLIPSInstance* inst, const char* def) {
    GUARD(inst);
    if (Build(ENV(inst), def) == BE_NO_ERROR) {
        snprintf(OUT(inst), OUTSZ, "Template defined successfully.");
    } else {
        snprintf(OUT(inst), OUTSZ, "Failed to define template.");
    }
    return OUT(inst);
}

// ---------------------------------------------------------------------------
// Rule Management
// ---------------------------------------------------------------------------

const char* clips_instance_define_rule(CLIPSInstance* inst, const char* def) {
    GUARD(inst);
    if (Build(ENV(inst), def) == BE_NO_ERROR) {
        snprintf(OUT(inst), OUTSZ, "Rule defined successfully.");
    } else {
        snprintf(OUT(inst), OUTSZ, "Failed to define rule.");
    }
    return OUT(inst);
}

const char* clips_instance_deactivate_rule(CLIPSInstance* inst, const char* name) {
    GUARD(inst);
    Defrule *rule = FindDefrule(ENV(inst), name);
    if (rule == NULL) {
        snprintf(OUT(inst), OUTSZ, "Rule not found: %s", name);
    } else {
        ClearRuleFromAgenda(ENV(inst), rule);
        snprintf(OUT(inst), OUTSZ, "Rule activations cleared from agenda: %s", name);
    }
    return OUT(inst);
}

// ---------------------------------------------------------------------------
// Agenda Management
// ---------------------------------------------------------------------------

const char* clips_instance_get_agenda(CLIPSInstance* inst) {
    GUARD(inst);
    memset(OUT(inst), 0, OUTSZ);
    OpenStringDestination(ENV(inst), "stdout", OUT(inst), OUTSZ);
    Agenda(ENV(inst), "stdout", NULL);
    CloseStringDestination(ENV(inst), "stdout");
    return OUT(inst);
}

const char* clips_instance_refresh_agenda(CLIPSInstance* inst) {
    GUARD(inst);
    RefreshAgenda(ENV(inst));
    return "Agenda refreshed.";
}

const char* clips_instance_clear_rule_from_agenda(CLIPSInstance* inst, const char* name) {
    GUARD(inst);
    Defrule *rule = FindDefrule(ENV(inst), name);
    if (rule == NULL) {
        snprintf(OUT(inst), OUTSZ, "Rule not found: %s", name);
    } else {
        ClearRuleFromAgenda(ENV(inst), rule);
        snprintf(OUT(inst), OUTSZ, "Rule cleared from agenda: %s", name);
    }
    return OUT(inst);
}

// ---------------------------------------------------------------------------
// Execution Control
// ---------------------------------------------------------------------------

const char* clips_instance_run(CLIPSInstance* inst, long long limit) {
    GUARD(inst);
    memset(OUT(inst), 0, OUTSZ);
    OpenStringDestination(ENV(inst), "stdout", OUT(inst), OUTSZ);
    Run(ENV(inst), limit);
    CloseStringDestination(ENV(inst), "stdout");
    return OUT(inst);
}

void clips_instance_halt(CLIPSInstance* inst) {
    if (inst != NULL && ENV(inst) != NULL) {
        Halt(ENV(inst));
    }
}

// ---------------------------------------------------------------------------
// Debugging
// ---------------------------------------------------------------------------

void clips_instance_enable_watch(CLIPSInstance* inst, const char* item, int enable) {
    if (inst != NULL && ENV(inst) != NULL) {
        SetWatchItem(ENV(inst), item, enable, NULL);
    }
}

// ---------------------------------------------------------------------------
// Global Variables
// ---------------------------------------------------------------------------

const char* clips_instance_define_global(CLIPSInstance* inst, const char* def) {
    GUARD(inst);
    if (Build(ENV(inst), def) == BE_NO_ERROR) {
        snprintf(OUT(inst), OUTSZ, "Global defined successfully.");
    } else {
        snprintf(OUT(inst), OUTSZ, "Failed to define global.");
    }
    return OUT(inst);
}

const char* clips_instance_get_global(CLIPSInstance* inst, const char* name) {
    GUARD(inst);
    Defglobal *global = GetNextDefglobal(ENV(inst), NULL);
    while (global != NULL) {
        const char *globalName = global->header.name->contents;
        if (strcmp(globalName, name) == 0) {
            CLIPSValue *val = &global->current.value;
            switch (val->header->type) {
                case STRING_TYPE:
                case SYMBOL_TYPE:
                    snprintf(OUT(inst), OUTSZ, "%s", val->lexemeValue->contents);
                    break;
                case INTEGER_TYPE:
                    snprintf(OUT(inst), OUTSZ, "%lld", val->integerValue->contents);
                    break;
                case FLOAT_TYPE:
                    snprintf(OUT(inst), OUTSZ, "%f", val->floatValue->contents);
                    break;
                default:
                    snprintf(OUT(inst), OUTSZ, "[Unsupported type]");
                    break;
            }
            return OUT(inst);
        }
        global = GetNextDefglobal(ENV(inst), global);
    }
    snprintf(OUT(inst), OUTSZ, "Global not found: %s", name);
    return OUT(inst);
}

const char* clips_instance_set_global(CLIPSInstance* inst, const char* name, const char* value) {
    GUARD(inst);
    Defglobal *global = GetNextDefglobal(ENV(inst), NULL);
    while (global != NULL) {
        const char *globalName = global->header.name->contents;
        if (strcmp(globalName, name) == 0) {
            const char* variableName = DefglobalName(global);
            char command[512];
            snprintf(command, sizeof(command), "(bind ?*%s* %s)", variableName, value);
            Eval(ENV(inst), command, NULL);
            snprintf(OUT(inst), OUTSZ, "Global value set: %s = %s", name, value);
            return OUT(inst);
        }
        global = GetNextDefglobal(ENV(inst), global);
    }
    snprintf(OUT(inst), OUTSZ, "Global not found: %s", name);
    return OUT(inst);
}

// ---------------------------------------------------------------------------
// Batch Processing
// ---------------------------------------------------------------------------

const char* clips_instance_batch(CLIPSInstance* inst, const char* filename) {
    GUARD(inst);
    if (Batch(ENV(inst), filename)) {
        snprintf(OUT(inst), OUTSZ, "Batch file executed: %s", filename);
    } else {
        snprintf(OUT(inst), OUTSZ, "Failed to execute batch file: %s", filename);
    }
    return OUT(inst);
}

// ---------------------------------------------------------------------------
// Save and Load State
// ---------------------------------------------------------------------------

const char* clips_instance_save_facts(CLIPSInstance* inst, const char* filename) {
    GUARD(inst);
    if (SaveFacts(ENV(inst), filename, LOCAL_SAVE) != -1) {
        snprintf(OUT(inst), OUTSZ, "Facts saved to file: %s", filename);
    } else {
        snprintf(OUT(inst), OUTSZ, "Failed to save facts to file: %s", filename);
    }
    return OUT(inst);
}

const char* clips_instance_load_facts(CLIPSInstance* inst, const char* filename) {
    GUARD(inst);
    if (LoadFacts(ENV(inst), filename) != -1) {
        snprintf(OUT(inst), OUTSZ, "Facts loaded from file: %s", filename);
    } else {
        snprintf(OUT(inst), OUTSZ, "Failed to load facts from file: %s", filename);
    }
    return OUT(inst);
}

const char* clips_instance_save_environment(CLIPSInstance* inst, const char* filename) {
    GUARD(inst);
    if (Save(ENV(inst), filename)) {
        snprintf(OUT(inst), OUTSZ, "Environment saved to file: %s", filename);
    } else {
        snprintf(OUT(inst), OUTSZ, "Failed to save environment to file: %s", filename);
    }
    return OUT(inst);
}

const char* clips_instance_load_environment(CLIPSInstance* inst, const char* filename) {
    GUARD(inst);
    if (Load(ENV(inst), filename) == LE_NO_ERROR) {
        snprintf(OUT(inst), OUTSZ, "Environment loaded from file: %s", filename);
    } else {
        snprintf(OUT(inst), OUTSZ, "Failed to load environment from file: %s", filename);
    }
    return OUT(inst);
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

const char* clips_instance_evaluate(CLIPSInstance* inst, const char* expression) {
    GUARD(inst);
    CLIPSValue result;
    if (Eval(ENV(inst), expression, &result) == EE_NO_ERROR) {
        switch (result.header->type) {
            case STRING_TYPE:
            case SYMBOL_TYPE:
                snprintf(OUT(inst), OUTSZ, "%s", result.lexemeValue->contents);
                break;
            case INTEGER_TYPE:
                snprintf(OUT(inst), OUTSZ, "%lld", result.integerValue->contents);
                break;
            case FLOAT_TYPE:
                snprintf(OUT(inst), OUTSZ, "%f", result.floatValue->contents);
                break;
            case VOID_TYPE:
                OUT(inst)[0] = '\0';
                break;
            default:
                snprintf(OUT(inst), OUTSZ, "[Unsupported result type]");
                break;
        }
    } else {
        snprintf(OUT(inst), OUTSZ, "Error evaluating expression: %s", expression);
    }
    return OUT(inst);
}

const char* clips_instance_execute_command(CLIPSInstance* inst, const char* command) {
    GUARD(inst);
    CLIPSValue result;
    memset(OUT(inst), 0, OUTSZ);
    OpenStringDestination(ENV(inst), "stdout", OUT(inst), OUTSZ);

    if (Eval(ENV(inst), command, &result) != EE_NO_ERROR) {
        CloseStringDestination(ENV(inst), "stdout");
        snprintf(OUT(inst), OUTSZ, "Eval failed for command: %s", command);
    } else {
        CloseStringDestination(ENV(inst), "stdout");
        switch (result.header->type) {
            case STRING_TYPE:
            case SYMBOL_TYPE:
                snprintf(OUT(inst), OUTSZ, "%s", result.lexemeValue->contents);
                break;
            case INTEGER_TYPE:
                snprintf(OUT(inst), OUTSZ, "%lld", result.integerValue->contents);
                break;
            case FLOAT_TYPE:
                snprintf(OUT(inst), OUTSZ, "%f", result.floatValue->contents);
                break;
            case VOID_TYPE:
                break;
            default:
                break;
        }
    }
    return OUT(inst);
}

const char* clips_instance_build(CLIPSInstance* inst, const char* construct) {
    GUARD(inst);
    if (Build(ENV(inst), construct) == BE_NO_ERROR) {
        return "Build successful.";
    } else {
        return "Build failed.";
    }
}
