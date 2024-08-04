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
    public class RelatedTagTest
    {
        public string dbdir;
        public List<HitomiColumnModel> target;
        public double threshold;

        public RelatedTagTest(string dbpath, double threshold)
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

            this.threshold = threshold;
            this.dbdir = Path.GetDirectoryName(dbpath);
        }

        public Dictionary<string, List<Tuple<string, double>>> result = new Dictionary<string, List<Tuple<string, double>>>();

        public Dictionary<string, List<int>> tags_dic = new Dictionary<string, List<int>>();
        public List<KeyValuePair<string, List<int>>> tags_list;
        public List<Tuple<string, string, double>> results = new List<Tuple<string, string, double>>();

        private void Initialize()
        {
            result.Clear();
            results.Clear();
            tags_dic.Clear();
            if (tags_list != null) tags_list.Clear();

            foreach (var data in target)
            {
                if (data.Tags != null)
                {
                    foreach (var tag in data.Tags.Split('|'))
                    {
                        if (tag == "") continue;
                        if (tags_dic.ContainsKey(tag))
                            tags_dic[tag].Add(data.Id);
                        else
                            tags_dic.Add(tag, new List<int> { data.Id });
                    }
                }
            }

            tags_list = tags_dic.ToList();

            tags_list.ForEach(x => x.Value.Sort());
            tags_list.Sort((a, b) => a.Value.Count.CompareTo(b.Value.Count));
        }

        private static int manually_intersect(List<int> a, List<int> b)
        {
            int intersect = 0;
            int i = 0, j = 0;
            for (; i < a.Count && j < b.Count;)
            {
                if (a[i] == b[j])
                {
                    intersect++;
                    i++;
                    j++;
                }
                else if (a[i] < b[j])
                {
                    i++;
                }
                else
                {
                    j++;
                }
            }
            return intersect;
        }

        private List<Tuple<string, string, double>> Intersect(int i)
        {
            List<Tuple<string, string, double>> result = new List<Tuple<string, string, double>>();

            for (int j = i + 1; j < tags_list.Count; j++)
            {
                int intersect = manually_intersect(tags_list[i].Value, tags_list[j].Value);
                int i_size = tags_list[i].Value.Count;
                int j_size = tags_list[j].Value.Count;
                double rate = (double)(intersect) / (i_size + j_size - intersect);
                if (rate >= threshold)
                    result.Add(new Tuple<string, string, double>(tags_list[i].Key, tags_list[j].Key,
                        rate));
            }

            return result;
        }

        private void Merge()
        {
            foreach (var tuple in results)
            {
                if (result.ContainsKey(tuple.Item1))
                    result[tuple.Item1].Add(new Tuple<string, double>(tuple.Item2, tuple.Item3));
                else
                    result.Add(tuple.Item1, new List<Tuple<string, double>> { new Tuple<string, double>(tuple.Item2, tuple.Item3) });
                if (result.ContainsKey(tuple.Item2))
                    result[tuple.Item2].Add(new Tuple<string, double>(tuple.Item1, tuple.Item3));
                else
                    result.Add(tuple.Item2, new List<Tuple<string, double>> { new Tuple<string, double>(tuple.Item1, tuple.Item3) });
            }
            result.ToList().ForEach(x => x.Value.Sort((a, b) => b.Item2.CompareTo(a.Item2)));
            results.Clear();
        }

        int max;
        int progress;
        int mtl;
        public void Start()
        {
            Initialize();

            max = tags_list.Count;
            progress = 0;
            mtl = Environment.ProcessorCount;

            Console.Write("Process... ");
            using (var pb = new ExtractingProgressBar())
            {
                Task.WhenAll(Enumerable.Range(0, mtl).Select(no => Task.Run(() => process(no, pb)))).Wait();
            }
            Console.WriteLine("Complete");

            Console.Write("Merge... ");
            Merge();
            Console.WriteLine("Complete");

            Console.Write("Save... ");
            var rr = result.ToList();
            rr.Sort((x, y) => y.Value.Count.CompareTo(x.Value.Count));
            JArray arr = new JArray();
            rr.ForEach(x =>
            {
                JArray tags = new JArray();
                x.Value.ForEach(y =>
                {
                    tags.Add(new JObject{ { y.Item1, y.Item2 } });
                });
                arr.Add(new JObject { { x.Key, tags } });
            });
            File.WriteAllText(Path.Combine(dbdir, "rtt-result.json"), JsonConvert.SerializeObject(arr));
            Console.WriteLine("Complete");
        }

        private void process(int i, ExtractingProgressBar pb)
        {
            int min = this.max / mtl * i;
            int max = this.max / mtl * (i + 1);
            if (max > this.max)
                max = this.max;

            List<Tuple<string, string, double>> result = new List<Tuple<string, string, double>>();

            for (int j = max - 1; j >= min; j--)
            {
                result.AddRange(Intersect(j));

                pb.Report(this.max, Interlocked.Increment(ref progress));
            }

            lock(results)
                results.AddRange(result);
        }
    }
}
