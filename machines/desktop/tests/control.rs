//! Run with rustc --test tests/control.rs -o /tmp/ryra-desktop-tests.
use std::fs;
use std::os::unix::{fs::PermissionsExt, net::UnixListener};
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicUsize, Ordering};

static NEXT: AtomicUsize = AtomicUsize::new(0);

struct Machine(PathBuf);

impl Machine {
    fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            "ryra-desktop-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).expect("isolated fixture");
        let this = Self(path);
        for dir in ["bin", "config/ryra-desktop", "run/ryra-desktop"] {
            fs::create_dir_all(this.0.join(dir)).expect("fixture folder");
        }
        fs::write(
            this.0.join("common.sh"),
            include_str!("../modules/desktop/common.sh"),
        )
        .expect("common");
        fs::write(
            this.0.join("control.sh"),
            include_str!("../modules/desktop/control.sh"),
        )
        .expect("control");
        this.executable("id", "echo 1000");
        this.executable("curl", "exit 0");
        this.executable("awk", "echo \"${TEST_MEMORY:-1048576}\"");
        this.executable("vncpasswd", "printf password > \"$1\"");
        this.executable(
            "systemctl",
            r#"
case "$2" in
  is-active) test "$(cat "$TEST_ROOT/state")" = active ;;
  is-failed) test "$(cat "$TEST_ROOT/state")" = failed ;;
  start) test "${TEST_START_FAIL:-0}" = 0 || exit 1; echo active > "$TEST_ROOT/state" ;;
  stop) echo stopped > "$TEST_ROOT/state" ;;
  reset-failed) exit 0 ;;
  *) exit 2 ;;
esac
"#,
        );
        this.state("stopped");
        this
    }

    fn executable(&self, name: &str, body: &str) {
        let path = self.0.join("bin").join(name);
        fs::write(&path, format!("#!/bin/sh\n{body}\n")).expect("mock command");
        fs::set_permissions(path, fs::Permissions::from_mode(0o700)).expect("executable");
    }

    fn state(&self, state: &str) {
        fs::write(self.0.join("state"), state).expect("service state");
    }

    fn password(&self) {
        fs::write(self.0.join("config/ryra-desktop/passwd"), "old-password")
            .expect("password fixture");
    }

    fn run(&self, action: &str, env: &[(&str, &str)]) -> std::process::Output {
        Command::new("bash")
            .args([
                "-c",
                "set -euo pipefail; source \"$1\"; source \"$2\" \"$3\"",
                "desktop-test",
            ])
            .arg(self.0.join("common.sh"))
            .arg(self.0.join("control.sh"))
            .arg(action)
            .env(
                "PATH",
                format!(
                    "{}:{}",
                    self.0.join("bin").display(),
                    std::env::var("PATH").expect("PATH")
                ),
            )
            .env("XDG_CONFIG_HOME", self.0.join("config"))
            .env("XDG_RUNTIME_DIR", self.0.join("run"))
            .env("TEST_ROOT", &self.0)
            .envs(env.iter().copied())
            .output()
            .expect("run helper against mocks")
    }

    fn said(&self, action: &str, env: &[(&str, &str)]) -> String {
        let out = self.run(action, env);
        assert!(
            out.status.success(),
            "{}",
            String::from_utf8_lossy(&out.stderr)
        );
        String::from_utf8(out.stdout).expect("UTF-8")
    }
}

impl Drop for Machine {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).expect("remove own fixture");
    }
}

#[test]
fn inspection_and_missing_password_never_start_a_session() {
    let machine = Machine::new();
    for action in ["status", "start"] {
        assert!(machine.said(action, &[]).contains("needs_password"));
        assert_eq!(
            fs::read_to_string(machine.0.join("state")).expect("state"),
            "stopped"
        );
    }
    machine.password();
    assert!(machine.said("status", &[]).contains("stopped"));
}

#[test]
fn low_memory_and_start_failures_are_actionable() {
    let machine = Machine::new();
    machine.password();
    assert!(machine
        .said("start", &[("TEST_MEMORY", "100")])
        .contains("512 MiB"));
    assert_eq!(
        fs::read_to_string(machine.0.join("state")).expect("state"),
        "stopped"
    );
    assert!(machine
        .said("start", &[("TEST_START_FAIL", "1")])
        .contains("Could not start"));
}

#[test]
fn active_service_requires_a_vnc_socket_and_http_viewer() {
    let machine = Machine::new();
    machine.password();
    machine.state("active");
    assert!(machine.said("status", &[]).contains("failed"));
    let _socket =
        UnixListener::bind(machine.0.join("run/ryra-desktop/vnc.sock")).expect("VNC socket");
    assert_eq!(
        machine.said("status", &[]).trim(),
        r#"{"state":"running","port":17000}"#
    );
    assert!(machine
        .said("start", &[("TEST_MEMORY", "0")])
        .contains("running"));
    machine.executable("curl", "exit 7");
    assert!(machine.said("status", &[]).contains("failed"));
}

#[test]
fn explicit_stop_releases_the_session_and_preserves_password() {
    let machine = Machine::new();
    machine.password();
    machine.state("active");
    assert!(machine.said("stop", &[]).contains("stopped"));
    assert_eq!(
        fs::read_to_string(machine.0.join("config/ryra-desktop/passwd")).expect("password"),
        "old-password"
    );
    assert!(machine.said("stop", &[]).contains("stopped"));
    fs::remove_file(machine.0.join("config/ryra-desktop/passwd")).expect("remove fixture password");
    assert!(machine.said("stop", &[]).contains("stopped"));
}

#[test]
fn password_change_is_atomic_and_refused_while_running() {
    let machine = Machine::new();
    machine.password();
    machine.executable("vncpasswd", "echo partial > \"$1\"; exit 1");
    assert!(!machine.run("password", &[]).status.success());
    assert_eq!(
        fs::read_to_string(machine.0.join("config/ryra-desktop/passwd")).expect("password"),
        "old-password"
    );
    machine.state("active");
    assert!(!machine.run("password", &[]).status.success());
}
