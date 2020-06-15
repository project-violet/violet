// This source code is a part of project violet-server.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

using hsync.CL;
using hsync.Component;
using hsync.Log;
using hsync.Network;
using hsync.Setting;
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

namespace hsync
{
    public class Options : IConsoleOption
    {
        [CommandLine("--help", CommandType.OPTION)]
        public bool Help;
        [CommandLine("--version", CommandType.OPTION, ShortOption = "-v", Info = "Show version information.")]
        public bool Version;

        /// <summary>
        /// Atomic Options
        /// </summary>

        [CommandLine("--recover-settings", CommandType.OPTION, Info = "Recover settings.json")]
        public bool RecoverSettings;

        /// <summary>
        /// User Option
        /// </summary>

        [CommandLine("--start", CommandType.OPTION, Default = true, ShortOption = "-s",
            Info = "Starts hsync", Help = "use --start")]
        public bool Start;
    }

    public class Command
    {
        public static void Start(string[] arguments)
        {
            arguments = CommandLineUtil.SplitCombinedOptions(arguments);
            arguments = CommandLineUtil.InsertWeirdArguments<Options>(arguments, true, "--url");
            var option = CommandLineParser.Parse<Options>(arguments);

            //
            //  Single Commands
            //
            if (option.Help)
            {
                PrintHelp();
            }
            else if (option.Version)
            {
                PrintVersion();
            }
            else if (option.RecoverSettings)
            {
                Settings.Instance.Recover();
                Settings.Instance.Save();
            }
            else if (option.Start)
            {
                ProcessStart();
            }
            else if (option.Error)
            {
                Console.WriteLine(option.ErrorMessage);
                if (option.HelpMessage != null)
                    Console.WriteLine(option.HelpMessage);
                return;
            }
            else
            {
                Console.WriteLine("Nothing to work on.");
                Console.WriteLine("Enter './hsync --help' to get more information");
            }

            return;
        }

