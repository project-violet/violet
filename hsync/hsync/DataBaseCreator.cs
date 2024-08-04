// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using Extreme.Mathematics;
using Extreme.Statistics;
using hsync.Component;
using hsync.Crypto;
using hsync.Utils;
using Newtonsoft.Json;
using SQLite;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace hsync
{
    public class DataBaseCreator
    {
        List<EHentaiResultArticle> ehentaiArticles;
        Dictionary<string, int> ehIndex = new Dictionary<string, int>();
        DateTime mindd;
        PolynomialRegressionModel datetimeEstimator;

        public DataBaseCreator()
        {
            // Load or Reload Raw datas
            if (HitomiData.Instance.metadata_collection != null)
                HitomiData.Instance.metadata_collection.Clear();
            HitomiData.Instance.Load();
            ehentaiArticles = JsonConvert.DeserializeObject<List<EHentaiResultArticle>>(File.ReadAllText("ex-hentai-archive.json"));

            // List of all works on ehentai
            ehIndex = new Dictionary<string, int>();

            // Minimum datetime
            mindd = ehentaiArticles.Min(x => DateTime.Parse(x.Published));

            var xx1 = new List<double>();
            var yy1 = new List<double>();

            for (int i = 0; i < ehentaiArticles.Count; i++)
            {
                xx1.Add(int.Parse(ehentaiArticles[i].URL.Split('/')[4]));
                yy1.Add((DateTime.Parse(ehentaiArticles[i].Published) - mindd).TotalMinutes);
                if (!ehIndex.ContainsKey(ehentaiArticles[i].URL.Split('/')[4]))
                    ehIndex.Add(ehentaiArticles[i].URL.Split('/')[4], i);
            }

            // Estimate DateTime
            datetimeEstimator = new PolynomialRegressionModel(Vector.Create(yy1.ToArray()), Vector.Create(xx1.ToArray()), 100);
            datetimeEstimator.Fit();
        }

        /// <summary>
        /// Create a list of works that exist in Hitomi or ehentai.
        /// </summary>
        public void Integrate()
        {
            var ids = new HashSet<int>();

            onHitomi = new Dictionary<int, int>();
            for (int i = 0; i < HitomiData.Instance.metadata_collection.Count; i++)
            {
                if (onHitomi.ContainsKey(HitomiData.Instance.metadata_collection[i].ID))
                    continue;
                onHitomi.Add(HitomiData.Instance.metadata_collection[i].ID, i);
                ids.Add(HitomiData.Instance.metadata_collection[i].ID);
            }

            onEH = new Dictionary<int, int>();
            for (int i = 0; i < ehentaiArticles.Count; i++)
            {
                var id = int.Parse(ehentaiArticles[i].URL.Split('/')[4]);
                if (onEH.ContainsKey(id))
                    continue;
                onEH.Add(id, i);
                ids.Add(id);
            }

            articles = ids.ToList();
            articles.Sort((x, y) => x.CompareTo(y));
        }

        /// <summary>
        /// Leave only new works.
        /// </summary>
        /// <param name="syncronizer"></param>
        public void FilterOnlyNewed(Syncronizer syncronizer)
        {
            var hitomi_ids = new HashSet<int>();
            syncronizer.newedDataHitomi.ForEach(x => hitomi_ids.Add(x));
            var eh_ids = new HashSet<int>();
            syncronizer.newedDataEH.ForEach(x => eh_ids.Add(x));

            HitomiData.Instance.metadata_collection.RemoveAll(x => !hitomi_ids.Contains(x.ID));
            ehentaiArticles.RemoveAll(x => !eh_ids.Contains(int.Parse(x.URL.Split('/')[4])));

            // You donot have to remove ehIndex's items.
        }

        Dictionary<int, int> onHitomi;
        Dictionary<int, int> onEH;
        List<int> articles;

        /// <summary>
        /// 
        /// </summary>
        /// <param name="filename"></param>
        /// <param name="language"></param>
        public void ExtractRawDatabase(string filename = "rawdata", bool skip_indexing = false, string language = null, bool include_exhentai = false)
        {
            Directory.CreateDirectory(filename);
            if (File.Exists(filename + "/data.db"))
                File.Delete(filename + "/data.db");
            var db = new SQLiteConnection(filename + "/data.db");
            var info = db.GetTableInfo(typeof(HitomiColumnModel).Name);
            if (!info.Any())
                db.CreateTable<HitomiColumnModel>();

            var datas = articles.Where(id =>
            {
                if (language == null) return true;

                var oh = onHitomi.ContainsKey(id);
                var oe = onEH.ContainsKey(id);

                if (oh)
                {
                    var md = HitomiData.Instance.metadata_collection[onHitomi[id]];
                    if (md.Language == null || md.Language == "" || md.Language == language)
                        return true;
                }
                else
                {
                    var ed = ehentaiArticles[onEH[id]];
                    if (ed.Descripts == null || !ed.Descripts.ContainsKey("language"))
                        return true;
                    var edl = ed.Descripts["language"];
                    if (edl == null || edl.Count == 0 || edl.Contains(language))
                        return true;
                }

                return false;
            }).Select(id =>
            {
                HitomiColumnModel result = null;

                var oh = onHitomi.ContainsKey(id);
                var oe = onEH.ContainsKey(id);

                if (oh)
                {
                    var md = HitomiData.Instance.metadata_collection[onHitomi[id]];
                    result = new HitomiColumnModel
                    {
                        Id = id,
                        Artists = (md.Artists != null && md.Artists.Length > 0 && md.Artists[0] != "" ? "|" + string.Join("|", md.Artists) + "|" : "|N/A|"),
                        Characters = (md.Characters != null && md.Characters.Length > 0 && md.Characters[0] != "" ? "|" + string.Join("|", md.Characters) + "|" : null),
                        Groups = (md.Groups != null && md.Groups.Length > 0 && md.Groups[0] != "" ? "|" + string.Join("|", md.Groups) + "|" : null),
                        Series = (md.Parodies != null && md.Parodies.Length > 0 && md.Parodies[0] != "" ? "|" + string.Join("|", md.Parodies) + "|" : null),
                        Title = md.Name,
                        Tags = (md.Tags != null && md.Tags.Length > 0 && md.Tags[0] != "" ? "|" + string.Join("|", md.Tags) + "|" : null),
                        Type = md.Type,
                        Language = (md.Language != null && md.Language.Length != 0) ? md.Language : "n/a",
                        Published = md.DateTime,
                        ExistOnHitomi = 1,
                    };

                    if (oe)
                    {
                        var ii = ehentaiArticles[ehIndex[md.ID.ToString()]];
                        result.Uploader = ii.Uploader;
                        result.Published = DateTime.Parse(ii.Published);
                        result.EHash = ii.URL.Split('/')[5];
                        result.Files = ii.Files.Split(' ')[0].ToInt();
                        if (ii.Title.StartsWith("("))
                        {
                            result.Class = ii.Title.Split("(")[1].Split(")")[0];
                        }
                    }
                    else if (result.Published == null)
                        result.Published = mindd.AddMinutes(datetimeEstimator.Predict(md.ID));
                }
                else
                {
                    /*
                     [
                        {
                          "URL": string,
                          "Thumbnail": string,
                          "Title": string,
                          "Uploader": string,
                          "Published": string,
                          "Files": string,
                          "Type": string,
                          "Descripts": {
                            "female": [ string ],
                            "artist": [ string ],
                            "parody": [ string ],
                            "character": [ string ],
                            "male": [ string ],
                            "misc": [ string ],
                            "language": [ string ],
                            "group": [ string ]
                          }
                        }
                     ]
                    */

                    var ed = ehentaiArticles[onEH[id]];

                    var aritst = ed.Descripts != null ? ed.Descripts.ContainsKey("artist") ? ed.Descripts["artist"] : null : null;
                    var female = ed.Descripts != null ? ed.Descripts.ContainsKey("female") ? ed.Descripts["female"] : null : null;
                    var parody = ed.Descripts != null ? ed.Descripts.ContainsKey("parody") ? ed.Descripts["parody"] : null : null;
                    var character = ed.Descripts != null ? ed.Descripts.ContainsKey("character") ? ed.Descripts["character"] : null : null;
                    var male = ed.Descripts != null ? ed.Descripts.ContainsKey("male") ? ed.Descripts["male"] : null : null;
                    var misc = ed.Descripts != null ? ed.Descripts.ContainsKey("misc") ? ed.Descripts["misc"] : null : null;
                    var language = ed.Descripts != null ? ed.Descripts.ContainsKey("language") ? ed.Descripts["language"] : null : null;
                    var group = ed.Descripts != null ? ed.Descripts.ContainsKey("group") ? ed.Descripts["group"] : null : null;

                    var lang = "n/a";
                    if (language != null && language.Count != 0)
                    {
                        if (language.Where(x => x != "translated").ToList().Count == 0)
                            Console.WriteLine(ed.URL);
                        else
                            lang = language.Where(x => x != "translated").ToList()[0];
                    }

                    var tags = new List<string>();
                    if (female != null)
                    {
                        foreach (var tag in female)
                        {
                            var tt = tag;
                            if (tt == "lolicon")
                                tt = "loli";
                            else if (tt == "shotacon")
                                tt = "shota";
                            tags.Add("female:" + tt);
                        }
                    }
                    if (male != null)
                    {
                        foreach (var tag in male)
                        {
                            var tt = tag;
                            if (tt == "lolicon")
                                tt = "loli";
                            else if (tt == "shotacon")
                                tt = "shota";
                            tags.Add("male:" + tt);
                        }
                    }
                    if (misc != null)
                    {
                        foreach (var tag in misc)
                        {
                            var tt = tag;
                            if (tt == "lolicon")
                                tt = "loli";
                            else if (tt == "shotacon")
                                tt = "shota";
                            tags.Add(tt);
                        }
                    }

                    if (include_exhentai)
                    {
                        result = new HitomiColumnModel
                        {
                            Id = id,
                            Artists = (aritst != null && aritst.Count > 0 && aritst[0] != "" ? "|" + string.Join("|", aritst) + "|" : "|N/A|"),
                            Characters = (character != null && character.Count > 0 && character[0] != "" ? "|" + string.Join("|", character) + "|" : null),
                            Groups = (group != null && group.Count > 0 && group[0] != "" ? "|" + string.Join("|", group) + "|" : null),
                            Series = (parody != null && parody.Count > 0 && parody[0] != "" ? "|" + string.Join("|", parody) + "|" : null),
                            Title = ed.Title,
                            Tags = (tags.Count > 0 ? "|" + string.Join("|", tags) + "|" : null),
                            Type = ed.Type,
                            Language = lang,
                            ExistOnHitomi = 0,
                            Uploader = ed.Uploader,
                            Published = DateTime.Parse(ed.Published),
                            EHash = ed.URL.Split('/')[5],
                            Files = ed.Files.Split(' ')[0].ToInt(),
                            Class = ed.Title.StartsWith("(") ? ed.Title.Split("(")[1].Split(")")[0] : null,
                            Thumbnail = ed.Thumbnail,
                        };
                    }
                }
                return result;
            });
            db.InsertAll(datas);
            db.Close();

            if (skip_indexing) return;

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

            foreach (var article in datas)
            {
                if (article == null) continue;
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
