#!/usr/bin/env python3
import re
import subprocess
import sys
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit("usage: analyze_macho.py <variant> <mach-o>")

variant, image = sys.argv[1:]
output = subprocess.check_output(
    ["xcrun", "dyld_info", "-fixup_chains", "-imports", "-fixups", image], text=True
)
fixups = re.findall(r"^\s+\S+\s+\S+\s+0x[0-9A-Fa-f]+\s+(rebase|bind)\b", output, re.MULTILINE)
imports = re.findall(r"^\s+0x[0-9A-Fa-f]+\s+", output, re.MULTILINE)
page_sizes = re.findall(r"page_size:\s+0x([0-9A-Fa-f]+)", output)
page_starts = re.findall(r"^\s+start\[", output, re.MULTILINE)
print(
    "DYLDLAB_STATIC "
    f"variant={variant} image={Path(image).name} "
    f"rebases={fixups.count('rebase')} binds={fixups.count('bind')} "
    f"imports={len(imports)} chain_pages={len(page_starts)} "
    f"page_sizes={','.join(page_sizes) or 'none'}"
)
