#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#include "../src/dsp/superboom.c"

int main(void) {
    superboom_t *source = create_instance(NULL, NULL);
    superboom_t *restored = create_instance(NULL, NULL);
    assert(source && restored);

    for (int i = 0; i < STATE_KEY_COUNT; i++) {
        char value[32];
        snprintf(value, sizeof(value), "%.4f", 0.137 + (i % 7) * 0.113);
        set_param(source, state_keys[i], value);
    }

    char state[4096];
    assert(get_param(source, "state", state, sizeof(state)) > 0);
    set_param(restored, "state", state);

    for (int i = 0; i < STATE_KEY_COUNT; i++) {
        char expected[64], actual[64];
        assert(get_param(source, state_keys[i], expected, sizeof(expected)) > 0);
        assert(get_param(restored, state_keys[i], actual, sizeof(actual)) > 0);
        if (strcmp(expected, actual) != 0) {
            fprintf(stderr, "%s: expected %s, got %s\n",
                    state_keys[i], expected, actual);
            return 1;
        }
    }

    char too_small[32];
    assert(get_param(source, "state", too_small, sizeof(too_small)) < 0);
    destroy_instance(source);
    destroy_instance(restored);
    puts("PASS: all SuperBoom controls round-trip through state");
    return 0;
}
