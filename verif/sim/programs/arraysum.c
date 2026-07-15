// Level 4: a real C program, compiled by a real compiler.
//
// The point is NOT the arithmetic. It is that gcc allocates registers, builds a
// stack frame, returns via jalr, and picks load/store offsets that no hand-written
// test would have chosen. Directed tests share the author's blind spots. A
// compiler does not have them.
//
// Note the multiply: RV32I has no MUL instruction. See the README for what gcc
// does about that.

#define N 16

static int arr[N];

// Written to a fixed address so the result is observable in data memory, not just
// in a register. volatile stops gcc from optimising the store away.
static volatile int *const result = (volatile int *)0x800;

int main(void) {
    int sum = 0;

    for (int i = 0; i < N; i++) {
        arr[i] = i * 3 + 1;
    }

    for (int i = 0; i < N; i++) {
        sum += arr[i];
    }

    *result = sum;

    // sum of (3i + 1) for i = 0..15  =  3*120 + 16  =  376
    return (*result == 376) ? 0 : 1;
}
