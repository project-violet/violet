using hsync.Utils;
using MessagePack;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace hsync.Component
{
    [MessagePackObject]
    public class HitomiIndexModel
    {
        [Key(0)]
        public string[] Artists;
        [Key(1)]
        public string[] Groups;
        [Key(2)]
        public string[] Series;
        [Key(3)]
        public string[] Characters;
        [Key(4)]
        public string[] Languages;
        [Key(5)]
        public string[] Types;
        [Key(6)]
        public string[] Tags;
    }

    [MessagePackObject]
    public struct HitomiIndexMetadata
    {
        [Key(0)]
        public int[] Artists { get; set; }
        [Key(1)]
        public int[] Groups { get; set; }
        [Key(2)]
        public int[] Parodies { get; set; }
        [Key(3)]
        public int[] Tags { get; set; }
        [Key(4)]
        public int[] Characters { get; set; }
        [Key(5)]
        public int Language { get; set; }
        [Key(6)]
        public string Name { get; set; }
        [Key(7)]
        public int Type { get; set; }
        [Key(8)]
        public int ID { get; set; }

        [JsonIgnore]
        public DateTime? DateTime;
    }

    [MessagePackObject]
    public class HitomiIndexDataModel
    {
        [Key(0)]
        public HitomiIndexModel index;
        [Key(1)]
        public List<HitomiIndexMetadata> metadata;
    }

    public class HitomiIndex : ILazy<HitomiIndex>
    {
        private static void add(Dictionary<string, int> dic, string arr)
        {
            if (arr == null) return;
            if (!dic.ContainsKey(arr))
                dic.Add(arr, dic.Count);
        }

        private static void add(Dictionary<string, int> dic, string[] arr)
        {
            if (arr == null) return;
            foreach (var item in arr)
                if (!dic.ContainsKey(item))
                    dic.Add(item, dic.Count);
        }

        private static string[] pp(Dictionary<string, int> dic)
        {
            var list = dic.ToList();
            list.Sort((x, y) => x.Value.CompareTo(y.Value));
            return list.Select(x => x.Key).ToArray();
        }

        public static (HitomiIndexModel, List<HitomiIndexMetadata>) MakeIndexF()
        {
            var artists = new Dictionary<string, int>();
            var groups = new Dictionary<string, int>();
            var series = new Dictionary<string, int>();
            var characters = new Dictionary<string, int>();
            var languages = new Dictionary<string, int>();
            var types = new Dictionary<string, int>();
            var tags = new Dictionary<string, int>();

            foreach (var md in HitomiData.Instance.metadata_collection)
            {
                add(artists, md.Artists);
                add(groups, md.Groups);
                add(series, md.Parodies);
                add(characters, md.Characters);
                if (md.Language != null)
                    add(languages, md.Language.ToLower());
                else
                    add(languages, md.Language);
                if (md.Type != null)
                    add(types, md.Type.ToLower());
                else
                    add(types, md.Type);
                add(tags, md.Tags);
            }

            var index = new HitomiIndexModel();

            index.Artists = pp(artists);
            index.Groups = pp(groups);
            index.Series = pp(series);
            index.Characters = pp(characters);
            index.Languages = pp(languages);
            index.Types = pp(types);
            index.Tags = pp(tags);

            var mdl = new List<HitomiIndexMetadata>();

            foreach (var md in HitomiData.Instance.metadata_collection)
            {
                var him = new HitomiIndexMetadata();
                him.ID = md.ID;
                him.Name = md.Name;
                if (md.Artists != null) him.Artists = md.Artists.Select(x => artists[x]).ToArray();
                if (md.Groups != null) him.Groups = md.Groups.Select(x => groups[x]).ToArray();
                if (md.Parodies != null) him.Parodies = md.Parodies.Select(x => series[x]).ToArray();
                if (md.Characters != null) him.Characters = md.Characters.Select(x => characters[x]).ToArray();
                if (md.Language != null) him.Language = languages[md.Language.ToLower()]; else him.Language = -1;
                if (md.Type != null) him.Type = types[md.Type.ToLower()]; else him.Type = -1;
                if (md.Tags != null) him.Tags = md.Tags.Select(x => tags[x]).ToArray();
                him.DateTime = md.DateTime;
                mdl.Add(him);
            }

            return (index, mdl);
        }

        public static void MakeIndex()
        {
            var artists = new Dictionary<string, int>();
            var groups = new Dictionary<string, int>();
            var series = new Dictionary<string, int>();
            var characters = new Dictionary<string, int>();
            var languages = new Dictionary<string, int>();
            var types = new Dictionary<string, int>();
            var tags = new Dictionary<string, int>();

            foreach (var md in HitomiData.Instance.metadata_collection)
            {
                add(artists, md.Artists);
                add(groups, md.Groups);
                add(series, md.Parodies);
                add(characters, md.Characters);
                if (md.Language != null)
                    add(languages, md.Language.ToLower());
                else
                    add(languages, md.Language);
                if (md.Type != null)
                    add(types, md.Type.ToLower());
                else
                    add(types, md.Type);
                add(tags, md.Tags);
            }

            var index = new HitomiIndexModel();

            index.Artists = pp(artists);
            index.Groups = pp(groups);
            index.Series = pp(series);
            index.Characters = pp(characters);
            index.Languages = pp(languages);
            index.Types = pp(types);
            index.Tags = pp(tags);

            var mdl = new List<HitomiIndexMetadata>();

            foreach (var md in HitomiData.Instance.metadata_collection)
            {
                var him = new HitomiIndexMetadata();
                him.ID = md.ID;
                him.Name = md.Name;
                if (md.Artists != null) him.Artists = md.Artists.Select(x => artists[x]).ToArray();
                if (md.Groups != null) him.Groups = md.Groups.Select(x => groups[x]).ToArray();
                if (md.Parodies != null) him.Parodies = md.Parodies.Select(x => series[x]).ToArray();
                if (md.Characters != null) him.Characters = md.Characters.Select(x => characters[x]).ToArray();
                if (md.Language != null) him.Language = languages[md.Language.ToLower()]; else him.Language = -1;
                if (md.Type != null) him.Type = types[md.Type.ToLower()]; else him.Type = -1;
                if (md.Tags != null) him.Tags = md.Tags.Select(x => tags[x]).ToArray();
                mdl.Add(him);
            }

            var result = new HitomiIndexDataModel();
            result.index = index;
            result.metadata = mdl;

            var bbb = MessagePackSerializer.Serialize(result);
            using (FileStream fsStream = new FileStream("index-metadata.json", FileMode.Create))
            using (BinaryWriter sw = new BinaryWriter(fsStream))
            {
                sw.Write(bbb);
            }
        }

    }
}
