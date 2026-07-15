// State machine — branch character: irregular, CORRELATED control flow.
//
// The next branch outcome depends on the current state, which depends on the
// history of previous tokens. That correlation is exactly what a global-history
// predictor (gshare) exploits and a per-PC 2-bit counter cannot — so this is the
// workload where the two predictors will eventually diverge.
//
// count is deterministic for a fixed seed; EXPECTED is baked in as the self-check.

#define STEPS 4000
#define EXPECTED_COUNT 62   // computed for seed 0x0f1e2d3c; see host reference

static unsigned rng = 0x0f1e2d3cu;

static unsigned rnd(void) {
    unsigned x = rng;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    rng = x;
    return x;
}

int main(void) {
    int state = 0;
    int count = 0;

    for (int i = 0; i < STEPS; i++) {
        int tok = (int)(rnd() & 0x3);     // 0..3

        switch (state) {
            case 0:
                if (tok == 0) state = 1;
                break;
            case 1:
                if (tok == 1)      state = 2;
                else if (tok == 0) state = 1;
                else               state = 0;
                break;
            case 2:
                if (tok == 2) { count++; state = 0; }
                else          state = 0;
                break;
        }
    }

    return (count == EXPECTED_COUNT) ? 0 : 1;
}
