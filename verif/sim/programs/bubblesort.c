// Branch-heavy benchmark for the branch predictor.
//
// Bubble sort is O(n^2) data-dependent branches: the inner-loop compare is taken
// or not depending on the data, so it's exactly what stresses a predictor. The
// fill is a seeded xorshift PRNG — random-LOOKING, so the branch pattern is
// realistic, but fully DETERMINISTIC, so CPI is reproducible across runs. That
// reproducibility is what makes a before/after predictor comparison valid.
//
// xorshift is pure XOR and shift: no multiply or divide, so nothing pulls in
// libgcc under -nostdlib.
//
// Self-checking: returns 0 (pass) iff the array ends up sorted. So it's both a
// benchmark and a correctness test.

#define N 64

static int arr[N];

static unsigned rng = 0x2468ace1u;

static unsigned rnd(void) {
    unsigned x = rng;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    rng = x;
    return x;
}

int main(void) {
    for (int i = 0; i < N; i++) {
        arr[i] = (int)(rnd() & 0x7fff);   // keep positive so signed compare is clean
    }

    for (int i = 0; i < N - 1; i++) {
        for (int j = 0; j < N - 1 - i; j++) {
            if (arr[j] > arr[j + 1]) {
                int t = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = t;
            }
        }
    }

    for (int i = 0; i < N - 1; i++) {
        if (arr[i] > arr[i + 1]) return 1;   // not sorted → fail
    }
    return 0;
}
