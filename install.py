#!/usr/bin/python

import os
import sys

home_links = {
    "zshrc": ".zshrc",
    "tmux.conf": ".tmux.conf",
    "ideavimrc": ".ideavimrc",
}

xdg_config_links = {
    "init.vim": "nvim/init.vim",
    "kitty.conf": "kitty/kitty.conf",
    "alacritty.yml": "alacritty/alacritty.yml",
    "bspwm/bspwmrc": "bspwm/bspwmrc",
    "bspwm/compton.conf": "compton.conf",
    "bspwm/sxhkdrc": "sxhkd/sxhkdrc",
    "sway/config": "sway/config",
    "sway/waybar/config": "waybar/config",
    "sway/waybar/style.css": "waybar/style.css",
    "sway/wofi/config": "wofi/config",
    "sway/wofi/style.css": "wofi/style.css",
}

force = len(sys.argv) >= 2 and sys.argv[1] == "-f"

def try_symlink(target, link_name):
    target = os.path.abspath(target)
    link_name = os.path.abspath(link_name)

    # Ask on conflict if force flag not set
    if os.path.lexists(link_name):
        should_remove = force
        if not force:
            answer = input(f"{link_name} exists. Link anyway? [Y/n]")
            if answer.upper() == "Y":
                should_remove = True
            else: return

        if should_remove:
            os.remove(link_name)
            print(f"Removed {link_name}")

    os.symlink(target, link_name)
    print(f"{link_name} -> {target}")

def ls(d):
    return [os.path.join(d, f) for f in os.listdir(d)]

home_dir = os.environ['HOME']
for target, link in home_links.items():
    try_symlink(target, os.path.join(home_dir, link))

xdg_config_dir = os.environ.get('XDG_CONFIG_HOME', os.path.join(home_dir, ".config"))
for target, link in xdg_config_links.items():
    try_symlink(target, os.path.join(xdg_config_dir, link))

bin_dir = f"{home_dir}/.local/bin"
for file in ls("./bin"):
    try_symlink(file, os.path.join(bin_dir, os.path.basename(file)))
