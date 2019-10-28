#!/bin/sh

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
userbindkeys=$HOME/.xbindkeysrc
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# merge in defaults and keymaps

if [ -f $sysresources ]; then
	xrdb -merge $sysresources
fi

if [ -f $sysmodmap ]; then
	xmodmap $sysmodmap
fi

if [ -f "$userresources" ]; then
	xrdb -merge "$userresources"
fi

if [ -f "$usermodmap" ]; then
	xmodmap "$usermodmap"
fi

# if [ -f "$userbindkeys" ]; then
# 	xbindkeys -p
# fi

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
	for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
		[ -x "$f" ] && . "$f"
	done
	unset f
fi

# Cursor
xsetroot -cursor_name left_ptr

# Keyboard delay
xset r rate 500 25

# Java graphics support
export _JAVA_AWT_WM_NONREPARENTING=1

# Set monitor layout
xrandr --output DisplayPort-2 --pos 0x800

# Window manager
exec bspwm 2>&1 bspwm.log
