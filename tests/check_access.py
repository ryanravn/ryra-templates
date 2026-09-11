"""Check evaluated access policy and enrollment ordering across all templates."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if len(sys.argv) == 2:
    results = json.loads(Path(sys.argv[1]).read_text())
else:
    results = json.loads(subprocess.check_output(
        ["nix", "eval", "--impure", "--json", "--file", str(ROOT / "tests/access.nix")],
        text=True,
    ))

for name, modes in results.items():
    for mode in ("public", "private", "bootstrap", "activationSecrets", "systemdSecrets"):
        assert not modes[mode]["failures"], (name, mode, modes[mode]["failures"])
    public = modes["public"]
    assert public["publicPorts"] == [22] and not public["tailscale"], (name, public)
    assert public["udpPorts"] == ([68] if name == "azure" else []) and public["mode"] == "public\n", name
    private = modes["private"]
    assert private["publicPorts"] == [] and private["privatePorts"] == [22], name
    assert private["trusted"] == ["lo"] and not private["sshOpenFirewall"], name
    assert private["udpPorts"] == ([68, 41641] if name == "azure" else [41641]) and private["mode"] == "tailscale\n", name
    assert private["authKeyFile"] == "/run/secrets/tailscale-auth", name
    assert private["upFlags"] == ["--ssh=false", "--netfilter-mode=off"], name
    assert private["setFlags"] == ["--ssh=false", "--netfilter-mode=off"], name
    unit = private["units"]["enrollment"]
    for secret_mode in ("private", "activationSecrets", "systemdSecrets"):
        case = modes[secret_mode]
        enrollment = case["units"]["enrollment"]
        if case["sopsSystemd"]:
            assert case["secretsUnitExists"], (name, secret_mode)
            for line in ("After=", "Requires="):
                assert any(row.startswith(line) and "sops-install-secrets.service" in row
                           for row in enrollment.splitlines()), (name, line, enrollment)
        else:
            assert "sops-install-secrets.service" not in enrollment, (name, secret_mode)
    assert "Restart=on-failure" in unit and "TimeoutStartSec=60s" in unit, name
    assert "MemoryLow=128M" in private["units"]["slice"], name
    bootstrap = modes["bootstrap"]
    assert bootstrap["tailscale"] and bootstrap["publicPorts"] == [22], name
    assert bootstrap["privatePorts"] == [22] and bootstrap["mode"] == "public\n", name
    for mode in ("missingKey", "noAccess", "leakedPort", "leakedRange", "leakedInterface", "trustedInterface"):
        assert modes[mode]["failures"], (name, mode, "unsafe configuration accepted")
    print(f"{name}: public, private, bootstrap and six rejection cases passed")
