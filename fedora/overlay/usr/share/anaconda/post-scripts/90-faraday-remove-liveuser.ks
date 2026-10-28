# FaradayOS: the installed system starts at the login screen, not the live session
%post
/usr/share/faraday/remove-liveuser.sh --installed
%end
