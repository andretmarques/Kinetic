# The Kinetic DMG window, built by dmgbuild from make-dmg.sh.
format = "UDZO"
files = ["build/Kinetic.app"]
symlinks = {"Applications": "/Applications"}
icon = "Packaging/AppIcon.icns"

background = "Packaging/dmg-background.tiff"
window_rect = ((200, 200), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 14
icon_locations = {
    "Kinetic.app": (170, 200),
    "Applications": (470, 200),
}
