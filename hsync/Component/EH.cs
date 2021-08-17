// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using HtmlAgilityPack;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using hsync.Log;
using System.Text.RegularExpressions;

namespace hsync.Component
{
    public class EHentaiArticle
    {
        public string Thumbnail { get; set; }

        public string Title { get; set; }
        public string SubTitle { get; set; }

        public string Type { get; set; }
        public string Uploader { get; set; }

        public string Posted;
        public string Parent;
        public string Visible;
        public string Language;
        public string FileSize;
        public int Length;
        public int Favorited;

        public string reclass;
        public string[] language;
        public string[] group;
        public string[] parody;
        public string[] character;
        public string[] artist;
        public string[] male;
        public string[] female;
        public string[] misc;

        public Tuple<DateTime, string, string>[] comment;
        public List<string> ImagesLink { get; set; }
        public string Archive { get; set; }
    }

    public class EHentaiResultArticle
    {
        public string URL;

        public string Thumbnail;
        public string Title;

        public string Uploader;
        public string Published;
        public string Files;
        public string Type;

        public Dictionary<string, List<string>> Descripts;
    }

    public class EHentaiParser
    {
        public static EHentaiArticle ParseArticleData(string source)
        {
            EHentaiArticle article = new EHentaiArticle();

            HtmlDocument document = new HtmlDocument();
            document.LoadHtml(source);
            HtmlNode nodes = document.DocumentNode.SelectNodes("//div[@class='gm']")[0];

            article.Thumbnail = Regex.Match(nodes.SelectSingleNode(".//div[@id='gleft']//div//div").GetAttributeValue("style", ""), @"https://ehgt.org/.*?(?=\))").Groups[0].Value;

            article.Title = nodes.SelectSingleNode(".//div[@id='gd2']//h1[@id='gn']").InnerText;
            article.SubTitle = nodes.SelectSingleNode(".//div[@id='gd2']//h1[@id='gj']").InnerText;

            // article.Type = nodes.SelectSingleNode(".//div[@id='gmid']//div//div[@id='gdc']//a//img").GetAttributeValue("alt", "");
            article.Uploader = nodes.SelectSingleNode(".//div[@id='gmid']//div//div[@id='gdn']//a").InnerText;

            HtmlNodeCollection nodes_static = nodes.SelectNodes(".//div[@id='gmid']//div//div[@id='gdd']//table//tr");

            article.Posted = nodes_static[0].SelectSingleNode(".//td[@class='gdt2']").InnerText;
            article.Parent = nodes_static[1].SelectSingleNode(".//td[@class='gdt2']").InnerText;
            article.Visible = nodes_static[2].SelectSingleNode(".//td[@class='gdt2']").InnerText;
            article.Language = nodes_static[3].SelectSingleNode(".//td[@class='gdt2']").InnerText.Split(' ')[0].ToLower();
            article.FileSize = nodes_static[4].SelectSingleNode(".//td[@class='gdt2']").InnerText;
            int.TryParse(nodes_static[5].SelectSingleNode(".//td[@class='gdt2']").InnerText.Split(' ')[0], out article.Length);
            int.TryParse(nodes_static[6].SelectSingleNode(".//td[@class='gdt2']").InnerText.Split(' ')[0], out article.Favorited);

            HtmlNodeCollection nodes_data = nodes.SelectNodes(".//div[@id='gmid']//div[@id='gd4']//table//tr");

            Dictionary<string, string[]> information = new Dictionary<string, string[]>();

            foreach (var i in nodes_data)
            {
                try
                {
                    information.Add(i.SelectNodes(".//td")[0].InnerText.Trim(),
                        i.SelectNodes(".//td")[1].SelectNodes(".//div").Select(e => e.SelectSingleNode(".//a").InnerText).ToArray());
                }
                catch { }
            }

            if (information.ContainsKey("language:")) article.language = information["language:"];
            if (information.ContainsKey("group:")) article.group = information["group:"];
            if (information.ContainsKey("parody:")) article.parody = information["parody:"];
            if (information.ContainsKey("character:")) article.character = information["character:"];
            if (information.ContainsKey("artist:")) article.artist = information["artist:"];
            if (information.ContainsKey("male:")) article.male = information["male:"];
            if (information.ContainsKey("female:")) article.female = information["female:"];
            if (information.ContainsKey("misc:")) article.misc = information["misc:"];

            HtmlNode nodesc = document.DocumentNode.SelectNodes("//div[@id='cdiv']")[0];
            HtmlNodeCollection nodes_datac = nodesc.SelectNodes(".//div[@class='c1']");
            List<Tuple<DateTime, string, string>> comments = new List<Tuple<DateTime, string, string>>();

            foreach (var i in nodes_datac ?? Enumerable.Empty<HtmlNode>())
            {
                try
                {
                    string date = WebUtility.HtmlDecode(i.SelectNodes(".//div[@class='c2']//div[@class='c3']")[0].InnerText.Trim());
                    string author = WebUtility.HtmlDecode(i.SelectNodes(".//div[@class='c2']//div[@class='c3']//a")[0].InnerText.Trim());
                    string contents = Regex.Replace(WebUtility.HtmlDecode(i.SelectNodes(".//div[@class='c6']")[0].InnerHtml.Trim()), @"<br>", "\r\n");
                    comments.Add(new Tuple<DateTime, string, string>(
                        DateTime.Parse(date.Remove(date.IndexOf(" UTC")).Substring("Posted on ".Length) + "Z"),
                        author,
                        contents));
                }
                catch { }
            }

            comments.Sort((a, b) => a.Item1.CompareTo(b.Item1));
            article.comment = comments.ToArray();

            return article;
        }
    }

