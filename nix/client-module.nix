{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ntfy-sh;
  settingsFormat = pkgs.formats.yaml { };

  # Build the client.yml from the structured options
  configFile = settingsFormat.generate "client.yml" (
    lib.filterAttrs (_: v: v != null) {
      default-host     = cfg.settings."default-host";
      default-user     = cfg.settings."default-user";
      default-password = cfg.settings."default-password";
      default-token    = cfg.settings."default-token";
      default-command  = cfg.settings."default-command";
      cert-file        = cfg.settings."cert-file";
      cert-password    = cfg.settings."cert-password";
      subscribe        = if cfg.settings.subscribe != [] then cfg.settings.subscribe else null;
    }
  );

  subscribeType = lib.types.submodule {
    options = {
      topic = lib.mkOption {
        type = lib.types.str;
        description = "Topic to subscribe to (short name or full URL).";
      };
      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Command to execute when a message is received.";
      };
      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Username for this subscription.";
      };
      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Password for this subscription.";
      };
      token = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Access token for this subscription.";
      };
      if_ = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Filters (message, title, priority, tags) to restrict which messages trigger the command.";
      };
    };
  };

in
{
  options.programs.ntfy-sh = {
    enable = lib.mkEnableOption "ntfy-sh client";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The ntfy package to use.";
    };

    settings = {
      "default-host" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "https://ntfy.example.com";
        description = ''
          Base URL used to expand short topic names in `ntfy publish` and `ntfy subscribe`.
          Defaults to https://ntfy.sh if unset.
        '';
      };

      "default-user" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default username for publish and subscribe commands.";
      };

      "default-password" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default password for publish and subscribe commands.";
      };

      "default-token" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default access token for publish and subscribe commands.";
      };

      "default-command" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default command to run when a subscribed message arrives (if no per-subscription command is set).";
      };

      "cert-file" = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/etc/ssl/ntfy-client.p12";
        description = ''
          Path to a PKCS#12 (.p12) client certificate file for mTLS authentication.
          Used when connecting to a server behind an mTLS-secured reverse proxy.
        '';
      };

      "cert-password" = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Password for the PKCS#12 client certificate file. Leave null or empty if the file has no password.";
      };

      subscribe = lib.mkOption {
        type = lib.types.listOf subscribeType;
        default = [];
        description = ''
          List of topic subscriptions for the ntfy-client service (i.e. `ntfy subscribe --from-config`).
        '';
        example = lib.literalExpression ''
          [
            {
              topic = "https://ntfy.example.com/alerts";
              command = '''notify-send "$NTFY_TITLE" "$NTFY_MESSAGE"''';
            }
            {
              topic = "backups";
              command = "systemctl start backup.service";
              if_.priority = "high,urgent";
            }
          ]
        '';
      };
    };

    # Install ntfy in the system environment and write /etc/ntfy/client.yml
    # (root's default config path). Per-user config (~/.config/ntfy/client.yml)
    # is managed by home-manager or manually.
    installSystemConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to install the generated client config to `/etc/ntfy/client.yml`.
        This is the default config path when ntfy is run as root. Normal users
        will still fall back to `~/.config/ntfy/client.yml`.
      '';
    };

    # Systemd user service for background subscriptions
    service = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable the `ntfy-client` systemd **user** service, which runs
          `ntfy subscribe --from-config` in the background and executes the configured
          commands when messages arrive.

          Enable this for users who want persistent background subscriptions.
          The service reads `~/.config/ntfy/client.yml` (or `/etc/ntfy/client.yml`
          if running as root).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.settings."default-user" != null && cfg.settings."default-token" != null);
        message = "programs.ntfy-sh: cannot set both default-user and default-token";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    environment.etc."ntfy/client.yml" = lib.mkIf cfg.installSystemConfig {
      source = configFile;
    };

    # Point all users at the system config file. The ntfy client checks
    # NTFY_CONFIG before falling back to ~/.config/ntfy/client.yml, and
    # only reads /etc/ntfy/client.yml when running as root.
    environment.sessionVariables.NTFY_CONFIG = lib.mkIf cfg.installSystemConfig
      "/etc/ntfy/client.yml";

    systemd.user.services.ntfy-client = lib.mkIf cfg.service.enable {
      description = "ntfy client - background topic subscriptions";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/ntfy subscribe --from-config";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
