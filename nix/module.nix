# openGym als Dienst: die API als systemd-Service mit Daten unter /var/lib/opengym, davor nginx auf einem lokalen Port,
# der die Oberfläche und die Übungsbilder ausliefert und /api an die API reicht. TLS und die öffentliche Adresse
# übernimmt der Reverse-Proxy davor (Traefik); er muss X-Forwarded-For setzen, die API vertraut ihm (TRUST_PROXY).
{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.opengym;
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
  inherit (lib) mkEnableOption mkOption types;
  csp = "default-src 'self'; script-src 'self' 'sha256-z/iOLe5i8fD4VNlIXz/4hEayGLTQzoTc52dIY51OjYc='; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; media-src 'self' blob: https:; font-src 'self' data:; connect-src 'self' https: http:; worker-src 'self'; manifest-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'";
  headers = ''
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "same-origin" always;
    add_header Content-Security-Policy "${csp}" always;
  '';
  proxy = ''
    proxy_pass http://127.0.0.1:${toString cfg.apiPort};
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $http_x_real_ip;
    proxy_set_header X-Forwarded-For $http_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    proxy_read_timeout 300s;
    proxy_send_timeout 300s;
  '';
in
{
  options.services.opengym = {
    enable = mkEnableOption "openGym";
    domain = mkOption {
      type = types.str;
      example = "fitness.example.org";
      description = "Öffentliche Adresse; Passkeys sind an sie gebunden (RP_ID, ORIGIN=https://<domain>).";
    };
    port = mkOption {
      type = types.port;
      default = 8085;
      description = "Lokaler Port von nginx, den der Reverse-Proxy anspricht.";
    };
    apiPort = mkOption {
      type = types.port;
      default = 3005;
      description = "Port der API, nur auf 127.0.0.1.";
    };
    frontend = mkOption {
      type = types.package;
      default = packages.frontend;
    };
    api = mkOption {
      type = types.package;
      default = packages.api;
    };
    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optionale Datei mit weiteren Variablen der API (ADMIN_UIDS, INVITE_ONLY, VAPID_SUBJECT, …).";
    };
    settings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        DEFAULT_LANG = "de";
        FIRST_USER_ADMIN = "1";
      };
      description = "Weitere Umgebungsvariablen der API (api/openapi.yaml und docs/SELF_HOSTING.md).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.opengym-api = {
      description = "openGym API";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        PORT = toString cfg.apiPort;
        DATA_DIR = "/var/lib/opengym";
        RP_ID = cfg.domain;
        ORIGIN = "https://${cfg.domain}";
        TRUST_PROXY = "1";
      }
      // cfg.settings;
      serviceConfig = {
        ExecStart = lib.getExe cfg.api;
        DynamicUser = true;
        StateDirectory = "opengym";
        StateDirectoryMode = "0700";
        PrivateTmp = true;
        Restart = "on-failure";
      }
      // lib.optionalAttrs (cfg.environmentFile != null) { EnvironmentFile = cfg.environmentFile; };
    };

    services.nginx = {
      enable = true;
      virtualHosts."opengym" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = cfg.port;
          }
        ];
        root = cfg.frontend;
        extraConfig = ''
          absolute_redirect off;
          ${headers}
          gzip on;
          gzip_types text/plain text/css application/json application/javascript image/svg+xml;
          gzip_vary on;
          gzip_min_length 1024;
        '';
        locations = {
          "^~ /api/" = {
            extraConfig = ''
              client_max_body_size 5m;
              ${proxy}
            '';
          };
          "^~ /api/media/" = {
            extraConfig = ''
              client_max_body_size 48m;
              proxy_request_buffering off;
              proxy_buffering off;
              ${proxy}
            '';
          };
          "/" = {
            tryFiles = "$uri $uri/ /index.html";
          };
          "~* \\.(js|css|json|html)$" = {
            extraConfig = ''
              add_header Cache-Control "no-cache, must-revalidate";
              ${headers}
            '';
          };
          "^~ /exercise-media/" = {
            extraConfig = ''
              add_header Cache-Control "public, max-age=2592000, immutable";
              add_header Cross-Origin-Resource-Policy "same-origin" always;
              ${headers}
            '';
          };
          "~* \\.(png|jpg|jpeg|gif|ico|svg|woff|woff2|webp|avif|mp4)$" = {
            extraConfig = ''
              add_header Cache-Control "public, max-age=2592000, immutable";
              ${headers}
            '';
          };
        };
      };
    };
  };
}