    public class ExHentaiParser
    {
        public static EHentaiArticle ParseArticleData(string source)
        {
            EHentaiArticle article = new EHentaiArticle();

            HtmlDocument document = new HtmlDocument();
            document.LoadHtml(source);
            HtmlNode nodes = document.DocumentNode.SelectNodes("//div[@class='gm']")[0];

            article.Thumbnail = Regex.Match(nodes.SelectSingleNode(".//div[@id='gleft']//div//div").GetAttributeValue("style", ""), @"https://exhentai.org/.*?(?=\))").Groups[0].Value;

            article.Title = nodes.SelectSingleNode(".//div[@id='gd2']//h1[@id='gn']").InnerText;
            article.SubTitle = nodes.SelectSingleNode(".//div[@id='gd2']//h1[@id='gj']").InnerText;

            //article.Type = nodes.SelectSingleNode(".//div[@id='gmid']//div//div[@id='gdc']//a//img").GetAttributeValue("alt", "");
            article.Uploader = nodes.SelectSingleNode(".//div[@id='gmid']//div//div[@id='gdn']//a").InnerText;

            HtmlNodeCollection nodes_static = nodes.SelectNodes(".//div[@id='gmid']//div//div[@id='gdd']//table//tr");

            article.Posted = nodes_static[0].SelectSingleNode(".//td[@class='gdt2']").InnerText;
            article.Parent = nodes_static[1].SelectSingleNode(".//td[@class='gdt2']").InnerText;
            article.Visible = nodes_static[2].SelectSingleNode(".//td[@class='gdt2']").InnerText;
            article.Language = nodes_static[3].SelectSingleNode(".//td[@class='gdt2']").InnerText.Split(' ')[0].ToLower();
            article.FileSize = nodes_static[4].SelectSingleNode(".//td[@class='gdt2']").InnerText;
            int.TryParse(nodes_static[5].SelectSingleNode(".//td[@class='gdt2']").InnerText.Split(' ')[0], out article.Length);
            int.TryParse(nodes_static[6].SelectSingleNode(".//td[@class='gdt2']").InnerText.Split(' ')[0], out article.Favorited);

            HtmlNodeCollection nodes_data = nodes.SelectNodes(".//div[@id='gmid']//div[@id='gd4']//table//tr");

            Dictionary<string, string[]> information = new Dictionary<string, string[]>();

            foreach (var i in nodes_data)
            {
                try
                {
                    information.Add(i.SelectNodes(".//td")[0].InnerText.Trim(),
                        i.SelectNodes(".//td")[1].SelectNodes(".//div").Select(e => e.SelectSingleNode(".//a").InnerText).ToArray());
                }
                catch { }
            }

            if (information.ContainsKey("language:")) article.language = information["language:"];
            if (information.ContainsKey("group:")) article.group = information["group:"];
            if (information.ContainsKey("parody:")) article.parody = information["parody:"];
            if (information.ContainsKey("character:")) article.character = information["character:"];
            if (information.ContainsKey("artist:")) article.artist = information["artist:"];
            if (information.ContainsKey("male:")) article.male = information["male:"];
            if (information.ContainsKey("female:")) article.female = information["female:"];
            if (information.ContainsKey("misc:")) article.misc = information["misc:"];

            HtmlNode nodesc = document.DocumentNode.SelectNodes("//div[@id='cdiv']")[0];
            HtmlNodeCollection nodes_datac = nodesc.SelectNodes(".//div[@class='c1']");
            List<Tuple<DateTime, string, string>> comments = new List<Tuple<DateTime, string, string>>();

            foreach (var i in nodes_datac ?? Enumerable.Empty<HtmlNode>())
            {
                try
                {
                    string date = WebUtility.HtmlDecode(i.SelectNodes(".//div[@class='c2']//div[@class='c3']")[0].InnerText.Trim());
                    string author = WebUtility.HtmlDecode(i.SelectNodes(".//div[@class='c2']//div[@class='c3']//a")[0].InnerText.Trim());
                    string contents = Regex.Replace(WebUtility.HtmlDecode(i.SelectNodes(".//div[@class='c6']")[0].InnerHtml.Trim()), @"<br>", "\r\n");
                    comments.Add(new Tuple<DateTime, string, string>(
                        DateTime.Parse(date.Remove(date.IndexOf(" by")).Substring("Posted on ".Length) + "Z"),
                        author,
                        contents));
                }
                catch (Exception e)
                {
                    Logs.Instance.PushError("[Fail] \r\n" + Logs.SerializeObject(e));
                }
            }

            comments.Sort((a, b) => a.Item1.CompareTo(b.Item1));
            article.comment = comments.ToArray();

            return article;
        }

