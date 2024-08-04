// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using hsync.Component;
using Newtonsoft.Json;
using SQLite;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace hsync
{
    public class DataBaseCreatorLowPerf
    {
        public void ExtractRawDatabase(string filename = "rawdata", string language = null, bool include_exhentai = false)
        {
            var db = new SQLiteConnection("data.db");
            var count = db.ExecuteScalar<int>("SELECT COUNT(*) FROM HitomiColumnModel");

            Action<Dictionary<string, int>, string> insert = (map, qr) =>
            {
                if (qr == null) return;
                foreach (var tag in qr.Split('|'))
                {
                    if (tag != "")
                    {
                        if (!map.ContainsKey(tag))
                            map.Add(tag, 0);
                        map[tag] += 1;
                    }
                }
            };

            Action<Dictionary<string, int>, string> insertSingle = (map, qr) =>
            {
                if (qr == null || qr == "") return;
                if (!map.ContainsKey(qr))
                    map.Add(qr, 0);
                map[qr] += 1;
            };

            if (Directory.Exists(filename))
                Directory.Delete(filename, true);
            Directory.CreateDirectory(filename);

            var index = new IndexData();
            var result_artist = new Dictionary<string, Dictionary<int, int>>();
            var result_group = new Dictionary<string, Dictionary<int, int>>();
            var result_uploader = new Dictionary<string, Dictionary<int, int>>();
            var result_series = new Dictionary<string, Dictionary<int, int>>();
            var result_character = new Dictionary<string, Dictionary<int, int>>();
            var result_characterseries = new Dictionary<string, Dictionary<string, int>>();
            var result_seriescharacter = new Dictionary<string, Dictionary<string, int>>();
            var result_charactercharacter = new Dictionary<string, Dictionary<string, int>>();
            var result_seriesseries = new Dictionary<string, Dictionary<string, int>>();
            var ff = new Dictionary<string, int>();

            var rdb = new SQLiteConnection(filename + "/data.db");
            var info = rdb.GetTableInfo(typeof(HitomiColumnModel).Name);
            rdb.CreateTable<HitomiColumnModel>();

            const int perLoop = 50000;

            for (int i = 0; i < count; i += perLoop)
            {
                var query = db.Query<HitomiColumnModel>($"SELECT * FROM HitomiColumnModel ORDER BY Id LIMIT {perLoop} OFFSET {i}");

                Console.WriteLine($"{i}/{count}");

                var fquery = query.Where(article =>
                {
                    if (article == null) return false;

                    if (language != null && article.Language != language && article.Language != "n/a")
                        return false;

                    if (include_exhentai && article.ExistOnHitomi == 0)
                        return false;

                    return true;
                });

                rdb.InsertAll(fquery);

                foreach (var article in fquery)
                {
                    if (article == null) continue;

                    if (language != null && article.Language != language && article.Language != "n/a")
                        continue;

                    if (include_exhentai && article.ExistOnHitomi == 0)
                        continue;

                    insert(index.tags, article.Tags);
                    insert(index.artists, article.Artists);
                    insert(index.groups, article.Groups);
                    insert(index.series, article.Series);
                    insert(index.characters, article.Characters);
                    insertSingle(index.languages, article.Language);
                    insertSingle(index.types, article.Type);
                    insertSingle(index.uploaders, article.Uploader);
                    insertSingle(index.classes, article.Class);

                    if (article.Tags == null || article.Tags.Length == 0)
                        continue;
                    if (article.Artists != null)
                    {
                        foreach (var artist in article.Artists.Split('|'))
                        {
                            if (artist == "")
                                continue;
                            if (!result_artist.ContainsKey(artist))
                                result_artist.Add(artist, new Dictionary<int, int>());
                            foreach (var tag in article.Tags.Split('|'))
                            {
                                if (tag == "")
                                    continue;
                                if (!ff.ContainsKey(tag))
                                    ff.Add(tag, ff.Count);
                                if (!result_artist[artist].ContainsKey(ff[tag]))
                                    result_artist[artist].Add(ff[tag], 0);
                                result_artist[artist][ff[tag]] += 1;
                            }
                        }
                    }
                    if (article.Groups != null)
                    {
                        foreach (var artist in article.Groups.Split('|'))
                        {
                            if (artist == "")
                                continue;
                            if (!result_group.ContainsKey(artist))
                                result_group.Add(artist, new Dictionary<int, int>());
                            foreach (var tag in article.Tags.Split('|'))
                            {
                                if (tag == "")
                                    continue;
                                if (!ff.ContainsKey(tag))
                                    ff.Add(tag, ff.Count);
                                if (!result_group[artist].ContainsKey(ff[tag]))
                                    result_group[artist].Add(ff[tag], 0);
                                result_group[artist][ff[tag]] += 1;
                            }
                        }
                    }
                    if (article.Uploader != null)
                    {
                        foreach (var artist in article.Uploader.Split('|'))
                        {
                            if (artist == "")
                                continue;
                            if (!result_uploader.ContainsKey(artist))
                                result_uploader.Add(artist, new Dictionary<int, int>());
                            foreach (var tag in article.Tags.Split('|'))
                            {
                                if (tag == "")
                                    continue;
                                if (!ff.ContainsKey(tag))
                                    ff.Add(tag, ff.Count);
                                if (!result_uploader[artist].ContainsKey(ff[tag]))
                                    result_uploader[artist].Add(ff[tag], 0);
                                result_uploader[artist][ff[tag]] += 1;
                            }
                        }
                    }
                    if (article.Series != null)
                    {
                        foreach (var artist in article.Series.Split('|'))
                        {
                            if (artist == "")
                                continue;
                            if (!result_series.ContainsKey(artist))
                                result_series.Add(artist, new Dictionary<int, int>());
                            foreach (var tag in article.Tags.Split('|'))
                            {
                                if (tag == "")
                                    continue;
                                if (!ff.ContainsKey(tag))
                                    ff.Add(tag, ff.Count);
                                if (!result_series[artist].ContainsKey(ff[tag]))
                                    result_series[artist].Add(ff[tag], 0);
                                result_series[artist][ff[tag]] += 1;
                            }
                        }
                    }
                    if (article.Characters != null)
                    {
                        foreach (var artist in article.Characters.Split('|'))
                        {
                            if (artist == "")
                                continue;
                            if (!result_character.ContainsKey(artist))
                                result_character.Add(artist, new Dictionary<int, int>());
                            foreach (var tag in article.Tags.Split('|'))
                            {
                                if (tag == "")
                                    continue;
                                if (!ff.ContainsKey(tag))
                                    ff.Add(tag, ff.Count);
                                if (!result_character[artist].ContainsKey(ff[tag]))
                                    result_character[artist].Add(ff[tag], 0);
                                result_character[artist][ff[tag]] += 1;
                            }
                        }
                    }
                    if (article.Series != null && article.Characters != null)
                    {
                        foreach (var series in article.Series.Split('|'))
                        {
                            if (series == "")
                                continue;
                            if (!result_characterseries.ContainsKey(series))
                                result_characterseries.Add(series, new Dictionary<string, int>());
                            foreach (var character in article.Characters.Split('|'))
                            {
                                if (character == "")
                                    continue;
                                if (!result_characterseries[series].ContainsKey(character))
                                    result_characterseries[series].Add(character, 0);
                                result_characterseries[series][character] += 1;
                            }
                        }
                        foreach (var character in article.Characters.Split('|'))
                        {
                            if (character == "")
                                continue;
                            if (!result_seriescharacter.ContainsKey(character))
                                result_seriescharacter.Add(character, new Dictionary<string, int>());
                            foreach (var series in article.Series.Split('|'))
                            {
                                if (series == "")
                                    continue;
                                if (!result_seriescharacter[character].ContainsKey(series))
                                    result_seriescharacter[character].Add(series, 0);
                                result_seriescharacter[character][series] += 1;
                            }
                        }
                    }
                    if (article.Series != null)
                    {
                        foreach (var series in article.Series.Split('|'))
                        {
                            if (series == "")
                                continue;
                            if (!result_seriesseries.ContainsKey(series))
                                result_seriesseries.Add(series, new Dictionary<string, int>());
                            foreach (var series2 in article.Series.Split('|'))
                            {
                                if (series2 == "" || series == series2)
                                    continue;
                                if (!result_seriesseries[series].ContainsKey(series2))
                                    result_seriesseries[series].Add(series2, 0);
                                result_seriesseries[series][series2] += 1;
                            }
                        }
                    }
                    if (article.Characters != null)
                    {
                        foreach (var character in article.Characters.Split('|'))
                        {
                            if (character == "")
                                continue;
                            if (!result_charactercharacter.ContainsKey(character))
                                result_charactercharacter.Add(character, new Dictionary<string, int>());
                            foreach (var character2 in article.Characters.Split('|'))
                            {
                                if (character2 == "" || character == character2)
                                    continue;
                                if (!result_charactercharacter[character].ContainsKey(character2))
                                    result_charactercharacter[character].Add(character2, 0);
                                result_charactercharacter[character][character2] += 1;
                            }
                        }
                    }
                }
            }
            rdb.Close();

            File.WriteAllText(filename + "/index.json", JsonConvert.SerializeObject(index));
            File.WriteAllText(filename + "/tag-index.json", JsonConvert.SerializeObject(ff));
            File.WriteAllText(filename + "/tag-artist.json", JsonConvert.SerializeObject(result_artist));
            File.WriteAllText(filename + "/tag-group.json", JsonConvert.SerializeObject(result_group));
            File.WriteAllText(filename + "/tag-uploader.json", JsonConvert.SerializeObject(result_uploader));
            File.WriteAllText(filename + "/tag-series.json", JsonConvert.SerializeObject(result_series));
            File.WriteAllText(filename + "/tag-character.json", JsonConvert.SerializeObject(result_character));
            File.WriteAllText(filename + "/character-series.json", JsonConvert.SerializeObject(result_characterseries));
            File.WriteAllText(filename + "/series-character.json", JsonConvert.SerializeObject(result_seriescharacter));
            File.WriteAllText(filename + "/character-character.json", JsonConvert.SerializeObject(result_charactercharacter));
            File.WriteAllText(filename + "/series-series.json", JsonConvert.SerializeObject(result_seriesseries));
        }

        class IndexData
        {
            [JsonProperty(PropertyName = "tag")]
            public Dictionary<string, int> tags = new Dictionary<string, int>();
            [JsonProperty(PropertyName = "lang")]
            public Dictionary<string, int> languages = new Dictionary<string, int>();
            [JsonProperty(PropertyName = "artist")]
            public Dictionary<string, int> artists = new Dictionary<string, int>();
            [JsonProperty(PropertyName = "group")]
            public Dictionary<string, int> groups = new Dictionary<string, int>();
            [JsonProperty(PropertyName = "type")]
            public Dictionary<string, int> types = new Dictionary<string, int>();
            [JsonProperty(PropertyName = "uploader")]
            public Dictionary<string, int> uploaders = new Dictionary<string, int>();
            [JsonProperty(PropertyName = "series")]
            public Dictionary<string, int> series = new Dictionary<string, int>();
            [JsonProperty(PropertyName = "character")]
            public Dictionary<string, int> characters = new Dictionary<string, int>();
            [JsonProperty(PropertyName = "class")]
            public Dictionary<string, int> classes = new Dictionary<string, int>();
        }
    }
}