        static byte[] art_console = {
            0x8D, 0x54, 0x3D, 0x6F, 0xDB, 0x30, 0x10, 0xDD, 0x0D, 0xF8, 0x3F, 0x5C, 0xB8, 0x48, 0x01, 0x74, 0xE4, 0x18, 0xC0, 0xB0, 0xBC,
            0x0B, 0x59, 0xB3, 0x18, 0x50, 0x45, 0x23, 0xD9, 0x0A, 0x01, 0xDD, 0x3A, 0x34, 0x2E, 0x7F, 0x7B, 0xDF, 0xBB, 0x93, 0x14, 0xA7,
            0x92, 0xDB, 0xD0, 0x24, 0x41, 0x1F, 0xDF, 0xDD, 0xBD, 0xFB, 0xA0, 0x44, 0xBE, 0x38, 0xD2, 0x8B, 0xA4, 0x6E, 0xBF, 0xFB, 0x0F,
            0x48, 0xAE, 0x98, 0x12, 0xB5, 0xA4, 0x7F, 0x41, 0x5F, 0x7A, 0x39, 0x8B, 0x74, 0x42, 0x34, 0x74, 0x24, 0xDF, 0x80, 0xE1, 0xE7,
            0xF3, 0xB8, 0x4A, 0x4F, 0xA4, 0xE1, 0xCF, 0x9F, 0x2D, 0x77, 0x32, 0x52, 0xA3, 0xFB, 0x30, 0x0B, 0x18, 0x26, 0xA4, 0xD8, 0x61,
            0x68, 0xC6, 0xFA, 0x0D, 0xBD, 0x8E, 0x93, 0x07, 0xB7, 0x4A, 0xF5, 0x5E, 0x2E, 0x3C, 0x9C, 0x01, 0xCD, 0xD9, 0x2E, 0x4C, 0x8A,
            0x0D, 0x88, 0x11, 0xB2, 0x71, 0xC6, 0x09, 0x91, 0x39, 0xCA, 0x15, 0xD0, 0x5E, 0x8A, 0x42, 0x7A, 0x31, 0x29, 0x36, 0x4E, 0xC8,
            0xFC, 0x24, 0x97, 0xC8, 0x1C, 0xD0, 0x0D, 0x09, 0x50, 0x52, 0x34, 0x4A, 0xC0, 0xA2, 0x09, 0xFC, 0x1F, 0x62, 0xC6, 0x72, 0x49,
            0x72, 0x04, 0xA0, 0x51, 0x15, 0x38, 0x90, 0x28, 0xEA, 0xBE, 0x78, 0xCA, 0x51, 0x01, 0x0B, 0x02, 0x79, 0xC2, 0xE2, 0x89, 0x61,
            0x9D, 0x94, 0xBA, 0x34, 0x2B, 0xBC, 0x92, 0x72, 0xD2, 0xC0, 0x50, 0x03, 0x68, 0x88, 0x3C, 0x4D, 0xEB, 0xDB, 0x7E, 0x07, 0x57,
            0x39, 0x97, 0x00, 0x38, 0x50, 0xD4, 0x78, 0x17, 0x23, 0x47, 0x2E, 0xCC, 0x48, 0x24, 0x01, 0x67, 0x7A, 0x44, 0x02, 0x80, 0xA4,
            0xDD, 0xB9, 0x1A, 0x99, 0x97, 0xB4, 0xC8, 0x74, 0xA1, 0x68, 0x72, 0xF0, 0x98, 0x64, 0x80, 0x3D, 0x33, 0x38, 0x8D, 0x52, 0x2F,
            0xD0, 0x53, 0xCC, 0x07, 0x4B, 0xF1, 0x08, 0xCF, 0x18, 0x4B, 0xC1, 0x06, 0x90, 0x68, 0x20, 0x80, 0xFB, 0x30, 0xDB, 0x7E, 0x00,
            0x0D, 0x8D, 0xE4, 0x37, 0x22, 0x40, 0x37, 0x05, 0x0A, 0x7F, 0xB7, 0x0F, 0xAD, 0x93, 0x57, 0x4D, 0x52, 0x95, 0x89, 0x02, 0x95,
            0x1A, 0x72, 0xD2, 0xF6, 0x15, 0xA4, 0xF3, 0xE3, 0xAA, 0xE7, 0x26, 0x2D, 0x90, 0x22, 0xA1, 0xA5, 0xC5, 0xAC, 0x9E, 0x18, 0x6F,
            0xA1, 0xFC, 0x90, 0x7E, 0xDD, 0xA9, 0xBD, 0x13, 0x41, 0x15, 0x99, 0x5C, 0x13, 0xC5, 0x81, 0x72, 0x63, 0x5E, 0x2C, 0xF3, 0x6B,
            0x67, 0x8B, 0x3B, 0x96, 0xCE, 0x23, 0xF1, 0xDD, 0x82, 0xB4, 0xF1, 0xB8, 0xF9, 0x2C, 0x12, 0x7E, 0x68, 0x2B, 0x91, 0xCA, 0x8A,
            0x59, 0x4D, 0x5C, 0x67, 0x65, 0xA9, 0xB6, 0x94, 0x2C, 0xDF, 0x71, 0x86, 0x65, 0x73, 0x1A, 0xF5, 0x78, 0xFB, 0x94, 0x6E, 0x5D,
            0x18, 0xB8, 0x62, 0xE1, 0x83, 0xC5, 0x95, 0xAC, 0x63, 0x3F, 0x00, 0xCD, 0xAF, 0x76, 0x95, 0xF3, 0xD9, 0x91, 0xB9, 0x40, 0xCE,
            0xBD, 0xA8, 0xCF, 0xD8, 0x51, 0x20, 0x36, 0xAA, 0x8D, 0x74, 0xF7, 0xA9, 0x07, 0x6D, 0x2C, 0x79, 0xCC, 0x76, 0x07, 0x87, 0xD6,
            0x2E, 0x39, 0xBF, 0xAB, 0x2A, 0x5A, 0xA4, 0x6E, 0xEF, 0x79, 0x24, 0xDF, 0xC4, 0x42, 0x1B, 0xC3, 0xA3, 0x91, 0x40, 0xB1, 0xA7,
            0x8B, 0x7B, 0x3A, 0xE8, 0x8A, 0xE4, 0x01, 0x2D, 0x91, 0x35, 0x3F, 0x5B, 0x10, 0xA8, 0xEB, 0x6D, 0x95, 0x88, 0x07, 0x88, 0xD4,
            0x3B, 0x14, 0xD6, 0x7F, 0xA3, 0x9F, 0x53, 0x6A, 0xDB, 0x96, 0x8F, 0x6F, 0x53, 0x85, 0x85, 0xAA, 0x98, 0x09, 0xC4, 0x8F, 0x3E,
            0x16, 0x46, 0x82, 0x30, 0x74, 0x03, 0x8C, 0x7E, 0xF1, 0x2E, 0xB5, 0xB4, 0xE1, 0x8B, 0x63, 0xFC, 0xC7, 0x71, 0x0D, 0xB5, 0x2A,
            0xDA, 0xC4, 0xD3, 0x92, 0xC3, 0xDC, 0x2A, 0xF8, 0x9C, 0x6C, 0xB6, 0xB3, 0x15, 0xE3, 0x8A, 0xDF, 0x77, 0x7F, 0xEF, 0x3E, 0xCA,
            0xB0, 0xC1, 0xA1, 0xA0, 0x1D, 0xEA, 0x1C, 0x07, 0xD4, 0x7C, 0xBF, 0xFB, 0x03,
        };

