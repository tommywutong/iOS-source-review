#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "Generated"
N = 4096
SPARSE_N = 128


def write(path: Path, text: str):
    path.mkdir(parents=True, exist_ok=True)
    (path / "payload.c").write_text(text)


def rebase_dense():
    decls = "\n".join(f"static __attribute__((noinline)) void rebase_target_{i}(void) {{}}" for i in range(SPARSE_N))
    ptrs = ",\n    ".join(f"rebase_target_{i}" for i in range(SPARSE_N))
    return f'''#include <stddef.h>\n{decls}\n__attribute__((used)) static void (*const pointers[])(void) = {{\n    {ptrs}\n}};\nvoid dyldlab_rebase_dense_marker(void) {{ (void)pointers[0]; }}\n'''


def rebase_sparse():
    decls = "\n".join(f"static __attribute__((noinline)) void rebase_sparse_target_{i}(void) {{}}" for i in range(SPARSE_N))
    slots = "\n".join(f"    [ {i} ] = {{ rebase_sparse_target_{i} }}," for i in range(SPARSE_N))
    return f'''#include <stddef.h>\n{decls}\nstruct slot {{ void (*target)(void); unsigned char padding[16376]; }};\n__attribute__((used)) static const struct slot pointers[{SPARSE_N}] = {{\n{slots}\n}};\nvoid dyldlab_rebase_sparse_marker(void) {{ (void)pointers[0].target; }}\n'''


def provider():
    funcs = "\n".join(f"__attribute__((visibility(\"default\"), noinline)) void provider_symbol_{i}(void) {{}}" for i in range(N))
    return f'''{funcs}\n'''


def bind_payload(name: str, unique: bool):
    decls = "\n".join(f"extern void provider_symbol_{i}(void);" for i in range(N))
    target = ",\n    ".join(f"provider_symbol_{i}" if unique else "provider_symbol_0" for i in range(N))
    marker = "dyldlab_bind_unique_marker" if unique else "dyldlab_bind_repeated_marker"
    return f'''#include <stddef.h>\n{decls}\n__attribute__((used)) static void (*const pointers[{N}])(void) = {{\n    {target}\n}};\nvoid {marker}(void) {{ (void)pointers[0]; }}\n'''

write(OUT / "RebaseDense", rebase_dense())
write(OUT / "RebaseSparse", rebase_sparse())
write(OUT / "BindProvider", provider())
write(OUT / "BindRepeated", bind_payload("BindRepeated", False))
write(OUT / "BindUnique", bind_payload("BindUnique", True))
print(f"generated {N} bind slots and {SPARSE_N} rebase slots")
