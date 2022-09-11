// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using HtmlAgilityPack;
using Newtonsoft.Json;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace hsync.Utils
{
    public static class Extends
    {
        public static int ToInt(this string str) => Convert.ToInt32(str);

        public static string MyText(this HtmlNode node) =>
            string.Join("", node.ChildNodes.Where(x => x.Name == "#text").Select(x => x.InnerText.Trim()));

        public static HtmlNode ToHtmlNode(this string html)
        {
            var document = new HtmlDocument();
            document.LoadHtml(html);
            return document.DocumentNode;
        }

        public static Task ForEachAsync<T>(this IEnumerable<T> source, int countdvd, Func<T, Task> body)
        {
            return Task.WhenAll(
                from partition in Partitioner.Create(source).GetPartitions(countdvd)
                select Task.Run(async delegate
                {
                    using (partition)
                    while (partition.MoveNext())
                        await body(partition.Current);
                }));
        }

        public static async Task<T> ReadJson<T>(string path)
        {
            using (var fs = new StreamReader(new FileStream(path, FileMode.Open, FileAccess.Read)))
            {
                return JsonConvert.DeserializeObject<T>(await fs.ReadToEndAsync());
            }
        }

        public static async void WriteJson<T>(string path, T value)
        {
            var json = JsonConvert.SerializeObject(value, Formatting.Indented);
            using (var fs = new StreamWriter(new FileStream(path, FileMode.Create, FileAccess.Write)))
            {
                await fs.WriteAsync(json);
            }
        }
    }
}
