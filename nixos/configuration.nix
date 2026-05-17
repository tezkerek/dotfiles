{
  config,
  pkgs,
  kanata-src,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  hardware.uinput.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "andrei-laptop";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ro_RO.UTF-8";
    LC_IDENTIFICATION = "ro_RO.UTF-8";
    LC_MEASUREMENT = "ro_RO.UTF-8";
    LC_MONETARY = "ro_RO.UTF-8";
    LC_NAME = "ro_RO.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "ro_RO.UTF-8";
    LC_TELEPHONE = "ro_RO.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.defaultUserShell = pkgs.zsh;
  users.users.andrei = {
    isNormalUser = true;
    description = "Andrei";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      kanata = prev.kanata.overrideAttrs (oldAttrs: {
        src = kanata-src;
        doCheck = false;
        doInstallCheck = false;
        cargoDeps = final.rustPlatform.importCargoLock {
          lockFile = "${kanata-src}/Cargo.lock";
        };
        cargoHash = "sha256-YGa18kZ9ttOKEP3pdCXXuh4zIcQLAaG7L2r2vPpcnDQ=";
      });
    })
  ];

  programs.chromium.enable = true;
  programs.firefox.enable = true;
  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.niri.enable = true;
  programs.wayvnc.enable = true;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    bat
    btop
    delta
    dotter
    eza
    fd
    fzf
    gitui
    jq
    jujutsu
    mcfly
    ripgrep
    tealdeer
    tmux
    usbutils
    wget
    zoxide

    bemenu
    brightnessctl
    copyq
    kanata
    waybar
    wofi

    keepassxc
    kitty
    opencode
    syncthing

    lua-language-server
    nixfmt
    stylua
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.symbols-only
  ];

  environment.variables.EDITOR = "nvim";

  services.udev.extraRules = ''
    # Keychron V1 Max
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="0913", MODE="0660", TAG+="uaccess", TAG+="udev-acl"

    # STM32 DFU
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", TAG+="uaccess"

    # Kanata
    KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"
    SUBSYSTEM=="input", ATTRS{name}=="AT Translated Set 2 keyboard", TAG+="uaccess", ENV{ID_INPUT_KEYBOARD}=="1", ENV{ID_SEAT}="seat0"
  '';

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "andrei";
    dataDir = "/home/andrei";
    configDir = "/home/andrei/.config/syncthing";
    settings = {
      gui.user = "andrei";
    };
  };

  services.openssh.enable = true;

  networking.firewall.allowedTCPPorts = [
    22
    5900
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
