﻿// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;

namespace hsync.Network
{
    /// <summary>
    /// Implementaion of real download procedure
    /// </summary>
    public class NetField
    {
        public static void Do(NetTask content)
        {
            var retry_count = 0;

        RETRY_PROCEDURE:

            if (content.Cancel != null && content.Cancel.IsCancellationRequested)
            {
                content.CancleCallback();
                return;
            }

            NetTaskPass.RunOnField(ref content);

            //if (content.DownloadString)
            //    Log.Logs.Instance.Push("[NetField] Start download string... " + content.Url);
            //else if (content.MemoryCache)
            //    Log.Logs.Instance.Push("[NetField] Start download to memory... " + content.Url);
            //else if (content.SaveFile)
            //    Log.Logs.Instance.Push("[NetField] Start download file... " + content.Url + " to " + content.Filename);

        REDIRECTION:

            if (content.Cancel != null && content.Cancel.IsCancellationRequested)
            {
                content.CancleCallback();
                return;
            }

            content.StartCallback?.Invoke();

            try
            {
                //
                //  Initialize http-web-request
                //

                var request = (HttpWebRequest)WebRequest.Create(content.Url);
                content.Request = request;

                request.Accept = content.Accept;
                request.UserAgent = content.UserAgent;

                if (content.Referer != null)
                    request.Referer = content.Referer;
                else
                    request.Referer = (content.Url.StartsWith("https://") ? "https://" : (content.Url.Split(':')[0] + "//")) + request.RequestUri.Host;

                if (content.Cookie != null)
                    request.Headers.Add(HttpRequestHeader.Cookie, content.Cookie);

                if (content.Headers != null)
                    content.Headers.ToList().ForEach(p => request.Headers.Add(p.Key, p.Value));

                if (content.Proxy != null)
                    request.Proxy = content.Proxy;

                if (content.TimeoutInfinite)
                    request.Timeout = Timeout.Infinite;
                else
                    request.Timeout = content.TimeoutMillisecond;

                request.AllowAutoRedirect = content.AutoRedirection;

                //
                //  POST Data
                //

                if (content.Query != null)
                {
                    request.Method = "POST";
                    request.ContentType = "application/x-www-form-urlencoded";

                    var request_stream = new StreamWriter(request.GetRequestStream());
                    var query = string.Join("&", content.Query.ToList().Select(x => $"{x.Key}={x.Value}"));
                    request_stream.Write(query);
                    request_stream.Close();

                    if (content.Cancel != null && content.Cancel.IsCancellationRequested)
                    {
                        content.CancleCallback();
                        return;
                    }
                }

                //
                //  Wait request
                //

                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                {
                    if (response.StatusCode == HttpStatusCode.NotFound ||
                        response.StatusCode == HttpStatusCode.Forbidden ||
                        response.StatusCode == HttpStatusCode.Unauthorized ||
                        response.StatusCode == HttpStatusCode.BadRequest ||
                        response.StatusCode == HttpStatusCode.InternalServerError)
                    {
                        //
                        //  Cannot continue
                        //

                        content.ErrorCallback?.Invoke(NetTask.NetError.CannotContinueByCriticalError);
                        return;
                    }
                    else if (response.StatusCode == HttpStatusCode.Moved ||
                             response.StatusCode == HttpStatusCode.Redirect)
                    {
                        if (content.AutoRedirection)
                        {
                            var old = content.Url;
                            content.Url = response.Headers.Get("Location");
                            Log.Logs.Instance.Push("[NetField] Redirection " + old + " to " + content.Url);
                            goto REDIRECTION;
                        }
                    }
                    else if (response.StatusCode == HttpStatusCode.OK)
                    {
                        if (content.Cancel != null && content.Cancel.IsCancellationRequested)
                        {
                            content.CancleCallback();
                            return;
                        }

                        content.HeaderReceive?.Invoke(response.Headers.ToString());
                        content.CookieReceive?.Invoke(response.Cookies);

                        Stream istream = response.GetResponseStream();
                        Stream ostream = null;

                        if (content.DownloadString || content.MemoryCache)
                        {
                            ostream = new MemoryStream();
                        }
                        else if (content.DriveCache)
                        {
                            // TODO:
                        }
                        else
                        {
                            ostream = File.OpenWrite(content.Filename);
                        }

                        content.SizeCallback?.Invoke(response.ContentLength);

                        if (content.NotifyOnlySize)
                        {
                            ostream.Close();
                            istream.Close();
                            return;
                        }

                        if (content.Cancel != null && content.Cancel.IsCancellationRequested)
                        {
                            content.CancleCallback();
                            return;
                        }

                        byte[] buffer = new byte[content.DownloadBufferSize];
                        long byte_read = 0;

                        //
                        //  Download loop
                        //

                        do
                        {
                            if (content.Cancel != null && content.Cancel.IsCancellationRequested)
                            {
                                content.CancleCallback();
                                return;
                            }

                            byte_read = istream.Read(buffer, 0, buffer.Length);
                            ostream.Write(buffer, 0, (int)byte_read);

                            if (content.Cancel != null && content.Cancel.IsCancellationRequested)
                            {
                                content.CancleCallback();
                                return;
                            }

                            content.DownloadCallback?.Invoke(byte_read);

                        } while (byte_read != 0);

                        //
                        //  Notify Complete
                        //

                        if (content.DownloadString)
                        {
                            if (content.Encoding == null)
                                content.CompleteCallbackString(Encoding.UTF8.GetString(((MemoryStream)ostream).ToArray()));
                            else
                                content.CompleteCallbackString(content.Encoding.GetString(((MemoryStream)ostream).ToArray()));
                        }
                        else if (content.MemoryCache)
                        {
                            content.CompleteCallbackBytes(((MemoryStream)ostream).ToArray());
                        }
                        else
                        {
                            content.CompleteCallback?.Invoke();
                        }

                        ostream.Close();
                        istream.Close();

                        return;
                    }
                }
            }
            catch (WebException e)
            {
                var response = (HttpWebResponse)e.Response;

                if (response != null && response.StatusCode == HttpStatusCode.Moved)
                {
                    if (content.AutoRedirection)
                    {
                        var old = content.Url;
                        content.Url = response.Headers.Get("Location");
                        Log.Logs.Instance.Push("[NetField] Redirection " + old + " to " + content.Url);
                        goto REDIRECTION;
                    }
                }

                //lock (Log.Logs.Instance)
                //{
                //    Log.Logs.Instance.PushError("[NetField] Web Excpetion - " + e.Message + "\r\n" + e.StackTrace);
                //    Log.Logs.Instance.PushError(content);
                //}

                if (content.FailUrls != null && retry_count < content.FailUrls.Count)
                {
                    content.Url = content.FailUrls[retry_count++];
                    content.RetryCallback?.Invoke(retry_count);

                    lock (Log.Logs.Instance)
                    {
                        Log.Logs.Instance.Push($"[NetField] Retry [{retry_count}/{content.RetryCount}]");
                        Log.Logs.Instance.Push(content);
                    }
                    goto RETRY_PROCEDURE;
                }

                if ((response != null && (
                    response.StatusCode == HttpStatusCode.NotFound ||
                    response.StatusCode == HttpStatusCode.Forbidden ||
                    response.StatusCode == HttpStatusCode.Unauthorized ||
                    response.StatusCode == HttpStatusCode.BadRequest ||
                    response.StatusCode == HttpStatusCode.InternalServerError)) ||
                    e.Status == WebExceptionStatus.NameResolutionFailure ||
                    e.Status == WebExceptionStatus.UnknownError)
                {
                    if (response != null && response.StatusCode == HttpStatusCode.Forbidden && response.Cookies != null)
                    {
                        content.CookieReceive?.Invoke(response.Cookies);
                        return;
                    }

                    //
                    //  Cannot continue
                    //

                    if (e.Status == WebExceptionStatus.UnknownError)
                    {
                        lock (Log.Logs.Instance)
                        {
                            Log.Logs.Instance.PushError("[NetField] Check your Firewall, Router or DPI settings.");
                            Log.Logs.Instance.PushError("[NetField] If you continue to receive this error, please contact developer.");
                        }

                        content.ErrorCallback?.Invoke(NetTask.NetError.UnknowError);
                    }
                    else
                    {
                        content.ErrorCallback?.Invoke(NetTask.NetError.CannotContinueByCriticalError);
                    }

                    return;
                }
            }
            catch (UriFormatException e)
            {
                lock (Log.Logs.Instance)
                {
                    Log.Logs.Instance.PushError("[NetField] URI Exception - " + e.Message + "\r\n" + e.StackTrace);
                    Log.Logs.Instance.PushError(content);
                }

                //
                //  Cannot continue
                //

                content.ErrorCallback?.Invoke(NetTask.NetError.UriFormatError);
                return;
            }
            catch (Exception e)
            {
                lock (Log.Logs.Instance)
                {
                    Log.Logs.Instance.PushError("[NetField] Unhandled Excpetion - " + e.Message + "\r\n" + e.StackTrace);
                    Log.Logs.Instance.PushError(content);
                }
            }

            //
            //  Request Aborted
            //

            if (content.Aborted)
            {
                content.ErrorCallback?.Invoke(NetTask.NetError.Aborted);
                return;
            }

            //
            //  Retry
            //

            //if (content.FailUrls != null && retry_count < content.FailUrls.Count)
            //{
            //    content.Url = content.FailUrls[retry_count++];
            //    content.RetryCallback?.Invoke(retry_count);

            //    lock (Log.Logs.Instance)
            //    {
            //        Log.Logs.Instance.Push($"[NetField] Retry [{retry_count}/{content.RetryCount}]");
            //        Log.Logs.Instance.Push(content);
            //    }
            //    goto RETRY_PROCEDURE;
            //}

            //if (content.RetryWhenFail)
            //{
            //    if (content.RetryCount > retry_count)
            //    {
            //        retry_count += 1;

            //        content.RetryCallback?.Invoke(retry_count);

            //        lock (Log.Logs.Instance)
            //        {
            //            Log.Logs.Instance.Push($"[NetField] Retry [{retry_count}/{content.RetryCount}]");
            //            Log.Logs.Instance.Push(content);
            //        }
            //        goto RETRY_PROCEDURE;
            //    }

            //    //
            //    //  Many retry
            //    //

            //    lock (Log.Logs.Instance)
            //    {
            //        Log.Logs.Instance.Push($"[NetField] Many Retry");
            //        Log.Logs.Instance.Push(content);
            //    }
            //    content.ErrorCallback?.Invoke(NetTask.NetError.ManyRetry);
            //}

            content.ErrorCallback?.Invoke(NetTask.NetError.Unhandled);
        }
    }
}
