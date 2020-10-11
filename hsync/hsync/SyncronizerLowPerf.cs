// This source code is a part of project violet-server.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

using hsync.Component;
using hsync.Log;
using hsync.Network;
using hsync.Utils;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using SQLite;
using System;
using System.Collections.Generic;
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
        HashSet<int> exists;

        public HashSet<int> newedDataHitomi;
        public HashSet<int> newedDataEH;

        public List<HitomiArticle> hitomiArticles;
        public List<EHentaiResultArticle> eHentaiResultArticles;

        public SyncronizerLowPerf()
        {
            db = new SQLiteConnection("data.db");

            exists = new HashSet<int>();
            foreach (var metadata in db.Query<HitomiColumnModel>("SELECT Id FROM HitomiColumnModel"))
                exists.Add(metadata.Id);

            //HitomiData.Instance.Load();
            latestId = db.Query<HitomiColumnModel>("SELECT * FROM HitomiColumnModel WHERE Id = (SELECT MAX(Id)  FROM HitomiColumnModel);")[0].Id;
            hitomiSyncRange = 2000;
            newedDataHitomi = new HashSet<int>();
            newedDataEH = new HashSet<int>();
        }

        public void SyncHitomi()
        {

            var gburls = Enumerable.Range(latestId - hitomiSyncRange, hitomiSyncRange * 2)
            //var gburls = Enumerable.Range(1000, latestId + hitomiSyncRange / 2)
                .Where(x => !exists.Contains(x)).Select(x => $"https://ltn.hitomi.la/galleryblock/{x}.html").ToList();
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
            for (int i = 0; i < gburls.Count; i++)
            {
                if (htmls[i] == null)
                    continue;
                var aa = HitomiParser.ParseGalleryBlock(htmls[i]);
                if (aa.Magic.Contains("-"))
                    gurls.Add("https://hitomi.la/" + aa.Magic);
                else
                    gurls.Add("https://hitomi.la/galleries/" + i + ".html");
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

            //Console.Write("Check redirect gallery html... ");
            //for (int i = 0; i < htmls2.Count; i++)
            //{
            //    if (htmls2[i] == null)
            //        continue;
            //    var node = htmls2[i].ToHtmlNode();
            //    var title = node.SelectSingleNode("//title");
            //    if (title != null && title.InnerText == "Redirect")
            //    {
            //        htmls2.RemoveAt(i--);
            //    }
            //}
            //Console.WriteLine("Complete");

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
                        var ab = HitomiParser.ParseGallery(htmls2[j]);
                        aa.Groups = ab.Groups;
                        aa.Characters = ab.Characters;
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

            //Console.Write("Save to hiddendata.json... ");
            //HitomiData.Instance.SaveWithNewData(result);
            //Console.WriteLine("Complete");
        }

        public void SyncExHentai()
        {
            eHentaiResultArticles = new List<EHentaiResultArticle>();

            for (int i = 0; i < 9999999; i++)
            {
                try
                {
                    //var task = NetTask.MakeDefault($"https://exhentai.org/?page={i}&f_doujinshi=on&f_manga=on&f_artistcg=on&f_gamecg=on&&f_cats=0&f_sname=on&f_stags=on&f_sh=on&advsearch=1&f_srdd=2&f_sname=on&f_stags=on&f_sdesc=on&f_sh=on");
                    //task.Cookie = "igneous=30e0c0a66;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f;sl=dm_2";
                    //var html = NetTools.DownloadString(task);
                    var url = $"https://exhentai.org/?page={i}&f_doujinshi=on&f_manga=on&f_artistcg=on&f_gamecg=on&&f_cats=0&f_sname=on&f_stags=on&f_sh=on&advsearch=1&f_srdd=2&f_sname=on&f_stags=on&f_sdesc=on&f_sh=on";
                    var wc = new WebClient();
                    wc.Encoding = Encoding.UTF8;
                    wc.Headers.Add(HttpRequestHeader.Accept, "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8");
                    wc.Headers.Add(HttpRequestHeader.UserAgent, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.139 Safari/537.36");
                    wc.Headers.Add(HttpRequestHeader.Cookie, "igneous=30e0c0a66;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f;sl=dm_2");
                    var html = wc.DownloadString(url);

                    try
                    {
                        var exh = ExHentaiParser.ParseResultPageExtendedListView(html);
                        eHentaiResultArticles.AddRange(exh);
                        if (exh.Count != 25)
                            Logs.Instance.PushWarning("[Miss] " + url);
                        if (i > 20 && exh.Min(x => x.URL.Split('/')[4].ToInt()) < latestId)
                            break;
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

                if (i % 1000 == 999)
                    Thread.Sleep(60000);
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

        public void FlushToMainDatabase()
        {
            var articles = new HashSet<int>();

            foreach (var n in newedDataEH)
                articles.Add(n);
            foreach (var n in newedDataHitomi)
                articles.Add(n);

            var x = articles.ToList();
            x.RemoveAll(x => exists.Contains(x));
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
            for (int i = 0; i < eHentaiResultArticles.Count; i++)
            {
                var id = int.Parse(eHentaiResultArticles[i].URL.Split('/')[4]);
                if (onEH.ContainsKey(id))
                    continue;
                onEH.Add(id, i);
            }

            var datas = x.Select(id =>
            {
                HitomiColumnModel result = null;

                var oh = newedDataHitomi.Contains(id);
                var oe = newedDataEH.Contains(id);

                if (oh)
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
                return result;
            });

            db.InsertAll(datas);
            db.Close();

            var db2 = new SQLiteConnection($"data-{DateTime.Now.Ticks}.db");
            db2.CreateTable<HitomiColumnModel>();
            db2.InsertAll(datas);
            db2.Close();
        }
    }
}