        static void PrintHelp()
        {
            PrintVersion();
            Console.WriteLine(Encoding.UTF8.GetString(CompressUtils.Decompress(art_console)));
            Console.WriteLine($"Copyright (C) 2020. project violet-server.");
            Console.WriteLine("Usage: ./hsync [OPTIONS...]");

            var builder = new StringBuilder();
            CommandLineParser.GetFields(typeof(Options)).ToList().ForEach(
                x =>
                {
                    var key = x.Key;
                    if (!key.StartsWith("--"))
                        return;
                    if (!string.IsNullOrEmpty(x.Value.Item2.ShortOption))
                        key = $"{x.Value.Item2.ShortOption}, " + key;
                    var help = "";
                    if (!string.IsNullOrEmpty(x.Value.Item2.Help))
                        help = $"[{x.Value.Item2.Help}]";
                    if (!string.IsNullOrEmpty(x.Value.Item2.Info))
                        builder.Append($"   {key}".PadRight(30) + $" {x.Value.Item2.Info} {help}\r\n");
                    else
                        builder.Append($"   {key}".PadRight(30) + $" {help}\r\n");
                });
            Console.Write(builder.ToString());
        }

        public static void PrintVersion()
        {
            Console.WriteLine($"{Version.Name} {Version.Text}");
            Console.WriteLine($"Build Date: " + Internals.GetBuildDate().ToLongDateString());
        }

