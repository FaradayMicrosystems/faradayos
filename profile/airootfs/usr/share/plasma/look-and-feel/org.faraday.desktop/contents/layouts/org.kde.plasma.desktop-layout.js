// FaradayOS default desktop layout for new users:
// a floating, translucent panel on the left edge, aligned to the top and sized to its content,
// with the start menu first, then pinned apps and open windows, system tray, clock and show-desktop.
var panel = new Panel;
panel.location = "left";
panel.height = 56;
panel.alignment = "left";
panel.lengthMode = "fit";
panel.hiding = "none";
panel.opacity = "translucent";
panel.floating = true;
panel.floatingApplets = true;

var menu = panel.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "faradayos");

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", ["preferred://browser", "preferred://filemanager", "applications:org.kde.discover.desktop", "applications:systemsettings.desktop"]);

panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
panel.addWidget("org.kde.plasma.showdesktop");

desktopsForActivity(currentActivity()).forEach(function (d) {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/FaradayOS/contents/images/3260x1838.png");
});
