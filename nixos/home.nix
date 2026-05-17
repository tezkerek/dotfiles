{ config, pkgs, ... }:

{
  home.username = "andrei";
  home.homeDirectory = "/home/andrei";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  systemd.user.services.kanata = {
    Unit = {
      Description = "Kanata keyboard remapper";
      ConditionEnvironment = "XDG_SEAT";
    };

    Service = {
      ExecStart = "${pkgs.kanata}/bin/kanata --cfg %h/.config/kanata/kanata.kbd";
      Restart = "always";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
