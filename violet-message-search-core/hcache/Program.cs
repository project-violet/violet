using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace hmerger
{
    class Program
    {
        public class MessageInfo
        {
            public int ArticleId { get; set; }
            public int Page { get; set; }
            public string Message { get; set; }
            public double Score { get; set; }
            public List<double> Rectangle { get; set; }
            public string MessageRaw { get; set; }
        }


        static List<int> makePageInvTable(int page_count)
        {
            var r = new List<String>();
            for (int i = 1; i <= page_count; i++)
                r.Add($"{i}");
            r.Sort();

            var x = Enumerable.Range(0, page_count).ToList();
            for (int i = 0; i < page_count; i++)
            {
                x[i] = Convert.ToInt32(r[i]);
            }

            return x;
        }

        static void Main(string[] args)
        {
            const string srcPath = @"G:\Dev2\htext-miner-english\result";
            const string destPath = @"G:\Dev2\htext-miner-english-cache";

            var len = Directory.GetFiles(srcPath).Length;
            var proc = 0;

            Parallel.ForEach(Directory.GetFiles(srcPath), file =>
            {
                Console.WriteLine($"{Interlocked.Increment(ref proc)}/{len}");
                var cacheFileName = @$"{destPath}\{file.Split('\\').Last()}.cache";
                if (File.Exists(cacheFileName))
                {
                    return;
                }

                var x = Merge(file);
                var id = Convert.ToInt32(file.Split('\\').Last().Split('.')[0]);

                var page = 0;
                var itable = makePageInvTable(x.Count);

                var mergedMessages = new List<MessageInfo>();
                foreach (var i in x)
                {
                    foreach (var c in i["content"])
                    {
                        var raw = c[0].Value<string>();
                        if (raw.Length <= 1) continue;
                        //var pp = Hangul.Disasm(raw);
                        var pp = raw.ToLower();
                        if (pp == "") continue;

                        mergedMessages.Add(new MessageInfo
                        {
                            ArticleId = id,
                            Page = itable[page] - 1,
                            //Page = page,
                            Message = pp,
                            Score = c[1].Value<double>(),
                            Rectangle = c[2].ToObject<List<double>>(),
                            MessageRaw = raw,
                        });
                    }
                    page++;
                }

                File.WriteAllText(cacheFileName, JsonConvert.SerializeObject(mergedMessages));
            });

        }

        static List<JArray> Parse(string page)
        {
            var ptr = 1;
            var plen = page.Length;

            var results = new List<JArray>();

            while (true)
            {
                if (ptr == plen)
                    break;

                if (page[ptr] == ']')
                    break;
                while (page[ptr] == ' ')
                    ptr += 1;

                var item = "";

                while (true)
                {
                    if (page[ptr] == ')') { ptr += 1; break; }
                    if (page[ptr] == '(') ptr += 1;

                    if (page[ptr] == '\'')
                    {
                        item += '"';
                        ptr += 1;

                        while (true)
                        {
                            if (page[ptr] == '\'')
                            {
                                item += '"';
                                ptr += 1;
                                break;
                            }

                            if (page[ptr] == '"')
                            {
                                item += '\\' + page[ptr];
                                ptr += 1;
                                continue;
                            }

                            if (page[ptr] == '\\')
                            {
                                ptr += 1;
                                item += page[ptr];
                            }

                            item += page[ptr];
                            ptr += 1;
                        }
                    }
                    else if (page[ptr] == '"')
                    {
                        item += '"';
                        ptr += 1;

                        while (true)
                        {
                            if (page[ptr] == '"')
                            {
                                item += '"';
                                ptr += 1;
                                break;
                            }
                            if (page[ptr] == '\\')
                            {
                                item += page[ptr];
                                ptr += 1;
                            }
                            item += page[ptr];
                            ptr += 1;
                        }
                    }
                    else
                    {
                        item += page[ptr];
                        ptr += 1;
                    }
                }

                results.Add(JArray.Parse('[' + item + ']'));

                while (page[ptr] == ' ')
                    ptr += 1;
                if (page[ptr] == ',')
                    ptr += 1;
                while (page[ptr] == ' ')
                    ptr += 1;

                ptr += 1;
            }

            return results;
        }

        const double drop_threshold = 0.1;
        const double drop_min_distx = 30.0;
        const double drop_min_disty = 80.0;

        static List<JArray> MergeByDist(List<JArray> page)
        {
            var group = Enumerable.Range(0, page.Count).ToList();

            for (var i = 1; i < page.Count; i++)
            {
                var min_distx = 99999.0;
                var min_disty = 99999.0;
                var min_index = i;

                for (var j = 0; j < i; j++)
                {
                    var l11 = page[i][0][0][0].Value<double>();
                    var l12 = page[i][0][0][1].Value<double>();
                    var l21 = page[i][0][1][0].Value<double>();
                    var l22 = page[i][0][1][1].Value<double>();
                    var l31 = page[i][0][2][0].Value<double>();
                    var l32 = page[i][0][2][1].Value<double>();
                    var l41 = page[i][0][3][0].Value<double>();
                    var l42 = page[i][0][3][1].Value<double>();

                    var r11 = page[j][0][0][0].Value<double>();
                    var r12 = page[j][0][0][1].Value<double>();
                    var r21 = page[j][0][1][0].Value<double>();
                    var r22 = page[j][0][1][1].Value<double>();
                    var r31 = page[j][0][2][0].Value<double>();
                    var r32 = page[j][0][2][1].Value<double>();
                    var r41 = page[j][0][3][0].Value<double>();
                    var r42 = page[j][0][3][1].Value<double>();

                    var mlx = (l11 + l21 + l31 + l41) / 4;
                    var mly = (l12 + l22 + l32 + l42) / 4;
                    var mrx = (r11 + r21 + r31 + r41) / 4;
                    var mry = (r12 + r22 + r32 + r42) / 4;

                    var distx = Math.Abs(mlx - mrx);
                    var disty = Math.Abs(mly - mry);

                    if (distx < drop_min_distx && disty < drop_min_disty)
                        if (distx < min_distx && disty < min_disty)
                        {
                            min_distx = distx;
                            min_disty = disty;
                            min_index = j;
                        }
                }

                group[i] = group[min_index];
            }

            var grouping = Enumerable.Repeat("", page.Count).ToList();
            var groupingc = Enumerable.Repeat(0, page.Count).ToList();
            var groupingw = Enumerable.Repeat(0.0, page.Count).ToList();
            var groupingRect = Enumerable.Repeat(new List<double>(), page.Count).ToList();

            for (var i = 0; i < page.Count; i++) {
                groupingRect[i] = Enumerable.Repeat(0.0, 4).ToList();
            }

            for (var i = 0; i < page.Count; i++)
            {
                if (page[i][2].Value<double>() > drop_threshold)
                {
                    grouping[group[i]] += ' ' + page[i][1].Value<string>();
                    groupingc[group[i]] += 1;
                    groupingw[group[i]] += page[i][2].Value<double>();

                    var x11 = page[i][0][0][0].Value<double>();
                    var x12 = page[i][0][0][1].Value<double>();
                    var x21 = page[i][0][1][0].Value<double>();
                    var x22 = page[i][0][1][1].Value<double>();
                    var x31 = page[i][0][2][0].Value<double>();
                    var x32 = page[i][0][2][1].Value<double>();
                    var x41 = page[i][0][3][0].Value<double>();
                    var x42 = page[i][0][3][1].Value<double>();

                    /*
                     (0,1)
                    x11,x12  ----------- x21,x22
                       |                    |
                       |                    |
                       |                    |
                       |                    |
                    x41,x42  ----------- x31,x32
                                          (2,3)
                    */

                    if (i == group[i])
                    {
                        groupingRect[i][0] = Math.Min(Math.Min(x11, x41), Math.Min(x21, x31));
                        groupingRect[i][1] = Math.Min(Math.Min(x12, x42), Math.Min(x22, x32));
                        groupingRect[i][2] = Math.Max(Math.Max(x11, x41), Math.Max(x21, x31));
                        groupingRect[i][3] = Math.Max(Math.Max(x12, x42), Math.Max(x22, x32));
                    }
                    else
                    {
                        groupingRect[group[i]][0] = Math.Min(groupingRect[group[i]][0], Math.Min(Math.Min(x11, x41), Math.Min(x21, x31)));
                        groupingRect[group[i]][1] = Math.Min(groupingRect[group[i]][1], Math.Min(Math.Min(x12, x42), Math.Min(x22, x32)));
                        groupingRect[group[i]][2] = Math.Max(groupingRect[group[i]][2], Math.Max(Math.Max(x11, x41), Math.Max(x21, x31)));
                        groupingRect[group[i]][3] = Math.Max(groupingRect[group[i]][3], Math.Max(Math.Max(x12, x42), Math.Max(x22, x32)));
                    }
                }
            }

            var result = new List<JArray>();

            for (var i = 0; i < page.Count; i++)
            {
                if (grouping[i].Trim() != "")
                {
                    var arr = new JArray();
                    arr.Add(grouping[group[i]].Trim());
                    arr.Add(groupingw[group[i]] / groupingc[group[i]]);
                    arr.Add(JArray.FromObject(groupingRect[group[i]]));
                    result.Add(arr);
                }
            }

            return result;
        }

        static List<JObject> Merge(string filename)
        {
            var data = File.ReadAllLines(filename);

            var dlen = Convert.ToInt32(data[1].Trim());

            var pages = new List<JObject>();
            for (var i = 0; i < dlen; i++)
            {
                var page = data[i + 2].Trim();
                var items = Parse(page);

                var groupInfo = MergeByDist(items);
                JObject obj = new JObject();
                obj.Add("page", i);
                obj.Add("content", JArray.FromObject(groupInfo));
                pages.Add(obj);
            }

            return pages;
        }
    }
}
