// Linear search — branch character: early-exit loops.
//
// Different from bubble sort: the inner loop's equality branch is not-taken until
// the hit, then taken once. Every key is guaranteed present (picked FROM the
// array), so the search must always succeed — that invariant is the self-check.
//
// N is a power of two so the index pick uses a mask, not a divide (RV32I has no
// division without libgcc).

#define N 128
#define Q 64

static int arr[N];

static unsigned rng = 0x13572468u;

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
        arr[i] = (int)(rnd() & 0xff);
    }

    int found = 0;
    for (int q = 0; q < Q; q++) {
        int key = arr[rnd() & (N - 1)];   // guaranteed to be in the array

        int hit = 0;
        for (int i = 0; i < N; i++) {
            if (arr[i] == key) {          // early-exit branch
                hit = 1;
                break;
            }
        }
        if (hit) found++;
    }

    return (found == Q) ? 0 : 1;          // every key must be found
}
