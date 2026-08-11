"""
Quick verification subset — delegates to _verify_all_claims.py.

Previously this was a 32-line duplicate of the main verifier with a
hardcoded subset of claims. Now imports shared verification logic from
_verify_all_claims and only runs the 12 core claims (speed + accuracy).
"""
from _verify_all_claims import verify_core_claims

if __name__ == "__main__":
    all_ok = verify_core_claims()
    print(f'VERDICT: {"ALL 12 CLAIMS VERIFIED" if all_ok else "DISCREPANCY FOUND"}')
