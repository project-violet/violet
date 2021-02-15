// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using hsync.Component;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using SQLite;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace hsync
{
    public class SeriesTest
    {
        public string dbdir;
        public List<HitomiColumnModel> target;
        public double threshold;

        public SeriesTest(string dbpath)
        {
            var db = new SQLiteConnection(dbpath);
            var info = db.GetTableInfo(typeof(HitomiColumnModel).Name);

            if (!info.Any())
            {
                Console.WriteLine($"{typeof(HitomiColumnModel).Name} table is not found.");
                return;
            }

            Console.Write("Load database... ");
            target = db.Query<HitomiColumnModel>("SELECT * FROM HitomiColumnModel");
            Console.WriteLine("Ready");

            this.dbdir = Path.GetDirectoryName(dbpath);
        }

        public void Start()
        {
            var tags_dic = new Dictionary<string, Dictionary<string, int>>();

            foreach (var data in target)
            {
                if (data.Series != null && data.Characters != null)
                {
                    foreach (var series in data.Series.Split('|'))
                    {
                        if (series == "") continue;
                        foreach (var tag in data.Characters.Split('|'))
                        {
                            if (tag == "") continue;
                            if (tags_dic.ContainsKey(series))
                            {
                                if (tags_dic[series].ContainsKey(tag))
                                    tags_dic[series][tag] += 1;
                                else
                                    tags_dic[series].Add(tag, 1);
                            }
                            else
                                tags_dic.Add(series, new Dictionary<string, int> { { tag, 1 } });
                        }
                    }
                }
            }

            Console.Write("Save... ");
            var rr = tags_dic.ToList();
            rr.Sort((x, y) => y.Value.Count.CompareTo(x.Value.Count));
            JArray arr = new JArray();
            rr.ForEach(x =>
            {
                JArray tags = new JArray();
                var rx = x.Value.ToList();
                rx.Sort((x, y) => y.Value.CompareTo(x.Value));
                rx.ForEach(y =>
                {
                    tags.Add(new JObject { { y.Key, y.Value } });
                });
                arr.Add(new JObject { { x.Key, tags } });
            });
            File.WriteAllText(Path.Combine(dbdir, "st-result.json"), JsonConvert.SerializeObject(arr, Formatting.Indented));
            Console.WriteLine("Complete");
        }
    }
}
