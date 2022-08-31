// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using hsync.Utils;
using HtmlAgilityPack;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using SQLite;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace hsync.Component
{
    public struct HitomiMetadata
    {
        [JsonProperty(PropertyName = "a")]
        public string[] Artists { get; set; }
        [JsonProperty(PropertyName = "g")]
        public string[] Groups { get; set; }
        [JsonProperty(PropertyName = "p")]
        public string[] Parodies { get; set; }
        [JsonProperty(PropertyName = "t")]
        public string[] Tags { get; set; }
        [JsonProperty(PropertyName = "c")]
        public string[] Characters { get; set; }
        [JsonProperty(PropertyName = "l")]
        public string Language { get; set; }
        [JsonProperty(PropertyName = "n")]
        public string Name { get; set; }
        [JsonProperty(PropertyName = "type")]
        public string Type { get; set; }
        [JsonProperty(PropertyName = "id")]
        public int ID { get; set; }

        [JsonIgnore]
        public int Files { get; set; }

        [JsonIgnore]
        public DateTime? DateTime;
    }

    public class HitomiArticle
    {
        public string[] Artists { get; set; }
        public string[] Characters { get; set; }
        public string[] Groups { get; set; }
        public string Language { get; set; }
        public string[] Series { get; set; }
        public string[] Tags { get; set; }
        public string Type { get; set; }
        public bool ManualPathOrdering { get; set; }
        public string ManualAdditionalPath { get; set; }
        public string DateTime { get; set; }

        public string Thumbnail { get; set; }
        public string Magic { get; set; }
        public string Title { get; set; }
        public string Files { get; set; }
    }

    public abstract class SQLiteColumnModel
    {
        [PrimaryKey]
        public int Id { get; set; }
    }

    public class HitomiColumnModel : SQLiteColumnModel
    {
        public string Title { get; set; }
        public string EHash { get; set; }
        public string Type { get; set; }
        public string Artists { get; set; }
        public string Characters { get; set; }
        public string Groups { get; set; }
        public string Language { get; set; }
        public string Series { get; set; }
        public string Tags { get; set; }
        public string Uploader { get; set; }
        public DateTime? Published { get; set; }
        public int Files { get; set; }
        public string Class { get; set; }
        public int ExistOnHitomi { get; set; }
        public string Thumbnail { get; set; }
    }

    public class HitomiIndexArtistsColumnModel : SQLiteColumnModel { public string Tag { get; set; } }
    public class HitomiIndexGroupsColumnModel : SQLiteColumnModel { public string Tag { get; set; } }
    public class HitomiIndexSeriesColumnModel : SQLiteColumnModel { public string Tag { get; set; } }
    public class HitomiIndexCharactersColumnModel : SQLiteColumnModel { public string Tag { get; set; } }
    public class HitomiIndexLanguagesColumnModel : SQLiteColumnModel { public string Tag { get; set; } }
    public class HitomiIndexTypesColumnModel : SQLiteColumnModel { public string Tag { get; set; } }
    public class HitomiIndexTagsColumnModel : SQLiteColumnModel { public string Tag { get; set; } }

    //public class HitomiIndexModel : SQLiteColumnModel
    //{
    //    public string Name { get; set; }
    //    public int Index { get; set; }
    //}

    public class HitomiLegalize
    {
        public static HitomiMetadata ArticleToMetadata(HitomiArticle article)
        {
            HitomiMetadata metadata = new HitomiMetadata();
            if (article.Artists != null) metadata.Artists = article.Artists;
            if (article.Characters != null) metadata.Characters = article.Characters;
            if (article.Groups != null) metadata.Groups = article.Groups;
            try
            {
                if (article.Magic.Contains("-"))
                    metadata.ID = Convert.ToInt32(article.Magic.Split('-').Last().Split('.')[0]);
                else if (article.Magic.Contains("galleries"))
                    metadata.ID = Convert.ToInt32(article.Magic.Split('/').Last().Split('.')[0]);
                else
                    metadata.ID = Convert.ToInt32(article.Magic);
            }
            catch
            {
                ;
            }
            metadata.Language = LegalizeLanguage(article.Language);
            metadata.Name = article.Title;
            if (article.Series != null) metadata.Parodies = article.Series;
            if (article.Tags != null) metadata.Tags = article.Tags.Select(x => LegalizeTag(x)).ToArray();
            metadata.Type = article.Type;
            if (article.Files != null) metadata.Files = Convert.ToInt32(article.Files);
            if (article.DateTime != null)
            metadata.DateTime = DateTime.Parse(article.DateTime);
            return metadata;
        }

        public static string LegalizeTag(string tag)
        {
            if (tag.Trim().EndsWith("♀")) return "female:" + tag.Trim('♀').Trim();
            if (tag.Trim().EndsWith("♂")) return "male:" + tag.Trim('♂').Trim();
            return tag.Trim();
        }

        public static string LegalizeLanguage(string lang)
        {
            switch (lang)
            {
                case "모든 언어": return "all";
                case "한국어": return "korean";
                case "N/A": return "n/a";
                case "日本語": return "japanese";
                case "English": return "english";
                case "Español": return "spanish";
                case "ไทย": return "thai";
                case "Deutsch": return "german";
                case "中文": return "chinese";
                case "Português": return "portuguese";
                case "Français": return "french";
                case "Tagalog": return "tagalog";
                case "Русский": return "russian";
                case "Italiano": return "italian";
                case "polski": return "polish";
                case "tiếng việt": return "vietnamese";
                case "magyar": return "hungarian";
                case "Čeština": return "czech";
                case "Bahasa Indonesia": return "indonesian";
                case "العربية": return "arabic";
            }

            return lang;
        }

        public static string DeLegalizeLanguage(string lang)
        {
            switch (lang)
            {
                case "all": return "모든 언어";
                case "korean": return "한국어";
                case "n/a": return "N/A";
                case "japanese": return "日本語";
                case "english": return "English";
                case "spanish": return "Español";
                case "thai": return "ไทย";
                case "german": return "Deutsch";
                case "chinese": return "中文";
                case "portuguese": return "Português";
                case "french": return "Français";
                case "tagalog": return "Tagalog";
                case "russian": return "Русский";
                case "italian": return "Italiano";
                case "polish": return "polski";
                case "vietnamese": return "tiếng việt";
                case "hungarian": return "magyar";
                case "czech": return "Čeština";
                case "indonesian": return "Bahasa Indonesia";
                case "arabic": return "العربية";
            }

            return lang;
        }
    }

    public class HitomiParser
    {
        static public HitomiArticle ParseGalleryBlock(string source)
        {
            HitomiArticle article = new HitomiArticle();

            HtmlDocument document = new HtmlDocument();
            document.LoadHtml(source);
            HtmlNode nodes = document.DocumentNode.SelectNodes("/div")[0];

            article.Magic = nodes.SelectSingleNode("./a").GetAttributeValue("href", "");
            try { article.Thumbnail = nodes.SelectSingleNode("./a//img").GetAttributeValue("data-src", "").Substring("//tn.hitomi.la/".Length).Replace("smallbig", "big"); }
            catch
            { article.Thumbnail = nodes.SelectSingleNode("./a//img").GetAttributeValue("src", "").Substring("//tn.hitomi.la/".Length); }
            article.Title = nodes.SelectSingleNode("./h1").InnerText;

            try { article.Artists = nodes.SelectNodes(".//div[@class='artist-list']//li").Select(node => node.SelectSingleNode("./a").InnerText).ToArray(); }
            catch { article.Artists = new[] { "N/A" }; }

            var contents = nodes.SelectSingleNode("./div[2]/table");
            try { article.Series = contents.SelectNodes("./tr[1]/td[2]/ul/li").Select(node => node.SelectSingleNode(".//a").InnerText).ToArray(); } catch { }
            article.Type = contents.SelectSingleNode("./tr[2]/td[2]/a").InnerText;
            try { article.Language = HitomiLegalize.LegalizeLanguage(contents.SelectSingleNode("./tr[3]/td[2]/a").InnerText); } catch { }
            try { article.Tags = contents.SelectNodes("./tr[4]/td[2]/ul/li").Select(node => HitomiLegalize.LegalizeTag(node.SelectSingleNode(".//a").InnerText)).ToArray(); } catch { }

            article.DateTime = nodes.SelectSingleNode("./div[2]/p").InnerText;

            return article;
        }

        static public HitomiArticle ParseGallery(string source)
        {
            HitomiArticle article = new HitomiArticle();

            HtmlDocument document = new HtmlDocument();
            document.LoadHtml(source);
            HtmlNode nodes = document.DocumentNode.SelectSingleNode("//div[@class='content']");

            try
            {
                article.Magic = nodes.SelectSingleNode("./div[3]/h1/a").GetAttributeValue("href", "").Split('/')[2].Split('.')[0];
            }
            catch
            {
                ;
            }
            //article.Title = nodes.SelectSingleNode("./div[3]/h1").InnerText.Trim();
            //article.Thumbnail = nodes.SelectSingleNode("./div[2]/div/a/img").GetAttributeValue("src", "");
            //article.Artists = nodes.SelectSingleNode(".")

            foreach (var tr in document.DocumentNode.SelectNodes("//div[@class='gallery-info']/table/tr").ToList())
            {
                var tt = tr.SelectSingleNode("./td").InnerText.ToLower().Trim();
                if (tt == "group")
                {
                    article.Groups = tr.SelectNodes(".//a")?.Select(x => x.InnerText.Trim()).ToArray();
                }
                else if (tt == "characters")
                {
                    article.Characters = tr.SelectNodes(".//a")?.Select(x => x.InnerText.Trim()).ToArray();
                }
            }

            return article;
        }

        static public void FillGallery(string source, HitomiArticle article)
        {
            HtmlDocument document = new HtmlDocument();
            document.LoadHtml(source);
            HtmlNode nodes = document.DocumentNode.SelectSingleNode("/div[@class='gallery-info']/table/tbody");

            foreach (var tr in nodes.SelectNodes("./tr").ToList())
            {
                var tt = tr.SelectSingleNode("./td").InnerText.ToLower().Trim();
                if (tt == "group")
                {
                    article.Groups = tr.SelectNodes(".//a").Select(x => x.InnerText.Trim()).ToArray();
                }
                else if (tt == "characters")
                {
                    article.Characters = tr.SelectNodes(".//a").Select(x => x.InnerText.Trim()).ToArray();
                }
            }
        }
    }

    public class HitomiData : ILazy<HitomiData>
    {
        public List<HitomiMetadata> metadata_collection;

        public void Load()
        {
            Log.Logs.Instance.Push("Load metadata files...");

            try
            {
                metadata_collection = JsonConvert.DeserializeObject<List<HitomiMetadata>>(File.ReadAllText("metadata.json"));

                var articles = JsonConvert.DeserializeObject<List<HitomiArticle>>(File.ReadAllText("hiddendata.json"));
                var overlap = new HashSet<string>();
                if (metadata_collection == null)
                    metadata_collection = new List<HitomiMetadata>();
                metadata_collection.ForEach(x => overlap.Add(x.ID.ToString()));
                foreach (var article in articles)
                {
                    if (overlap.Contains(article.Magic)) continue;
                    metadata_collection.Add(HitomiLegalize.ArticleToMetadata(article));
                }
                metadata_collection.Sort((a, b) => b.ID.CompareTo(a.ID));
            }
            catch (Exception e)
            {
                Log.Logs.Instance.PushError("Metadata loading error!");
                Log.Logs.Instance.PushException(e);
                Log.Logs.Instance.Panic();
            }
        }

        public void SaveWithNewData(List<HitomiArticle> data)
        {
            var articles = JsonConvert.DeserializeObject<List<HitomiArticle>>(File.ReadAllText("hiddendata.json"));
            File.Move("hiddendata.json", $"hiddendata-{DateTime.Now.Ticks}.json");

            articles.AddRange(data);
            var overlap = new HashSet<string>();
            var pure = new List<HitomiArticle>();
            foreach (var article in articles)
            {
                if (!overlap.Contains(article.Magic))
                {
                    pure.Add(article);
                    overlap.Add(article.Magic);
                }
            }

            JsonSerializer serializer = new JsonSerializer();
            serializer.Converters.Add(new JavaScriptDateTimeConverter());
            serializer.NullValueHandling = NullValueHandling.Ignore;

            using (StreamWriter sw = new StreamWriter("hiddendata.json"))
            using (JsonWriter writer = new JsonTextWriter(sw))
            {
                serializer.Serialize(writer, pure);
            }
        }
    }
}
