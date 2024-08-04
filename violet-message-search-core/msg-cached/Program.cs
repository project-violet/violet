using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Web;

namespace msg_cached
{
    class Program
    {
        public static string CreateMD5(string input)
        {
            // byte array representation of that string
            byte[] encodedPassword = new UTF8Encoding().GetBytes(input);

            // need MD5 to calculate the hash
            byte[] hash = ((HashAlgorithm)CryptoConfig.CreateFromName("MD5")).ComputeHash(encodedPassword);

            // string representation (similar to UNIX format)
            string encoded = BitConverter.ToString(hash)
               // without dashes
               .Replace("-", string.Empty)
               // make lowercase
               .ToLower();

            return encoded;
        }

        static void Main(string[] args)
        {
            using (StreamReader r = new StreamReader(@"F:\Dev2\violet-message-search\fast-search\build\Release\SORT-COMBINE.json"))
            {
                var json = r.ReadToEnd();
                var items = JsonConvert.DeserializeObject<Dictionary<string, int>>(json);
                var c = 0;

                using (WebClient wc = new WebClient())
                {
                    var ii = items.ToList();
                    ii.Sort((x, y) => y.Key.Length.CompareTo(x.Key.Length));
                    foreach (var kv in ii)
                    {
                        Console.WriteLine($"[{++c}/{items.Count}] // {kv.Key}: {kv.Value}");

                        var s = wc.DownloadString($"http://localhost:8894/s/contains/{HttpUtility.UrlEncode(kv.Key)}");
                        //Console.WriteLine(s);

                        File.WriteAllText($"result/{CreateMD5(kv.Key)}.json", s);
                    }
                }
            }
        }
    }
}