        /// <summary>
        /// 결과 페이지를 분석합니다.
        /// ex: https://exhentai.org/
        /// ex: https://exhentai.org/?inline_set=dm_t
        /// ex: https://exhentai.org/?page=1
        /// </summary>
        /// <param name="html"></param>
        /// <returns></returns>
        public static List<EHentaiResultArticle> ParseResultPageThumbnailView(string html)
        {
            var result = new List<EHentaiResultArticle>();

            var document = new HtmlDocument();
            document.LoadHtml(html);
            var nodes = document.DocumentNode.SelectNodes("//div[@class='itg']/div[@class='id1']");

            foreach (var node in nodes)
            {
                try
                {
                    var article = new EHentaiResultArticle();

                    article.URL = node.SelectSingleNode("./div[@class='id2']/a").GetAttributeValue("href", "");

                    try { article.Thumbnail = node.SelectSingleNode("./div[@class='id3']/a/img").GetAttributeValue("src", ""); } catch { }
                    article.Title = node.SelectSingleNode("./div[@class='id2']/a").InnerText;

                    article.Files = node.SelectSingleNode(".//div[@class='id42']").InnerText;
                    article.Type = node.SelectSingleNode(".//div[@class='id41']").GetAttributeValue("title", "");

                    result.Add(article);
                }
                catch { }
            }

            return result;
        }

        /// <summary>
        /// 결과 페이지를 분석합니다.
        /// ex: https://exhentai.org/
        /// ex: https://exhentai.org/?inline_set=dm_l
        /// ex: https://exhentai.org/?page=1
        /// </summary>
        /// <param name="html"></param>
        /// <returns></returns>
        public static List<EHentaiResultArticle> ParseResultPageListView(string html)
        {
            var result = new List<EHentaiResultArticle>();

            var document = new HtmlDocument();
            document.LoadHtml(html);
            var nodes = document.DocumentNode.SelectNodes("//table[@class='itg']/tr");

            if (nodes.Count > 1) nodes.RemoveAt(0);

            foreach (var node in nodes)
            {
                try
                {
                    var article = new EHentaiResultArticle();

                    article.URL = node.SelectSingleNode("./td[3]/div/div[@class='it5']/a").GetAttributeValue("href", "");

                    try { article.Thumbnail = node.SelectSingleNode("./td[3]/div/div[@class='it2']/img").GetAttributeValue("src", ""); } catch { }
                    article.Title = node.SelectSingleNode("./td[3]/div/div[@class='it5']/a").InnerText;

                    article.Uploader = node.SelectSingleNode("./td[4]/div/a").GetAttributeValue("href", "");
                    article.Published = node.SelectSingleNode("./td[2]").InnerText;
                    article.Type = node.SelectSingleNode("./td/a/img").GetAttributeValue("alt", "");

                    result.Add(article);
                }
                catch { }
            }

            return result;
        }

