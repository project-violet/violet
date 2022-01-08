// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace hsync.Network
{
    public class NetTools
    {
        public static async Task<List<string>> DownloadStrings(List<string> urls, string cookie = "", Action complete = null, Action error = null)
        {
            var interrupt = new ManualResetEvent(false);
            var result = new string[urls.Count];
            var count = urls.Count;
            int iter = 0;

            foreach (var url in urls)
            {
                var itertmp = iter;
                var task = NetTask.MakeDefault(url);
                task.DownloadString = true;
                var headers = new Dictionary<string, string>();
                // headers["accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8";
                // headers["user-agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.3";
                // headers["referer"] = "https://hitomi.la/reader/1234.html";
                task.Headers = headers;
                task.CompleteCallbackString = (str) =>
                {
                    result[itertmp] = str;
                    if (Interlocked.Decrement(ref count) == 0)
                        interrupt.Set();
                    complete?.Invoke();
                };
                task.ErrorCallback = (code) =>
                {
                    if (Interlocked.Decrement(ref count) == 0)
                        interrupt.Set();
                    error?.Invoke();
                };
                task.Cookie = cookie;
                await AppProvider.DownloadQueue.Add(task).ConfigureAwait(false);
                iter++;
            }

            interrupt.WaitOne();

            return result.ToList();
        }

        public static async Task<List<string>> DownloadStrings(List<NetTask> tasks, string cookie = "", Action complete = null)
        {
            var interrupt = new ManualResetEvent(false);
            var result = new string[tasks.Count];
            var count = tasks.Count;
            int iter = 0;

            foreach (var task in tasks)
            {
                var itertmp = iter;
                task.DownloadString = true;
                task.CompleteCallbackString = (str) =>
                {
                    result[itertmp] = str;
                    if (Interlocked.Decrement(ref count) == 0)
                        interrupt.Set();
                    complete?.Invoke();
                };
                task.ErrorCallback = (code) =>
                {
                    if (Interlocked.Decrement(ref count) == 0)
                        interrupt.Set();
                };
                task.Cookie = cookie;
                await AppProvider.DownloadQueue.Add(task).ConfigureAwait(false);
                iter++;
            }

            interrupt.WaitOne();

            return result.ToList();
        }

        public static string DownloadString(string url)
        {
            return DownloadStringAsync(NetTask.MakeDefault(url)).Result;
        }

        public static string DownloadString(NetTask task)
        {
            return DownloadStringAsync(task).Result;
        }

        public static async Task<string> DownloadStringAsync(NetTask task)
        {
            return await Task.Run(async () =>
            {
                var interrupt = new ManualResetEvent(false);
                string result = null;

                task.DownloadString = true;
                task.CompleteCallbackString = (string str) =>
                {
                    result = str;
                    interrupt.Set();
                };

                task.ErrorCallback = (code) =>
                {
                    task.ErrorCallback = null;
                    interrupt.Set();
                };

                await AppProvider.DownloadQueue.Add(task).ConfigureAwait(false);

                interrupt.WaitOne();

                return result;
            }).ConfigureAwait(false);
        }

        public static async Task<List<string>> DownloadFiles(List<(string, string)> url_path, string cookie = "", Action<long> download = null, Action complete = null)
        {
            var interrupt = new ManualResetEvent(false);
            var result = new string[url_path.Count];
            var count = url_path.Count;
            int iter = 0;

            foreach (var up in url_path)
            {
                var itertmp = iter;
                var task = NetTask.MakeDefault(up.Item1);
                task.SaveFile = true;
                task.Filename = up.Item2;
                task.DownloadCallback = (sz) =>
                {
                    download?.Invoke(sz);
                };
                task.CompleteCallback = () =>
                {
                    if (Interlocked.Decrement(ref count) == 0)
                        interrupt.Set();
                    complete?.Invoke();
                };
                task.ErrorCallback = (code) =>
                {
                    if (Interlocked.Decrement(ref count) == 0)
                        interrupt.Set();
                };
                task.Cookie = cookie;
                await AppProvider.DownloadQueue.Add(task).ConfigureAwait(false);
                iter++;
            }

            interrupt.WaitOne();

            return result.ToList();
        }

        public static void DownloadFile(string url, string filename)
        {
            var task = NetTask.MakeDefault(url);
            task.SaveFile = true;
            task.Filename = filename;
            DownloadFileAsync(task).Wait();
        }

        public static void DownloadFile(NetTask task)
        {
            DownloadFileAsync(task).Wait();
        }

        public static async Task DownloadFileAsync(NetTask task)
        {
            await Task.Run(async () =>
            {
                var interrupt = new ManualResetEvent(false);

                task.SaveFile = true;
                task.CompleteCallback = () =>
                {
                    interrupt.Set();
                };

                task.ErrorCallback = (code) =>
                {
                    task.ErrorCallback = null;
                    interrupt.Set();
                };

                await AppProvider.DownloadQueue.Add(task).ConfigureAwait(false);

                interrupt.WaitOne();
            }).ConfigureAwait(false);
        }

        public static byte[] DownloadData(string url)
        {
            return DownloadDataAsync(NetTask.MakeDefault(url)).Result;
        }

        public static byte[] DownloadData(NetTask task)
        {
            return DownloadDataAsync(task).Result;
        }

        public static async Task<byte[]> DownloadDataAsync(NetTask task)
        {
            return await Task.Run(async () =>
            {
                var interrupt = new ManualResetEvent(false);
                byte[] result = null;

                task.MemoryCache = true;
                task.CompleteCallbackBytes = (byte[] bytes) =>
                {
                    result = bytes;
                    interrupt.Set();
                };

                task.ErrorCallback = (code) =>
                {
                    task.ErrorCallback = null;
                    interrupt.Set();
                };

                await AppProvider.DownloadQueue.Add(task).ConfigureAwait(false);

                interrupt.WaitOne();

                return result;
            }).ConfigureAwait(false);
        }
    }
}
