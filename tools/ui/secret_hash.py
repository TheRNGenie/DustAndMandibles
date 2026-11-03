"""Print the table line for a secret code (components/secret_codes.gd TABLE).

    python tools/ui/secret_hash.py "GOLD RUSH 77" weapon:dino_rifle cosmetic:hat:bug_skull

Each unlock is kind:id, kind = weapon (a weapon id), cosmetic (slot:option) or notches (an amount, paid once).
Codes are matched upper-cased with only letters and digits kept, salted with
SecretCodes.SALT, and stored as SHA-256 so the plain code never enters the repo.
"""
import hashlib
import sys

SALT = "dust&mandibles:"


def normalize(code: str) -> str:
    return "".join(ch for ch in code.upper() if ("A" <= ch <= "Z") or ("0" <= ch <= "9"))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    digest = hashlib.sha256((SALT + normalize(sys.argv[1])).encode("utf-8")).hexdigest()
    unlocks = []
    for arg in sys.argv[2:]:
        kind, _, uid = arg.partition(":")
        if kind not in ("weapon", "cosmetic", "notches") or not uid:
            sys.exit("unlocks look like weapon:dino_rifle or cosmetic:hat:bug_skull, not %r" % arg)
        unlocks.append('{"kind": "%s", "id": "%s"}' % (kind, uid))
    print('\t"%s": [%s],' % (digest, ", ".join(unlocks)))
