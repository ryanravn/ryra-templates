{ config, lib, pkgs, ... }:
let
  common = builtins.readFile ./desktop/common.sh;
  helper = pkgs.writeShellApplication {
    name = "ryra-desktop";
    runtimeInputs = with pkgs; [ coreutils systemd curl jq tigervnc gawk ];
    text = ''
      ${common}
      ${builtins.readFile ./desktop/control.sh}
    '';
  };
  session = pkgs.writeShellApplication {
    name = "ryra-desktop-session";
    runtimeInputs = with pkgs; [ coreutils tigervnc openbox xterm dbus xauth xdpyinfo openssl python3Packages.websockify ];
    text = ''
      ${common}
      export RYRA_NOVNC=${pkgs.novnc}/share/webapps/novnc
      ${builtins.readFile ./desktop/session.sh}
    '';
  };
in {
  options.ryra.desktop.enable = lib.mkEnableOption "the Ryra virtual desktop";
  config = lib.mkIf config.ryra.desktop.enable {
    environment.systemPackages = [ helper pkgs.xterm pkgs.openbox ];
    fonts.enableDefaultPackages = true;
    services.dbus.enable = true;

    systemd.user.services.ryra-desktop = {
      description = "Ryra desktop session";
      serviceConfig = {
        ExecStart = "${session}/bin/ryra-desktop-session";
        RuntimeDirectory = "ryra-desktop";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        KillMode = "control-group";
        TimeoutStopSec = 10;
        NoNewPrivileges = true;
      };
    };
  };
}
