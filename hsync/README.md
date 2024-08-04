# hsync

```
hsync 2021.4.16
Build Date: Saturday, 17 April 2021
                                         /T /I
                              / |/ | .-~/
                          T\ Y  I  |/  /  _
         /T               | \I  |  I  Y.-~/
        I l   /I       T\ |  |  l  |  T  /
     T\ |  \ Y l  /T   | \I  l   \ `  l Y
 __  | \l   \l  \I l __l  l   \   `  _. |
 \ ~-l  `\   `\  \  \\ ~\  \   `. .-~   |
  \   ~-. "-.  `  \  ^._ ^. "-.  /  \   |
.--~-._  ~-  `  _  ~-_.-"-." ._ /._ ." ./
 >--.  ~-.   ._  ~>-"    "\\   7   7   ]
^.___~"--._    ~-{  .-~ .  `\ Y . /    |
 <__ ~"-.  ~       /_/   \   \I  Y   : |
   ^-.__           ~(_/   \   >._:   | l______
       ^--.,___.-~"  /_/   !  `-.~"--l_ /     ~"-.
              (_/ .  ~(   /'     "~"--,Y   -=b-. _)
               (_/ .  \  :           / l      c"~o \
                \ /    `.    .     .^   \_.-~"~--.  )
                 (_/ .   `  /     /       !       )/
                  / / _.   '.   .':      /        '
                  ~(_/ .   /    _  `  .-<_
                    /_/ . ' .-~" `.  / \  \          ,z=.
                    ~( /   '  :   | K   "-.~-.______//
                      "-,.    l   I/ \_    __{--->._(==.
                       //(     \  <    ~"~"     //
                      /' /\     \  \     ,v=.  ((
                    .^. / /\     "  }__ //===-  `
                   / / ' '  "-.,__ {---(==-
                 .^ '       :  T  ~"   ll
                / .  .  . : | :!        \\
               (_/  /   | | j-"          ~^
                 ~-<_(_.^-~"

Copyright (C) 2020-2021. project violet-server.
Usage: ./hsync [OPTIONS...]
   --help                      
   -v, --version               Show version information. 
   --recover-settings          Recover settings.json 
   -r, --related-tag-test      Related Tag Test [use --related-tag-test <db file path> <threshold>]
   -h, --character-test        Character Test [use --character-tag-test <db file path> <threshold>]
   -p, --series-test           Series Test [use --series-tag-test <db file path> <threshold>]
   --create-ehentai-inv-table  create e/exhentai hash inverse table [use --create-ehentai-inv-table]
   --create-datetime-estimator create datetime estimator [use --create-datetime-estimator]
   --init-server               Upload all data to server database [use --init-server]
   --init-server-pages         Upload all data to server article pages [use --init-server-pages]
   --export-for-es             Export database bulk datas for elastic-search to json [use --export-for-es]
   --export-for-es-range       Export database bulk datas for elastic-search to json using id range [--export-for-es-range]
   --export-for-db-range       Upload data to server database by user range [--export-for-db-range]
   -s, --start                 Starts hsync [use --start]
   -c, --compress              Compress exists data [use --compress]
   -x, --include-exhentai      Include ExHentai Database [use --include-exhentai]
   -l, --low-perf              hsync run on low performance system [use --low-perf]
   -n, --sync-only             Sync only when start [use --sync-only]
   --hitomi-sync-range         Set lookup id range manually [use --hitomi-sync-range <start id> <end id>]
   --hitomi-sync-lookup-range  Set hitomi id lookup range. (default: 4,000 [-4,000 ~ 4,000]) [use --hitomi-sync-lookup-range <count>]
   --exhentai-lookup-page      Set exhentai lookup page. (default: 200) [use --exhentai-lookup-page <range>]
   -e, --use-server            Upload sync data to server database [use --use-server]
   -a, --use-elastic-search    Upload sync data to elastic-search server [use --use-elastic-search]
   --sync-only-hitomi          Sync only hitomi [use --sync-only-hitomi]
   -t, --test                  hysnc test option [use --test <what>]
```

High-Performance E-Hentai/EX-Hentai/Hitomi Works Data Synchronizer

## Public Sync Data

You can see real-time synchronization information from https://koromo.xyz/version.txt
See sync.py for more information.

## How to use?

At least 8 GB of memory is required.

```
1. Set your own hitomi.la crawling range
https://github.com/project-violet/violet-server/blob/master/tools/hsync/hsync/Syncronizer.cs#L32
This use exhentai-based ID.
The default of 6,000 means to crawl 157,000 to 163,000 based on 160,000.

2. Set exhentai.org search range
https://github.com/project-violet/violet-server/blob/master/tools/hsync/hsync/Syncronizer.cs#L175
This use exhentai search result page number.
You need to set up how many pages you want to browse. The default is 150 pages.

3. Build
I recommend the debug build, but if you want to release, 
check the batch files in https://github.com/project-violet/violet-server/tree/master/tools/hsync/hsyncc folder.

4. Download base database
Download base database from https://github.com/project-violet/violet-server/releases

5. Run ./hsync.exe

6. Wait for complete
```

### (Option) For Server or Embedded System

This option is implemented to run on low performance system.

#### Linux x64

```
1. Install
mkdir sync
cd sync
wget https://github.com/project-violet/hsync/releases/download/2020.10.11/hsync
chmod 777 hsync
wget https://github.com/project-violet/hsync/releases/download/2020.10.11/data.db
mkdir runtimes
cd runtimes
wget https://github.com/project-violet/hsync/releases/download/2020.10.11/runtimes.zip
unzip runtimes.zip
cd ..

2. Syncronize
./hsync --start --low-perf
```

#### Customize Performance

```
1. Adjust NetQueue thread pool min threads count
https://github.com/project-violet/hsync/blob/master/hsync/Network/NetQueue.cs#L30

2. Adjust database query buffer size
https://github.com/project-violet/hsync/blob/master/hsync/DataBaseCreatorLowPerf.cs#L62
```
