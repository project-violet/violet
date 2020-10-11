
# run sync
./hsync -ls
./hsync -lc

# compress
cd rawdata
7z a -r rawdata.7z * x=9
cd rawdata-chinese
7z a -r rawdata-chinese.7z * x=9
cd rawdata-english
7z a -r rawdata-english.7z * x=9
cd rawdata-japanese
7z a -r rawdata-japanese.7z * x=9
cd rawdata-korean
7z a -r rawdata-korean.7z * x=9

# upload
# https://github.com/cheton/github-release-cli
github-release upload  \
     --owner=violet-dev \
     --repo=db \
     --tag="latest" \
     --release-name="db" \
     --body="" \
     rawdata/rawdata.7z \
     rawdata-chinese/rawdata-chinese.7z \
     rawdata-english/rawdata-english.7z \
     rawdata-japanese/rawdata-japanese.7z \
     rawdata-korean/rawdata-korean.7z