        static void ProcessStart()
        {
            Console.Clear();
            Console.Title = "hsync";

            Console.WriteLine($"hsync - DB Synchronization Manager");
            Console.WriteLine($"Copyright (C) 2020. project violet-server.");
            Console.WriteLine($"Version: {Version.Text} (Build: {Internals.GetBuildDate().ToLongDateString()})");
            Console.WriteLine("");

            if (!File.Exists("hiddendata.json"))
            {
                Logs.Instance.Push("Welcome to hsync!\r\n\tDownload the necessary data before running the program!");
                download_data("https://github.com/project-violet/database/releases/download/rd2020.06.07/hiddendata.json", "hiddendata.json");
            }
            if (!File.Exists("metadata.json"))
                download_data("https://github.com/project-violet/database/releases/download/rd2020.06.07/metadata.json", "metadata.json");
            if (!File.Exists("ex-hentai-archive.json"))
                download_data("https://github.com/project-violet/database/releases/download/rd2020.06.07/ex-hentai-archive.json", "ex-hentai-archive.json");

            HitomiData.Instance.Load();

            var latest = HitomiData.Instance.metadata_collection.First().ID;

//#if true
            // Sync Hitomi
            {
                var range = 2000;
                var exists = new HashSet<int>();
                foreach (var metadata in HitomiData.Instance.metadata_collection)
                    exists.Add(metadata.ID);

                var gburls = Enumerable.Range(latest - range, range * 2).Where(x => !exists.Contains(x)).Select(x => $"https://ltn.hitomi.la/galleryblock/{x}.html").ToList();
                var dcnt = 0;
                var ecnt = 0;
                Console.Write("Running galleryblock tester... ");
                List<string> htmls;
                using (var pb = new ProgressBar())
                {
                    htmls = NetTools.DownloadStrings(gburls, "", 
                    () => {
                        pb.Report(gburls.Count, Interlocked.Increment(ref dcnt), ecnt);
                    }, 
                    () => {
                        pb.Report(gburls.Count, dcnt, Interlocked.Increment(ref ecnt));
                    });
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
                    () => {
                        pb.Report(gburls.Count, Interlocked.Increment(ref dcnt), ecnt);
                    },
                    () => {
                        pb.Report(gburls.Count, dcnt, Interlocked.Increment(ref ecnt));
                    });
                }
                Console.WriteLine("Complete");

                Console.Write("Check redirect gallery html... ");
                var last_change = true;
                while (last_change)
                {
                    last_change = false;
                    for (int i = 0; i < htmls2.Count; i++)
                    {
                        if (htmls2[i] == null)
                            continue;
                        var node = htmls2[i].ToHtmlNode();
                        var title = node.SelectSingleNode("//title");
                        if (title != null && title.InnerText == "Redirect")
                        {
                            htmls2[i] = NetTools.DownloadString(node.SelectSingleNode("//a").GetAttributeValue("href", ""));
                            last_change = true;
                        }
                    }
                }
                Console.WriteLine("Complete");

                var result = new List<HitomiArticle>();
                for (int i = 0, j = 0; i < gburls.Count; i++)
                {
                    if (htmls[i] == null)
                        continue;
                    var aa = HitomiParser.ParseGalleryBlock(htmls[i]);
                    if (htmls2[j] != null)
                    {
                        var ab = HitomiParser.ParseGallery(htmls2[j]);
                        aa.Groups = ab.Groups;
                        aa.Characters = ab.Characters;
                    }
                    result.Add(aa);
                    j++;
                }

                Console.Write("Save to hiddendata.json... ");
                HitomiData.Instance.SaveWithNewData(result);
                Console.WriteLine("Complete");

//#if true
//                Console.Write("Save to index-metadata.json... ");
//                HitomiIndex.MakeIndex();
//                Console.WriteLine("Complete");
//#endif
            }

//#if false
            // Sync EH
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
                            if (i > 500 && exh.Min(x => x.URL.Split('/')[4].ToInt()) < latest)
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
                        xxx.Add(z);
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
//#endif
//#endif

//#if false
            // Make DataBase
            {
                HitomiData.Instance.metadata_collection.Clear();
                HitomiData.Instance.Load();
                var xxx = JsonConvert.DeserializeObject<List<EHentaiResultArticle>>(File.ReadAllText("ex-hentai-archive.json"));

                Console.Write("Make database... ");
                var dict = new Dictionary<string, int>();

                for (int i = 0; i < xxx.Count; i++)
                {
                    if (!dict.ContainsKey(xxx[i].URL.Split('/')[4]))
                        dict.Add(xxx[i].URL.Split('/')[4], i);
                }

                {
                    var db = new SQLiteConnection("hitomidata.db");
                    var info = db.GetTableInfo(typeof(HitomiColumnModel).Name);
                    if (!info.Any())
                        db.CreateTable<HitomiColumnModel>();
                    db.InsertAll(HitomiData.Instance.metadata_collection.Select(md =>
                    {
                        var dd = new HitomiColumnModel
                        {
                            Id = md.ID,
                            Artists = (md.Artists != null && md.Artists.Length > 0 && md.Artists[0] != "" ? "|" + string.Join("|", md.Artists) + "|" : "N/A|"),
                            Characters = (md.Characters != null && md.Characters.Length > 0 && md.Characters[0] != "" ? "|" + string.Join("|", md.Characters) + "|" : null),
                            Groups = (md.Groups != null && md.Groups.Length > 0 && md.Groups[0] != "" ? "|" + string.Join("|", md.Groups) + "|" : null),
                            Series = (md.Parodies != null && md.Parodies.Length > 0 && md.Parodies[0] != "" ? "|" + string.Join("|", md.Parodies) + "|" : null),
                            Title = md.Name,
                            Tags = (md.Tags != null && md.Tags.Length > 0 && md.Tags[0] != "" ? "|" + string.Join("|", md.Tags) + "|" : null),
                            Type = md.Type,
                            Language = md.Language,

                        };

                        if (dict.ContainsKey(md.ID.ToString()))
                        {
                            var ii = xxx[dict[md.ID.ToString()]];
                            dd.Uploader = ii.Uploader;
                            dd.Published = DateTime.Parse(ii.Published);
                            dd.EHash = ii.URL.Split('/')[5];
                            dd.Files = ii.Files.Split(' ')[0].ToInt();
                            if (ii.Title.StartsWith("("))
                            {
                                dd.Class = ii.Title.Split("(")[1].Split(")")[0];
                            }
                        }

                        return dd;
                    }));
                    db.Close();
                }

                Console.WriteLine("Complete-All");

                {
                    var db = new SQLiteConnection("hitomidata-korean.db");
                    var info = db.GetTableInfo(typeof(HitomiColumnModel).Name);
                    if (!info.Any())
                        db.CreateTable<HitomiColumnModel>();
                    db.InsertAll(HitomiData.Instance.metadata_collection.Where(md => md.Language == null || md.Language == "" || md.Language == "korean").Select(md =>
                    {
                        var dd = new HitomiColumnModel
                        {
                            Id = md.ID,
                            Artists = (md.Artists != null && md.Artists.Length > 0 && md.Artists[0] != "" ? "|" + string.Join("|", md.Artists) + "|" : "N/A|"),
                            Characters = (md.Characters != null && md.Characters.Length > 0 && md.Characters[0] != "" ? "|" + string.Join("|", md.Characters) + "|" : null),
                            Groups = (md.Groups != null && md.Groups.Length > 0 && md.Groups[0] != "" ? "|" + string.Join("|", md.Groups) + "|" : null),
                            Series = (md.Parodies != null && md.Parodies.Length > 0 && md.Parodies[0] != "" ? "|" + string.Join("|", md.Parodies) + "|" : null),
                            Title = md.Name,
                            Tags = (md.Tags != null && md.Tags.Length > 0 && md.Tags[0] != "" ? "|" + string.Join("|", md.Tags) + "|" : null),
                            Type = md.Type,
                            Language = md.Language,

                        };

                        if (dict.ContainsKey(md.ID.ToString()))
                        {
                            var ii = xxx[dict[md.ID.ToString()]];
                            dd.Uploader = ii.Uploader;
                            dd.Published = DateTime.Parse(ii.Published);
                            dd.EHash = ii.URL.Split('/')[5];
                            dd.Files = ii.Files.Split(' ')[0].ToInt();
                            if (ii.Title.StartsWith("("))
                            {
                                dd.Class = ii.Title.Split("(")[1].Split(")")[0];
                            }
                        }

                        return dd;
                    }));
                    db.Close();
                }

                Console.WriteLine("Complete-Korean");

                {
                    var db = new SQLiteConnection("hitomidata-japanese.db");
                    var info = db.GetTableInfo(typeof(HitomiColumnModel).Name);
                    if (!info.Any())
                        db.CreateTable<HitomiColumnModel>();
                    db.InsertAll(HitomiData.Instance.metadata_collection.Where(md => md.Language == null || md.Language == "" || md.Language == "japanese").Select(md =>
                    {
                        var dd = new HitomiColumnModel
                        {
                            Id = md.ID,
                            Artists = (md.Artists != null && md.Artists.Length > 0 && md.Artists[0] != "" ? "|" + string.Join("|", md.Artists) + "|" : "N/A|"),
                            Characters = (md.Characters != null && md.Characters.Length > 0 && md.Characters[0] != "" ? "|" + string.Join("|", md.Characters) + "|" : null),
                            Groups = (md.Groups != null && md.Groups.Length > 0 && md.Groups[0] != "" ? "|" + string.Join("|", md.Groups) + "|" : null),
                            Series = (md.Parodies != null && md.Parodies.Length > 0 && md.Parodies[0] != "" ? "|" + string.Join("|", md.Parodies) + "|" : null),
                            Title = md.Name,
                            Tags = (md.Tags != null && md.Tags.Length > 0 && md.Tags[0] != "" ? "|" + string.Join("|", md.Tags) + "|" : null),
                            Type = md.Type,
                            Language = md.Language,

                        };

                        if (dict.ContainsKey(md.ID.ToString()))
                        {
                            var ii = xxx[dict[md.ID.ToString()]];
                            dd.Uploader = ii.Uploader;
                            dd.Published = DateTime.Parse(ii.Published);
                            dd.EHash = ii.URL.Split('/')[5];
                            dd.Files = ii.Files.Split(' ')[0].ToInt();
                            if (ii.Title.StartsWith("("))
                            {
                                dd.Class = ii.Title.Split("(")[1].Split(")")[0];
                            }
                        }

                        return dd;
                    }));
                    db.Close();
                }

                Console.WriteLine("Complete-Japanese");

                {
                    var db = new SQLiteConnection("hitomidata-english.db");
                    var info = db.GetTableInfo(typeof(HitomiColumnModel).Name);
                    if (!info.Any())
                        db.CreateTable<HitomiColumnModel>();
                    db.InsertAll(HitomiData.Instance.metadata_collection.Where(md => md.Language == null || md.Language == "" || md.Language == "english").Select(md =>
                    {
                        var dd = new HitomiColumnModel
                        {
                            Id = md.ID,
                            Artists = (md.Artists != null && md.Artists.Length > 0 && md.Artists[0] != "" ? "|" + string.Join("|", md.Artists) + "|" : "N/A|"),
                            Characters = (md.Characters != null && md.Characters.Length > 0 && md.Characters[0] != "" ? "|" + string.Join("|", md.Characters) + "|" : null),
                            Groups = (md.Groups != null && md.Groups.Length > 0 && md.Groups[0] != "" ? "|" + string.Join("|", md.Groups) + "|" : null),
                            Series = (md.Parodies != null && md.Parodies.Length > 0 && md.Parodies[0] != "" ? "|" + string.Join("|", md.Parodies) + "|" : null),
                            Title = md.Name,
                            Tags = (md.Tags != null && md.Tags.Length > 0 && md.Tags[0] != "" ? "|" + string.Join("|", md.Tags) + "|" : null),
                            Type = md.Type,
                            Language = md.Language,

                        };

                        if (dict.ContainsKey(md.ID.ToString()))
                        {
                            var ii = xxx[dict[md.ID.ToString()]];
                            dd.Uploader = ii.Uploader;
                            dd.Published = DateTime.Parse(ii.Published);
                            dd.EHash = ii.URL.Split('/')[5];
                            dd.Files = ii.Files.Split(' ')[0].ToInt();
                            if (ii.Title.StartsWith("("))
                            {
                                dd.Class = ii.Title.Split("(")[1].Split(")")[0];
                            }
                        }

                        return dd;
                    }));
                    db.Close();
                }

                Console.WriteLine("Complete-English");

                {
                    var db = new SQLiteConnection("hitomidata-chinese.db");
                    var info = db.GetTableInfo(typeof(HitomiColumnModel).Name);
                    if (!info.Any())
                        db.CreateTable<HitomiColumnModel>();
                    db.InsertAll(HitomiData.Instance.metadata_collection.Where(md => md.Language == null || md.Language == "" || md.Language == "chinese").Select(md =>
                    {
                        var dd = new HitomiColumnModel
                        {
                            Id = md.ID,
                            Artists = (md.Artists != null && md.Artists.Length > 0 && md.Artists[0] != "" ? "|" + string.Join("|", md.Artists) + "|" : "N/A|"),
                            Characters = (md.Characters != null && md.Characters.Length > 0 && md.Characters[0] != "" ? "|" + string.Join("|", md.Characters) + "|" : null),
                            Groups = (md.Groups != null && md.Groups.Length > 0 && md.Groups[0] != "" ? "|" + string.Join("|", md.Groups) + "|" : null),
                            Series = (md.Parodies != null && md.Parodies.Length > 0 && md.Parodies[0] != "" ? "|" + string.Join("|", md.Parodies) + "|" : null),
                            Title = md.Name,
                            Tags = (md.Tags != null && md.Tags.Length > 0 && md.Tags[0] != "" ? "|" + string.Join("|", md.Tags) + "|" : null),
                            Type = md.Type,
                            Language = md.Language,

                        };

                        if (dict.ContainsKey(md.ID.ToString()))
                        {
                            var ii = xxx[dict[md.ID.ToString()]];
                            dd.Uploader = ii.Uploader;
                            dd.Published = DateTime.Parse(ii.Published);
                            dd.EHash = ii.URL.Split('/')[5];
                            dd.Files = ii.Files.Split(' ')[0].ToInt();
                            if (ii.Title.StartsWith("("))
                            {
                                dd.Class = ii.Title.Split("(")[1].Split(")")[0];
                            }
                        }

                        return dd;
                    }));
                    db.Close();
                }

                Console.WriteLine("Complete-Chinese");
            }
//#endif
        }

        static void download_data(string url, string filename)
        {
            Logs.Instance.Push($"Download {filename}...");
            var task = NetTask.MakeDefault(url);

            SingleFileProgressBar pb = null;
            long tsz = 0;
            task.SizeCallback = (sz) =>
            {
                Console.Write("Downloading ... ");
                pb = new SingleFileProgressBar();
                pb.Report(sz, 0);
                tsz = sz;
            };
            task.Filename = filename;
            task.DownloadCallback = (sz) => pb.Report(tsz, sz);
            NetTools.DownloadFile(task);
            pb.Dispose();
            Console.WriteLine("Complete!");
        }
    }
}