        /// <summary>
        /// 결과 페이지를 분석합니다.
        /// ex: https://exhentai.org/?inline_set=dm_e
        /// </summary>
        /// <param name="html"></param>
        /// <returns></returns>
        public static List<EHentaiResultArticle> ParseResultPageExtendedListView(string html)
        {
            var result = new List<EHentaiResultArticle>();

            var document = new HtmlDocument();
            document.LoadHtml(html);

            Queue<HtmlNode> nodes = new Queue<HtmlNode>();
            var fn = document.DocumentNode.SelectNodes("//table[@class='itg glte']/tr");
            fn.ToList().ForEach(x => nodes.Enqueue(x));

            while (nodes.Count != 0)
            {
                var node = nodes.Dequeue();
                try
                {
                    var article = new EHentaiResultArticle();

                    article.URL = node.SelectSingleNode(".//a").GetAttributeValue("href", "");
                    try { article.Thumbnail = node.SelectSingleNode(".//img").GetAttributeValue("src", ""); } catch { }

                    var g13 = node.SelectSingleNode("./td[2]/div/div");

                    article.Type = g13.SelectSingleNode("./div").InnerText.ToLower();
                    article.Published = g13.SelectSingleNode("./div[2]").InnerText;
                    article.Uploader = g13.SelectSingleNode("./div[4]").InnerText;
                    article.Files = g13.SelectSingleNode("./div[5]").InnerText;

                    var gref = node.SelectSingleNode("./td[2]/div/a/div");

                    article.Title = gref.SelectSingleNode("./div").InnerText;

                    if (article.Title.Contains("느와카나"))
                        ;

                    try
                    {
                        var desc = gref.SelectNodes("./div//tr");
                        var desc_dic = new Dictionary<string, List<string>>();

                        foreach (var nn in desc)
                        {
                            var cont = nn.SelectSingleNode("./td").InnerText.Trim();
                            cont = cont.Remove(cont.Length - 1);

                            var cc = new List<string>();

                            foreach (var ccc in nn.SelectNodes("./td[2]//div"))
                            {
                                cc.Add(ccc.InnerText);
                            }

                            desc_dic.Add(cont, cc);
                        }

                        article.Descripts = desc_dic;
                    }
                    catch { }
                    result.Add(article);

                    var next = node.SelectNodes("./tr");
                    if (next != null)
                        next.ToList().ForEach(x => nodes.Enqueue(x));
                }
                catch { }
            }

            return result;
        }

        /// <summary>
        /// 결과 페이지를 분석합니다.
        /// ex: https://exhentai.org/?inline_set=dm_m
        /// </summary>
        /// <param name="html"></param>
        /// <returns></returns>
        public static List<EHentaiResultArticle> ParseResultPageMinimalListView(string html)
        {
            var result = new List<EHentaiResultArticle>();

            var document = new HtmlDocument();
            document.LoadHtml(html);

            HtmlNodeCollection nodes = document.DocumentNode.SelectNodes("//table[@class='itg gltm']/tr");

            for (int i = 1; i < nodes.Count; i++)
            {
                var node = nodes[i];

                var article = new EHentaiResultArticle();

                article.Type = node.SelectSingleNode("./td/div").InnerText.Trim().ToLower();
                article.Thumbnail = node.SelectSingleNode(".//img").GetAttributeValue("src", "");
                if (article.Thumbnail.StartsWith("data"))
                    article.Thumbnail = node.SelectSingleNode(".//img").GetAttributeValue("data-src", "");
                article.Published = node.SelectSingleNode("./td[2]/div[2]/div[2]/div[1]/div[2]").InnerText.Trim();
                article.Files = node.SelectSingleNode("./td[2]/div[2]/div[2]/div[2]/div[2]").InnerText.Trim();

                article.URL = node.SelectSingleNode("./td[4]/a").GetAttributeValue("href", "");
                article.Title = node.SelectSingleNode("./td[4]/a/div").InnerText.Trim();
                article.Uploader = node.SelectSingleNode("./td[6]/div/a").InnerText.Trim();

                result.Add(article);
            }

            return result;
        }
    }
}
