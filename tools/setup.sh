#!/usr/bin/env bash
# Builds everything the formal flow needs beyond `yosys`/`verilator`/`z3`
# themselves, all inside tools/ so nothing depends on paths outside this repo.
# Safe to re-run: each step skips if its output already exists.
#
#   tools/riscv-formal/      the check/instruction models, cloned at a pinned commit
#   tools/yosys-slang/       SystemVerilog frontend plugin, built here
#   tools/yices/             SMT solver, downloaded prebuilt
#   tools/sby/               SymbiYosys, patched and built here
#   tools/bin/sby            watchdog wrapper (committed, no build step --
#                            see the file itself for why it exists)
#
# yosys/verilator/z3 stay system installs, checked but not vendored -- same
# tier as gcc, not something a project should build for you.

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS="$(nproc 2>/dev/null || echo 4)"

pass() { printf '  [ok]   %s\n' "$1"; }
skip() { printf '  [skip] %s (already built)\n' "$1"; }
step() { printf '\n== %s ==\n' "$1"; }

step "checking system prerequisites"
missing=0
for t in yosys verilator git make g++ python3; do
  if command -v "$t" >/dev/null; then
    pass "$t: $(command -v "$t")"
  else
    printf '  [MISSING] %s\n' "$t"
    missing=1
  fi
done
if [ "$missing" = 1 ]; then
  echo "install the missing tools above, then re-run this script" >&2
  exit 1
fi

if command -v z3 >/dev/null; then
  pass "z3: $(command -v z3) (optional fallback engine)"
else
  echo "  [note] z3 not found -- optional fallback engine, formal-run still works without it"
fi

if ! command -v cmake >/dev/null || ! command -v ninja >/dev/null; then
  step "installing cmake/ninja (user-local, needed to build yosys-slang)"
  python3 -m pip install --user --quiet cmake ninja
fi
export PATH="$HOME/.local/bin:$PATH"

step "riscv-formal (check generator and instruction models)"
# Pinned, not tracking master: the generated check set and the invariants in
# verif/formal are written against this exact revision of insns/ and checks/.
# A moving upstream would silently change what "43/43 passing" means.
RISCV_FORMAL_REF="${RISCV_FORMAL_REF:-c992aa61fdfe0846c5ed90324c596202a1c69b76}"
RF_DIR="$TOOLS_DIR/riscv-formal"
if [ -d "$RF_DIR/checks" ]; then
  skip "riscv-formal"
else
  rm -rf "$RF_DIR"
  # Fetching the SHA directly keeps this to one commit instead of the full
  # history; GitHub allows it, a plain `clone --depth 1` cannot take a SHA.
  git init -q "$RF_DIR"
  git -C "$RF_DIR" remote add origin https://github.com/YosysHQ/riscv-formal.git
  git -C "$RF_DIR" fetch -q --depth 1 origin "$RISCV_FORMAL_REF"
  git -C "$RF_DIR" checkout -q FETCH_HEAD
  pass "riscv-formal at ${RISCV_FORMAL_REF:0:12}"
fi

step "yosys-slang (SystemVerilog frontend plugin)"
SLANG_SO="$TOOLS_DIR/yosys-slang/build/slang.so"
if [ -f "$SLANG_SO" ]; then
  skip "yosys-slang"
else
  rm -rf "$TOOLS_DIR/yosys-slang"
  git clone --recursive --depth 1 https://github.com/povik/yosys-slang.git "$TOOLS_DIR/yosys-slang"
  cmake -S "$TOOLS_DIR/yosys-slang" -B "$TOOLS_DIR/yosys-slang/build" -G Ninja -DCMAKE_BUILD_TYPE=Release
  cmake --build "$TOOLS_DIR/yosys-slang/build" -j "$JOBS"
  pass "built $SLANG_SO"
fi

step "yices2 (SMT solver)"
YICES_BIN="$TOOLS_DIR/yices/bin/yices-smt2"
if [ -f "$YICES_BIN" ]; then
  skip "yices2"
else
  mkdir -p "$TOOLS_DIR/yices"
  curl -sL -o /tmp/yices.tar.gz \
    https://github.com/SRI-CSL/yices2/releases/download/Yices-2.6.4/yices-2.6.4-x86_64-pc-linux-gnu.tar.gz
  tar xzf /tmp/yices.tar.gz -C /tmp
  cp -r /tmp/yices-2.6.4/bin /tmp/yices-2.6.4/lib "$TOOLS_DIR/yices/"
  rm -rf /tmp/yices.tar.gz /tmp/yices-2.6.4
  pass "installed $YICES_BIN"
fi

step "sby (SymbiYosys, patched)"
SBY_BIN="$TOOLS_DIR/sby/bin/sby"
if [ -f "$SBY_BIN" ]; then
  skip "sby"
else
  rm -rf "$TOOLS_DIR/sby-src"
  git clone --depth 1 https://github.com/YosysHQ/sby.git "$TOOLS_DIR/sby-src"
  # Fixes `abc pdr` (unused unless FORMAL_ENGINES includes it): sby's own aiger
  # script runs setundef before aigmap, but aigmap can reintroduce x/z bits that
  # write_aiger then rejects. See tools/patches/sby-aigmap-setundef.patch.
  patch -p0 -d "$TOOLS_DIR/sby-src" < "$TOOLS_DIR/patches/sby-aigmap-setundef.patch"
  make -C "$TOOLS_DIR/sby-src" install PREFIX="$TOOLS_DIR/sby"
  rm -rf "$TOOLS_DIR/sby-src"
  pass "built $SBY_BIN"
fi

step "done"
echo "tools/riscv-formal, tools/yosys-slang, tools/yices, tools/sby are ready."
echo "Run 'make formal-gen && make formal-run' from the repo root."
