// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using hsync.Component;
using hsync.Log;
using hsync.Network;
using hsync.Utils;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
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
    public class Syncronizer
    {
        int latestId;
        int hitomiSyncRange;

        int starts=0, ends=0;
        bool useManualRange = false;

        int exhentaiLookupPage;

        public List<int> newedDataHitomi;
        public List<int> newedDataEH;

        bool hitomi_sync_ignore_exists = false;

        public Syncronizer(string[] hitomi_sync_range, string[] hitomi_sync_lookup_range, bool hitomi_sync_ignore_exists, string[] exhentai_lookup_page)
        {
            HitomiData.Instance.Load();
            latestId = HitomiData.Instance.metadata_collection.First().ID;

            int lookup_range;
            if (hitomi_sync_lookup_range != null && int.TryParse(hitomi_sync_lookup_range[0], out lookup_range))
                hitomiSyncRange = lookup_range;
            else
                hitomiSyncRange = 4000;

            if (hitomi_sync_range != null 
                && int.TryParse(hitomi_sync_range[0], out starts) 
                && int.TryParse(hitomi_sync_range[1], out ends))
                useManualRange = true;

            if (exhentai_lookup_page != null && int.TryParse(exhentai_lookup_page[0], out exhentaiLookupPage))
                ;
            else
                exhentaiLookupPage = 200;

            newedDataHitomi = new List<int>();
            newedDataEH = new List<int>();

            this.hitomi_sync_ignore_exists = hitomi_sync_ignore_exists;
        }

        public void SyncHitomi()
        {
            var exists = new HashSet<int>();
            foreach (var metadata in HitomiData.Instance.metadata_collection)
                exists.Add(metadata.ID);

            var gburls = Enumerable.Range(useManualRange ? starts : latestId - hitomiSyncRange, useManualRange ? ends - starts + 1 : hitomiSyncRange * 2)
            //var gburls = Enumerable.Range(1000, latestId + hitomiSyncRange / 2)
                .Where(x => !exists.Contains(x) || hitomi_sync_ignore_exists).Select(x => $"https://ltn.hitomi.la/galleryblock/{x}.html").ToList();
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

            var result = new List<HitomiArticle>();
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
                result.Add(aa);
                j++;
            }

            Console.Write("Save to hiddendata.json... ");
            HitomiData.Instance.SaveWithNewData(result);
            Console.WriteLine("Complete");
        }

        public void SyncExHentai()
        {
            var result = new List<EHentaiResultArticle>();

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
                        result.AddRange(exh);
                        if (exh.Count != 25)
                            Logs.Instance.PushWarning("[Miss] " + url);
                        if (i > exhentaiLookupPage && exh.Min(x => x.URL.Split('/')[4].ToInt()) < latestId)
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

            var xxx = JsonConvert.DeserializeObject<List<EHentaiResultArticle>>(File.ReadAllText("ex-hentai-archive.json"));
            File.Move("ex-hentai-archive.json", $"ex-hentai-archive-{DateTime.Now.Ticks}.json");

            var exists = new HashSet<int>();
            xxx.ForEach(x => exists.Add(x.URL.Split('/')[4].ToInt()));

            foreach (var z in result)
            {
                var nn = z.URL.Split('/')[4].ToInt();

                if (!exists.Contains(nn))
                {
                    newedDataEH.Add(nn);
                    xxx.Add(z);
                }
            }

            JsonSerializer serializer = new JsonSerializer();
            serializer.Converters.Add(new JavaScriptDateTimeConverter());
            serializer.NullValueHandling = NullValueHandling.Ignore;

            Logs.Instance.Push("Write file: ex-hentai-archive.json");
            using (StreamWriter sw = new StreamWriter("ex-hentai-archive.json"))
            using (JsonWriter writer = new JsonTextWriter(sw))
            {
                serializer.Serialize(writer, xxx);
            }
        }
    }
}
