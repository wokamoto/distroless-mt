AdminCGIPath         /mt/
CGIPath              /mt/
StaticWebPath        /mt-static/
StaticFilePath       /var/www/movabletype/mt-static/
SupportDirectoryURL  /mt-static/support/
SupportDirectoryPath /var/www/movabletype/mt-static/support

ObjectDriver         DBI::mysql
# DB connection settings are provided through MT_CONFIG_* system environment variables.

# PID file for MT's admin restart feature; Starman --pid must match.
PIDFilePath          /tmp/mt-starman.pid

DefaultLanguage      ja
DefaultTimezone      9

BaseSitePath         /var/www/html/htdocs

TransparentProxyIPs  1

DBUmask              0002
HTMLUmask            0002
UploadUmask          0002
DirUmask             0002

AdminScript    admin
ImageDriver    ImageMagick

MailTransfer smtp
# SMTP server settings are provided through MT_CONFIG_* system environment variables.

PreviewInNewWindow 0
AutoChangeImageQuality 0

NewsboxURL disable
DisableVersionCheck 1

AutoSaveFrequency 0
AssetFileExtensions gif, jpe?g, png, webp
