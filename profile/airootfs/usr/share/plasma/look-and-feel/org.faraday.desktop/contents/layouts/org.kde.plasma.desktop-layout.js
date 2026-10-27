// FaradayOS default desktop layout for new users, modelled on Zorin OS:
// one full-width bottom panel, start menu on the left, pinned apps and open windows next to it,
// system tray, clock and show-desktop on the right.
var panel = new Panel;
panel.location = "bottom";
panel.height = 2 * Math.ceil(gridUnit * 2.75 / 2);
panel.floating = false;
panel.hiding = "none";
panel.alignment = "left";
panel.lengthMode = "fill";

var menu = panel.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "/usr/share/pixmaps/faradayos.png");

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", ["preferred://browser", "preferred://filemanager", "applications:org.kde.discover.desktop", "applications:systemsettings.desktop"]);

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");

var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BelowTime");

panel.addWidget("org.kde.plasma.showdesktop");

desktopsForActivity(currentActivity()).forEach(function (d) {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/FaradayOS/contents/images/3260x1838.png");
});
