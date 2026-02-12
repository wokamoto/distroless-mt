AdminCGIPath         /mt/
CGIPath              /mt/
StaticWebPath        /mt-static/
StaticFilePath       /var/www/movabletype/mt-static/

ObjectDriver         DBI::mysql
Database             docker
DBUser               docker
DBPassword           docker
DBHost               database

# PID file: use /tmp so distroless (non-root) can write; Starman --pid must match
PIDFilePath          /var/www/mt.pid

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

PreviewInNewWindow 0
AutoChangeImageQuality 0

NewsboxURL disable
DisableVersionCheck 1

AutoSaveFrequency 0
AssetFileExtensions gif, jpe?g, png, webp
