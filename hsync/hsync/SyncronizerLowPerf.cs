// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using hsync.Component;
using hsync.Log;
using hsync.Network;
using hsync.Setting;
using hsync.Utils;
using MySql.Data.MySqlClient;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Linq;
using SQLite;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace hsync
{
    public class SyncronizerLowPerf
    {
        int latestId;
        int hitomiSyncRange;
        SQLiteConnection db;
        HashSet<int> existsBoth;
        HashSet<int> existsEH;
        HashSet<int> existsHitomi;

        int starts = 0, ends = 0;
        bool useManualRange = false;
        int exhentaiLookupPage;

        public HashSet<int> newedDataHitomi;
        public HashSet<int> newedDataEH;

        public List<HitomiArticle> hitomiArticles;
        public List<EHentaiResultArticle> eHentaiResultArticles;

        public SyncronizerLowPerf(string[] hitomi_sync_range, string[] hitomi_sync_lookup_range, string[] exhentai_lookup_page)
        {
            if (hitomi_sync_lookup_range == null || !int.TryParse(hitomi_sync_lookup_range[0], out hitomiSyncRange))
                hitomiSyncRange = 4000;

            if (hitomi_sync_range != null
                && int.TryParse(hitomi_sync_range[0], out starts)
                && int.TryParse(hitomi_sync_range[1], out ends))
                useManualRange = true;

            if (exhentai_lookup_page == null || !int.TryParse(exhentai_lookup_page[0], out exhentaiLookupPage))
                exhentaiLookupPage = 200;

            db = new SQLiteConnection("data.db");

            existsHitomi = new HashSet<int>();
            foreach (var metadata in db.Query<HitomiColumnModel>("SELECT Id FROM HitomiColumnModel WHERE ExistOnHitomi=1"))
                existsHitomi.Add(metadata.Id);

            existsEH = new HashSet<int>();
            foreach (var metadata in db.Query<HitomiColumnModel>("SELECT Id FROM HitomiColumnModel WHERE EHash IS NOT NULL"))
                existsEH.Add(metadata.Id);

            existsBoth = new HashSet<int>();
            foreach (var metadata in db.Query<HitomiColumnModel>("SELECT Id FROM HitomiColumnModel WHERE EHash IS NOT NULL AND ExistOnHitomi=1"))
                existsBoth.Add(metadata.Id);

            latestId = db.Query<HitomiColumnModel>("SELECT * FROM HitomiColumnModel WHERE Id = (SELECT MAX(Id) FROM HitomiColumnModel);")[0].Id;
            newedDataHitomi = new HashSet<int>();
            newedDataEH = new HashSet<int>();

            Console.WriteLine("latest_id: " + latestId);
        }

        public void SyncHitomi()
        {
            var gburls = Enumerable.Range(useManualRange ? starts : latestId - hitomiSyncRange, useManualRange ? ends - starts + 1 : hitomiSyncRange * 2)
                .Select(x => $"https://ltn.hitomi.la/galleryblock/{x}.html").ToList();
            var dcnt = 0;
            var ecnt = 0;
            Console.Write("Running galleryblock tester... ");
            List<string> htmls;
            using (var pb = new ProgressBar())
            {
                htmls = NetTools.DownloadStrings(gburls, "",
                () =>
                {
                    pb.Report(gburls.Count, Interlocked.Increment(ref dcnt), ecnt);
                },
                () =>
                {
                    pb.Report(gburls.Count, dcnt, Interlocked.Increment(ref ecnt));
                }).Result;
            }
            Console.WriteLine("Complete");

            var gurls = new List<string>(gburls.Count);
            var gpurls = new List<string>(gburls.Count);
            for (int i = 0; i < gburls.Count; i++)
            {
                if (htmls[i] == null)
                    continue;
                var aa = HitomiParser.ParseGalleryBlock(htmls[i]);
                if (aa.Magic.Contains("-"))
                {
                    gurls.Add("https://hitomi.la/" + aa.Magic);
                    gpurls.Add("https://ltn.hitomi.la/galleries/" + aa.Magic.Split("-").Last().Split(".").First() + ".js");
                }
                else
                {
                    gurls.Add("https://hitomi.la/galleries/" + i + ".html");
                    gpurls.Add("https://ltn.hitomi.la/galleries/" + i + ".js");
                }
            }

            dcnt = 0;
            ecnt = 0;
            Console.Write("Running gallery tester... ");
            List<string> htmls2 = null;
            if (gurls.Count != 0)
                using (var pb = new ProgressBar())
                {
                    htmls2 = NetTools.DownloadStrings(gurls, "",
                    () =>
                    {
                        pb.Report(gburls.Count, Interlocked.Increment(ref dcnt), ecnt);
                    },
                    () =>
                    {
                        pb.Report(gburls.Count, dcnt, Interlocked.Increment(ref ecnt));
                    }).Result;
                }
            Console.WriteLine("Complete");

            dcnt = 0;
            ecnt = 0;
            Console.Write("Running galleries pages...");
            List<string> js = null;
            if (gpurls.Count != 0)
                using (var pb = new ProgressBar())
                {
                    js = NetTools.DownloadStrings(gpurls, "",
                    () =>
                    {
                        pb.Report(gburls.Count, Interlocked.Increment(ref dcnt), ecnt);
                    },
                    () =>
                    {
                        pb.Report(gburls.Count, dcnt, Interlocked.Increment(ref ecnt));
                    }).Result;
                }
            Console.WriteLine("Complete");

            hitomiArticles = new List<HitomiArticle>();
            for (int i = 0, j = 0; i < gburls.Count; i++)
            {
                if (htmls[i] == null)
                    continue;
                var aa = HitomiParser.ParseGalleryBlock(htmls[i]);
                if (htmls2[j] != null)
                {
                    var node = htmls2[j].ToHtmlNode();
                    var title = node.SelectSingleNode("//title");
                    if (!(title != null && title.InnerText == "Redirect"))
                    {
                        try
                        {
                            var ab = HitomiParser.ParseGallery(htmls2[j]);
                            aa.Groups = ab.Groups;
                            aa.Characters = ab.Characters;
                        } catch {
                            Console.WriteLine("parse-gallery-error: " + gurls[j]);
                            Console.WriteLine(htmls2[j]);
                        }
                    }
                }
                if (js[j] != null)
                {
                    try
                    {
                        var json = js[j].Split("var galleryinfo = ")[1].Split(";")[0];
                        aa.Files = JObject.Parse(json)["files"].Count().ToString();
                    } catch
                    {
                        Console.WriteLine("parse-galleryinfo: " + gpurls[j]);
                        Console.WriteLine(js[j]);
                    }
                }
                try
                {
                    if (aa.Magic.Contains("-"))
                        newedDataHitomi.Add(Convert.ToInt32(aa.Magic.Split('-').Last().Split('.')[0]));
                    else if (aa.Magic.Contains("galleries"))
                        newedDataHitomi.Add(Convert.ToInt32(aa.Magic.Split('/').Last().Split('.')[0]));
                    else
                        newedDataHitomi.Add(Convert.ToInt32(aa.Magic));
                }
                catch
                {
                    ;
                }
                hitomiArticles.Add(aa);
                j++;
            }

        }

        public void SyncExHentai()
        {
            eHentaiResultArticles = new List<EHentaiResultArticle>();

            var next = 0;

            // loop for no expunded galleries
            for (int i = 0; i < 9999999; i++)
            {
                try
                {
                    var url = $"https://exhentai.org/?next={next}&f_doujinshi=on&f_manga=on&f_artistcg=on&f_gamecg=on&f_cats=0&f_sname=on&f_stags=on&advsearch=1&f_sname=on&f_stags=on&f_sdesc=on";
                    var wc = new WebClient();
                    wc.Encoding = Encoding.UTF8;
                    wc.Headers.Add(HttpRequestHeader.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8");
                    wc.Headers.Add(HttpRequestHeader.UserAgent, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36");
                    wc.Headers.Add(HttpRequestHeader.Cookie, "igneous=30e0c0a66;sk=t8inbzaqn45ttyn9f78eanzuqizh;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f;sl=dm_2");
                    var html = wc.DownloadString(url);

                    try
                    {
                        var exh = ExHentaiParser.ParseResultPageExtendedListView(html);
                        eHentaiResultArticles.AddRange(exh);
                        if (exh.Count != 25)
                            Logs.Instance.PushWarning("[Miss] " + url);
                        if (i > exhentaiLookupPage && exh.Min(x => x.URL.Split('/')[4].ToInt()) < latestId)
                        {
                            break;
                        }
                        next = exh.Last().URL.Split('/')[4].ToInt();
                        Logs.Instance.Push("Parse exh page - " + i);
                    }
                    catch (Exception e)
                    {
                        Logs.Instance.PushError("[Fail] " + url);
                    }
                }
                catch (Exception e)
                {
                    Logs.Instance.PushError($"{i} {e.Message}");
                }
                Thread.Sleep(100);

                if (i % 100 == 99)
                    Thread.Sleep(120000);
            }

            next = 0;

            // loop for expunded galleries
            for (int i = 0; i < 9999999; i++)
            {
                try
                {
                    var url = $"https://exhentai.org/?next={next}&f_doujinshi=on&f_manga=on&f_artistcg=on&f_gamecg=on&f_cats=0&f_sname=on&f_stags=on&f_sh=on&advsearch=1&f_sname=on&f_stags=on&f_sdesc=on&f_sh=on";
                    var wc = new WebClient();
                    wc.Encoding = Encoding.UTF8;
                    wc.Headers.Add(HttpRequestHeader.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8");
                    wc.Headers.Add(HttpRequestHeader.UserAgent, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.139 Safari/537.36");
                    wc.Headers.Add(HttpRequestHeader.Cookie, "igneous=30e0c0a66;sk=t8inbzaqn45ttyn9f78eanzuqizh;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f;sl=dm_2");
                    var html = wc.DownloadString(url);

                    try
                    {
                        var exh = ExHentaiParser.ParseResultPageExtendedListView(html);
                        eHentaiResultArticles.AddRange(exh);
                        if (exh.Count != 25)
                            Logs.Instance.PushWarning("[Miss] " + url);
                        if (i > exhentaiLookupPage && exh.Min(x => x.URL.Split('/')[4].ToInt()) < latestId)
                        {
                            break;
                        }
                        next = exh.Last().URL.Split('/')[4].ToInt();
                        Logs.Instance.Push("Parse exh page - " + i);
                    }
                    catch (Exception e)
                    {
                        Logs.Instance.PushError("[Fail] " + url);
                    }
                }
                catch (Exception e)
                {
                    Logs.Instance.PushError($"{i} {e.Message}");
                }
                Thread.Sleep(100);

                if (i % 100 == 99)
                    Thread.Sleep(120000);
            }

            foreach (var z in eHentaiResultArticles)
            {
                var nn = z.URL.Split('/')[4].ToInt();

                if (!newedDataEH.Contains(nn))
                {
                    newedDataEH.Add(nn);
                }
            }
        }

        IEnumerable<HitomiColumnModel> _newedCache;
        private IEnumerable<HitomiColumnModel> getNewedHitomiColumnModels()
        {
            if (_newedCache != null) return _newedCache;
            var articles = new HashSet<int>();

            foreach (var n in newedDataEH)
                articles.Add(n);
            foreach (var n in newedDataHitomi)
                articles.Add(n);

            var x = articles.ToList();
            //x.RemoveAll(x => existsBoth.Contains(x));
            //x.RemoveAll(x => newedDataEH.Contains(x) && existsEH.Contains(x) && !existsHitomi.Contains(x) && !newedDataHitomi.Contains(x));
            //x.RemoveAll(x => newedDataHitomi.Contains(x) && existsHitomi.Contains(x) && !existsEH.Contains(x) && !newedDataEH.Contains(x));
            x.Sort((x, y) => x.CompareTo(y));

            var onHitomi = new Dictionary<int, int>();
            for (int i = 0; i < hitomiArticles.Count; i++)
            {
                var id = 0;

                try
                {
                    if (hitomiArticles[i].Magic.Contains("-"))
                        id = Convert.ToInt32(hitomiArticles[i].Magic.Split('-').Last().Split('.')[0]);
                    else if (hitomiArticles[i].Magic.Contains("galleries"))
                        id = Convert.ToInt32(hitomiArticles[i].Magic.Split('/').Last().Split('.')[0]);
                    else
                        id = Convert.ToInt32(hitomiArticles[i].Magic);
                }
                catch
                {
                    ;
                }

                if (onHitomi.ContainsKey(id))
                    continue;
                onHitomi.Add(id, i);
            }

            var onEH = new Dictionary<int, int>();
            if (eHentaiResultArticles != null)
            {
                for (int i = 0; i < eHentaiResultArticles.Count; i++)
                {
                    var id = int.Parse(eHentaiResultArticles[i].URL.Split('/')[4]);
                    if (onEH.ContainsKey(id))
                        continue;
                    onEH.Add(id, i);
                }
            }

            var exists = db.Query<HitomiColumnModel>($"SELECT * FROM HitomiColumnModel WHERE Id IN ({string.Join(",", x)})");
            var onExists = new Dictionary<int, int>();
            for (int i = 0; i < exists.Count; i++)
            {
                if (onExists.ContainsKey(exists[i].Id))
                    continue;
                onExists.Add(exists[i].Id, i);
            }

            var datas = x.Select(id =>
            {
                HitomiColumnModel result = null;

                var oh = newedDataHitomi.Contains(id);
                var oe = newedDataEH.Contains(id);
                var ox = onExists.ContainsKey(id);

                var ehh = existsHitomi.Contains(id);
                var eeh = existsEH.Contains(id);

                if (oh && !oe)
                {
                    var md = HitomiLegalize.ArticleToMetadata(hitomiArticles[onHitomi[id]]);
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
                        Files = md.Files
                    };

                    if (oe)
                    {
                        var ii = eHentaiResultArticles[onEH[md.ID]];
                        result.Uploader = ii.Uploader;
                        result.Published = DateTime.Parse(ii.Published);
                        result.EHash = ii.URL.Split('/')[5];
                        result.Files = ii.Files.Split(' ')[0].ToInt();
                        if (ii.Title.StartsWith("("))
                        {
                            result.Class = ii.Title.Split("(")[1].Split(")")[0];
                        }
                    }
                    else if (eeh)
                    {
                        var ii = exists[onExists[id]];
                        result.EHash = ii.EHash;
                        result.Uploader = ii.Uploader;
                        result.Published = ii.Published;
                        result.Class = ii.Class;
                    }
                    //else if (result.Published == null)
                    //    result.Published = mindd.AddMinutes(datetimeEstimator.Predict(md.ID));
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

                    var ed = eHentaiResultArticles[onEH[id]];

                    var aritst = ed.Descripts != null ? ed.Descripts.ContainsKey("artist") ? ed.Descripts["artist"] : null : null;
                    var female = ed.Descripts != null ? ed.Descripts.ContainsKey("female") ? ed.Descripts["female"] : null : null;
                    var parody = ed.Descripts != null ? ed.Descripts.ContainsKey("parody") ? ed.Descripts["parody"] : null : null;
                    var character = ed.Descripts != null ? ed.Descripts.ContainsKey("character") ? ed.Descripts["character"] : null : null;
                    var male = ed.Descripts != null ? ed.Descripts.ContainsKey("male") ? ed.Descripts["male"] : null : null;
                    var misc = ed.Descripts != null ? ed.Descripts.ContainsKey("misc") ? ed.Descripts["misc"] : null : null;
                    var language = ed.Descripts != null ? ed.Descripts.ContainsKey("language") ? ed.Descripts["language"] : null : null;
                    var group = ed.Descripts != null ? ed.Descripts.ContainsKey("group") ? ed.Descripts["group"] : null : null;
                    var other = ed.Descripts != null ? ed.Descripts.ContainsKey("other") ? ed.Descripts["other"] : null : null;
                    var mixed = ed.Descripts != null ? ed.Descripts.ContainsKey("mixed") ? ed.Descripts["mixed"] : null : null;

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
                    if (other != null)
                    {
                        foreach (var tag in other)
                        {
                            var tt = tag;
                            if (tt == "lolicon")
                                tt = "loli";
                            else if (tt == "shotacon")
                                tt = "shota";
                            tags.Add(tt);
                        }
                    }
                    if (mixed != null)
                    {
                        foreach (var tag in mixed)
                        {
                            var tt = tag;
                            if (tt == "lolicon")
                                tt = "loli";
                            else if (tt == "shotacon")
                                tt = "shota";
                            tags.Add(tt);
                        }
                    }

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
                        ExistOnHitomi = ehh || oh ? 1 : 0,
                        Uploader = ed.Uploader,
                        Published = DateTime.Parse(ed.Published),
                        EHash = ed.URL.Split('/')[5],
                        Files = ed.Files.Split(' ')[0].ToInt(),
                        Class = ed.Title.StartsWith("(") ? ed.Title.Split("(")[1].Split(")")[0] : null,
                        Thumbnail = ed.Thumbnail,
                    };
                }
                return result;
            });

            List<HitomiColumnModel> results = new List<HitomiColumnModel>();

            // Remove Overlapped Articles
            foreach (var article in datas) 
            {
                if (onExists.ContainsKey(article.Id))
                {
                    var exist = exists[onExists[article.Id]];

                    if (isDiff(article, exist))
                        results.Add(article);
                }
                else
                {
                    results.Add(article);
                }
            }

            // TODO: This code must be called only one!
            db.Execute($"DELETE FROM HitomiColumnModel WHERE Id IN ({string.Join(",", results.Select(x => x.Id))})");

            return _newedCache = results;
        }

        private bool isDiff(HitomiColumnModel a, HitomiColumnModel b)
        {
            if (a.Artists != b.Artists || 
                a.Groups != b.Groups || 
                a.Uploader != b.Uploader || 
                a.Tags != b.Tags || 
                a.Characters != b.Characters || 
                a.Series != b.Series || 
                a.Language != b.Language ||
                a.Type != b.Type || 
                a.Files != b.Files
                )
                return true;
            return false;
        }

        public void FlushToMainDatabase()
        {
            var datas = getNewedHitomiColumnModels();

            db.InsertAll(datas);
            db.Close();

            if (!Directory.Exists("chunk"))
                Directory.CreateDirectory("chunk");
            var dt = DateTime.Now.Ticks;
            var db2 = new SQLiteConnection($"chunk/data-{dt}.db");
            db2.CreateTable<HitomiColumnModel>();
            db2.InsertAll(datas);
            db2.Close();

            File.WriteAllText($"chunk/data-{dt}.json", JsonConvert.SerializeObject(datas));
        }

        static string _ggg(string nu)
        {
            if (nu == null) return "";
            return nu.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("＼", "\\\\").Replace("＂", "\\\"");
        }

        public void FlushToServerDatabase()
        {
            using (var conn = new MySqlConnection(Setting.Settings.Instance.Model.ServerConnection))
            {
                conn.Open();

                var myCommand = conn.CreateCommand();
                var transaction = conn.BeginTransaction();

                myCommand.Transaction = transaction;
                myCommand.Connection = conn;

                try
                {
                    db = new SQLiteConnection("data.db");
                    var datas = getNewedHitomiColumnModels();

                    var index_artist = new Dictionary<string, int>();
                    var index_group = new Dictionary<string, int>();
                    var index_series = new Dictionary<string, int>();
                    var index_character = new Dictionary<string, int>();
                    var index_tag = new Dictionary<string, int>();

                    Action<string, Dictionary<string, int>> queryIndexs = (tableName, index) =>
                    {
                        myCommand.CommandText = "SELECT Id, Name FROM " + tableName;
                        var reader = myCommand.ExecuteReader();
                        while (reader.Read())
                            index.Add(reader["Name"] as string, Convert.ToInt32(reader["Id"].ToString()));
                        reader.Close();
                    };

                    queryIndexs("eharticles_artists", index_artist);
                    queryIndexs("eharticles_groups", index_group);
                    queryIndexs("eharticles_series", index_series);
                    queryIndexs("eharticles_characters", index_character);
                    queryIndexs("eharticles_tags", index_tag);

                    myCommand.CommandText = "INSERT INTO eharticles (Title, Id, " +
                                            "EHash, Type, Language, " +
                                            "Uploader, Published, Files, Class, ExistOnHitomi) VALUES " +
                                                string.Join(',', datas.Select(x => $"(\"{_ggg(x.Title)}\", {x.Id}, " +
                                                $"\"{x.EHash}\", \"{_ggg(x.Type)}\", \"{_ggg(x.Language)}\", " +
                                                $"\"{_ggg(x.Uploader)}\", \"{(x.Published.HasValue ? x.Published.Value.ToString("yyyy-MM-dd HH:mm:ss") : "")}\", " +
                                                $"{x.Files}, \"{_ggg(x.Class)}\", {x.ExistOnHitomi})")) + " " +
                                            "ON DUPLICATE KEY UPDATE " +
                                            "Title=VALUES(Title), EHash=VALUES(EHash), Type=VALUES(Type), Language=VALUES(Language)," +
                                            "Uploader=VALUES(Uploader),Published=VALUES(Published),Files=VALUES(Files),Class=VALUES(Class),ExistOnHitomi=VALUES(ExistOnHitomi)";
                    myCommand.ExecuteNonQuery();

                    var new_index_artist = new List<(string, int)>();
                    var new_index_group = new List<(string, int)>();
                    var new_index_series = new List<(string, int)>();
                    var new_index_character = new List<(string, int)>();
                    var new_index_tag = new List<(string, int)>();

                    var junction_artist = new List<(int, int)>();
                    var junction_group = new List<(int, int)>();
                    var junction_series = new List<(int, int)>();
                    var junction_character = new List<(int, int)>();
                    var junction_tag = new List<(int, int)>();

                    foreach (var article in datas)
                    {
                        Func<Dictionary<string, int>, string, List<(string, int)>> insertSingle = (map, qr) =>
                        {
                            if (qr == null || qr == "") return null;
                            var x = new List<(string, int)>();
                            foreach (var tag in qr.Split('|'))
                                if (tag != "" && !map.ContainsKey(tag))
                                {
                                    x.Add((tag, map.Count));
                                    map.Add(tag, map.Count);
                                }
                            return x;
                        };

                        Action<string, List<(string, int)>, List<(int, int)>, Dictionary<string, int>>
                            compileMetadata = (what, new_index, junction, index) =>
                        {
                            if (what != null && what != "")
                            {
                                new_index.AddRange(insertSingle(index, what));
                                junction.AddRange(what.Split('|')
                                    .Where(x => x != "")
                                    .Select(x => (article.Id, index[x])));
                            }
                        };

                        compileMetadata(article.Artists, new_index_artist, junction_artist, index_artist);
                        compileMetadata(article.Groups, new_index_group, junction_group, index_group);
                        compileMetadata(article.Series, new_index_series, junction_series, index_series);
                        compileMetadata(article.Characters, new_index_character, junction_character, index_character);
                        compileMetadata(article.Tags, new_index_tag, junction_tag, index_tag);
                    }

                    Action<List<(string, int)>, string, List<(int, int)>, string> insertNew =
                        (new_index, tableName, junctions, junctionKeyword) =>
                    {
                        if (new_index.Count > 0)
                        {
                            myCommand.CommandText = $"INSERT IGNORE INTO {tableName} (Id, Name) VALUES " +
                                 string.Join(',', new_index.Select(x => $"({x.Item2}, \"{_ggg(x.Item1)}\")"));
                            myCommand.ExecuteNonQuery();
                        }
                        if (junctions.Count > 0)
                        {
                            myCommand.CommandText = $"INSERT IGNORE INTO {tableName}_junction (`Article`, `{junctionKeyword}`) VALUES " +
                                 string.Join(',', junctions.Select(x => $"({x.Item1}, {x.Item2})"));
                            myCommand.ExecuteNonQuery();
                        }
                    };

                    insertNew(new_index_artist, "eharticles_artists", junction_artist, "Artist");
                    insertNew(new_index_group, "eharticles_groups", junction_group, "Group");
                    insertNew(new_index_series, "eharticles_series", junction_series, "Series");
                    insertNew(new_index_character, "eharticles_characters", junction_character, "Character");
                    insertNew(new_index_tag, "eharticles_tags", junction_tag, "Tag");

                    transaction.Commit();
                }
                catch (Exception e)
                {
                    try
                    {
                        transaction.Rollback();
                    }
                    catch (Exception e1)
                    {
                    }
                }
                finally
                {
                    conn.Close();
                }
            }
        }

        public void FlushToElasticSearchServer()
        {
            try
            {
                db = new SQLiteConnection("data.db");
                var datas = getNewedHitomiColumnModels();

                var ss = new List<string>();
                foreach (var article in datas)
                {
                    JObject id = new JObject();
                    id.Add("_id", article.Id);
                    JObject index = new JObject();
                    index.Add("index", id);
                    ss.Add(JsonConvert.SerializeObject(index));
                    article.Thumbnail = null;
                    ss.Add(JsonConvert.SerializeObject(article));
                }

            RETRY_PUSH:

                var request = (HttpWebRequest)WebRequest.Create(Settings.Instance.Model.ElasticSearchHost);

                request.Method = "POST";
                request.ContentType = "application/json";

                var request_stream = new StreamWriter(request.GetRequestStream());

                request_stream.Write(string.Join("\n", ss) + "\n");
                request_stream.Close();

                try
                {
                    using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                    {
                    }
                }
                catch (WebException)
                {
                    Thread.Sleep(1000);
                    goto RETRY_PUSH;
                }
                Thread.Sleep(1000);
            }
            catch (Exception e)
            {
            }
        }

        public void Close() => db.Close();
    }
}
