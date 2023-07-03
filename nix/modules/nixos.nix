{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib; let
  cfg = config.services.snips-sh;
  user = config.users.users.snips-sh.name;
  group = config.users.groups.snips-sh.name;
  configFile = pkgs.writeText "snips-sh.env" (concatStrings (mapAttrsToList (name: value: "${name}=${value}\n") configEnv));

  # Convert name from camel case (e.g. disable2FARemember) to upper case snake case (e.g. DISABLE_2FA_REMEMBER).
  nameToEnvVar = name: let
    parts = builtins.split "([A-Z0-9]+)" name;
    partsToEnvVar = parts:
      foldl' (key: x: let
        last = stringLength key - 1;
      in
        if isList x
        then key + optionalString (key != "" && substring last 1 key != "_") "_" + head x
        else if key != "" && elem (substring 0 1 x) lowerChars
        then # to handle e.g. [ "disable" [ "2FAR" ] "emember" ]
          substring 0 last key + optionalString (substring (last - 1) 1 key != "_") "_" + substring last 1 key + toUpper x
        else key + toUpper x) ""
      parts;
  in
    if builtins.match "[A-Z0-9_]+" name != null
    then name
    else partsToEnvVar parts;

  # Due to the different naming schemes allowed for config keys,
  # we can only check for values consistently after converting them to their corresponding environment variable name.
  configEnv = let
    configEnv = concatMapAttrs (name: value:
      optionalAttrs (value != null) {
        ${nameToEnvVar name} =
          if isBool value
          then boolToString value
          else toString value;
      })
    cfg.config;
  in
    configEnv;
in {
  options.services.snips-sh = with types; {
    enable = mkEnableOption (mdDoc "Snips.sh");

    package = mkOption {
      type = package;
      default = self.packages.${pkgs.system}.default;
      defaultText = literalExpression "self'.packages.snips-sh";
      description = lib.mdDoc "snips-sh package to use.";
    };

    config = mkOption {
      type = attrsOf (nullOr (oneOf [bool int str]));
      default = {
        config = {};
      };
      example = literalExpression ''
        {
          SNIPS_HTTP_INTERNAL=http://0.0.0.0:8080
          ENV SNIPS_SSH_INTERNAL=ssh://0.0.0.0:2222
        }
      '';
      description = lib.mdDoc ''
        The configuration of snips-sh is done through environment variables,
        therefore it is recommended to use upper snake case (e.g. {env}`SNIPS_HTTP_INTERNAL`).

        However, camel case (e.g. `snipsSshInternal`) is also supported:
        The NixOS module will convert it automatically to
        upper case snake case (e.g. {env}`SNIPS_SSH_INTERNAL`).
        In this conversion digits (0-9) are handled just like upper case characters,
        so `foo2` would be converted to {env}`FOO_2`.
        Names already in this format remain unchanged, so `FOO2` remains `FOO2` if passed as such,
        even though `foo2` would have been converted to {env}`FOO_2`.
        This allows working around any potential future conflicting naming conventions.

        Based on the attributes passed to this config option an environment file will be generated
        that is passed to snips-sh's systemd service.

        The available configuration options can be found in
        [self-hostiing guide](https://github.com/robherley/snips.sh/blob/main/docs/self-hosting.md#configuration) to
        find about the environment variables you can use.
      '';
    };

    environmentFile = mkOption {
      type = with types; nullOr path;
      default = null;
      example = "/etc/snips-sh.env";
      description = lib.mdDoc ''
        Additional environment file as defined in {manpage}`systemd.exec(5)`.

        Sensitive secrets such as {env}`SNIPS_SSH_HOSTKEYPATH` and {env}`SNIPS_METRICS_STATSD`
        may be passed to the service while avoiding potentially making them world-readable in the nix store or
        to convert an existing non-nix installation with minimum hassle.

        Note that this file needs to be available on the host on which
        `snips-sh` is running.
      '';
    };
  };

  config = mkIf (cfg.enable) {
    users.users.snips-sh = {
      inherit group;
      isSystemUser = true;
    };
    users.groups.snips-sh = {};

    systemd.services.snips-sh = {
      after = ["network.target"];
      #path = with pkgs; [openssl];
      serviceConfig = {
        User = user;
        Group = group;
        EnvironmentFile = [configFile] ++ optional (cfg.environmentFile != null) cfg.environmentFile;
        ExecStart = "${cfg.package}/bin/snips.sh";
        LimitNOFILE = "1048576";
        PrivateTmp = "true";
        PrivateDevices = "true";
        ProtectHome = "true";
        ProtectSystem = "strict";
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        StateDirectory = "snips-sh";
        StateDirectoryMode = "0700";
        Restart = "always";
      };
      wantedBy = ["multi-user.target"];
    };
  };
}
