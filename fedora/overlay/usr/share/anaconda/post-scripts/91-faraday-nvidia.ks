# FaradayOS: the installed system boots with the NVIDIA driver, like the live USB does.
# The live USB gets "rd.driver.blacklist=nouveau modprobe.blacklist=nouveau" from its own boot menu;
# the installer writes a new boot menu without them, so nouveau took NVIDIA cards and the NVIDIA driver never loaded.
%post
/usr/share/faraday/nvidia-boot-setup.sh
%end
