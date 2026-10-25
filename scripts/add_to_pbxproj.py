"""Register a Swift file in the Colorwork app target.

usage: python3 add_to_pbxproj.py <pbxproj> <GroupName> <NewFile.swift> <AnchorFile.swift>
AnchorFile must already be in GroupName; new entries are inserted next to its entries.
"""
import re, secrets, sys

path, group, new, anchor = sys.argv[1:5]
src = open(path).read()
if f"/* {new} */" in src:
    sys.exit(f"{new} already registered")

def nid():
    while True:
        i = secrets.token_hex(12).upper()
        if i not in src:
            return i

ref, bld = nid(), nid()
lines = src.split("\n")
out = []
anchor_ref = re.search(r"(\w{24}) /\* " + re.escape(anchor) + r" \*/ = \{isa = PBXFileReference", src).group(1)
in_group = False
for line in lines:
    out.append(line)
    if f"/* {anchor} in Sources */ = {{isa = PBXBuildFile" in line:
        out.append(f"\t\t{bld} /* {new} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {new} */; }};")
    elif f"{anchor_ref} /* {anchor} */ = {{isa = PBXFileReference" in line:
        out.append(f"\t\t{ref} /* {new} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {new}; sourceTree = \"<group>\"; }};")
    elif line.strip() == f"{anchor_ref} /* {anchor} */,":
        out.append(line.replace(f"{anchor_ref} /* {anchor} */", f"{ref} /* {new} */"))
    elif line.strip().endswith(f"/* {anchor} in Sources */,"):
        out.append(re.sub(r"\w{24} /\* .* in Sources \*/", f"{bld} /* {new} in Sources */", line))

result = "\n".join(out)
assert result.count(ref) == 3 and result.count(bld) == 2, "unexpected match count"
open(path, "w").write(result)
print(f"registered {new}: ref={ref} build={bld}")
