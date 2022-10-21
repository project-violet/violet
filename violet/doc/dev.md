# Dev

## Supports

Support sites that share the article ID of `e-hentai`.

`e-hentai.org`, `exhentai.org`, `hitomi.la`, `hiyobi.la`

## Database & Index

We use local database for article searching.

By providing not only database but also index information, `Violet` provides numerous functions that other apps do not provide.

See https://github.com/violet-dev/sync-data/releases/latest

## Pages

Check `lib/pages/**` directory.

### Receptions

`splash`, `lock`, `after_loading`, `database_download`

When the app start, the `splash` page is displayed.

If you set a lock, the `lock` page is shown before `splash`.

At first, it moves to the `database_download` page for `database_download`.

The next time you run, it moves to the `after_loading` page.

### After Loading

This page includes subpages like `main`, `search`, `hot`, `bookmark`, `download`, `settings`.

#### Main Page

#### Search Page

#### Hot Page

#### Bookmark Page

#### Download Page

#### Settings Page

## Settings

## Procedure

### How to load image?

Check https://github.com/project-violet/violet/blob/40b5fee47b5b619f7fcfabfea3cfe044a2af8830/lib/component/hentai.dart#L199

As said in the upper `supports`, we currently support four image sources as below.

`e-hentai.org`, `exhentai.org`, `hitomi.la`, `hiyobi.la`

Basically, `hitomi.la` mirror `exhenta.org`'s article(works) such as `doujinshi`, `manga`, `artist cg`, `game cg`.

So, there is not all article are on `hitomi.la`.

#### Why using hitomi.la?

Cuzof the `e-hentai.org` has ratelimit lock, if you load many image from that, the connection is denied for some time.

But, `hitomi.la` has a very optimistic ratelimit rule, so, you always load images no matter how you.

We just need to handle the annoying 503 error and script-related issues.

Check https://ltn.hitomi.la/gg.js

For handling this problem, we made https://github.com/project-violet/scripts and https://github.com/project-violet/violet/blob/40b5fee47b5b619f7fcfabfea3cfe044a2af8830/lib/script/script_manager.dart

#### How to load image from e-hentai, exhentai?

In violet, there ehparser class for parsing `e-hentai` html

Check https://github.com/project-violet/violet/blob/40b5fee47b5b619f7fcfabfea3cfe044a2af8830/lib/component/eh/eh_parser.dart#L58

### How to work viewer?

### How to search?

The core of search logic is `HentaiManger::search` https://github.com/project-violet/violet/blob/40b5fee47b5b619f7fcfabfea3cfe044a2af8830/lib/component/hentai.dart#L44

First of all, you must translate user query to sql.

These functions are performed by the following code.

https://github.com/project-violet/violet/blob/40b5fee47b5b619f7fcfabfea3cfe044a2af8830/lib/component/hitomi/hitomi.dart#L364

Then, query sqlite to get data information.

Queries need to be streamed, and for this we use `QueryManager`.

https://github.com/project-violet/violet/blob/40b5fee47b5b619f7fcfabfea3cfe044a2af8830/lib/database/query.dart#L51
