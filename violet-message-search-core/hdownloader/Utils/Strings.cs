﻿// This source code is a part of project violet-server.
// Copyright (C)2020-2021. violet-team. Licensed under the MIT Licence.

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

namespace hsync.Utils
{
    public static class Strings
    {
        // https://stackoverflow.com/questions/11743160/how-do-i-encode-and-decode-a-base64-string
        public static string ToBase64(this string text)
        {
            return ToBase64(text, Encoding.UTF8);
        }

        public static string ToBase64(this string text, Encoding encoding)
        {
            if (string.IsNullOrEmpty(text))
            {
                return text;
            }

            byte[] textAsBytes = encoding.GetBytes(text);
            return Convert.ToBase64String(textAsBytes);
        }

        public static bool TryParseBase64(this string text, out string decodedText)
        {
            return TryParseBase64(text, Encoding.UTF8, out decodedText);
        }

        public static bool TryParseBase64(this string text, Encoding encoding, out string decodedText)
        {
            if (string.IsNullOrEmpty(text))
            {
                decodedText = text;
                return false;
            }

            try
            {
                byte[] textAsBytes = Convert.FromBase64String(text);
                decodedText = encoding.GetString(textAsBytes);
                return true;
            }
            catch (Exception)
            {
                decodedText = null;
                return false;
            }
        }

        #region Compression

        // https://stackoverflow.com/questions/7343465/compression-decompression-string-with-c-sharp
        private static void CopyTo(Stream src, Stream dest)
        {
            byte[] bytes = new byte[4096];

            int cnt;

            while ((cnt = src.Read(bytes, 0, bytes.Length)) != 0)
            {
                dest.Write(bytes, 0, cnt);
            }
        }

        public static byte[] Zip(this string str)
        {
            var bytes = Encoding.UTF8.GetBytes(str);

            using (var msi = new MemoryStream(bytes))
            using (var mso = new MemoryStream())
            {
                using (var gs = new GZipStream(mso, CompressionMode.Compress))
                {
                    CopyTo(msi, gs);
                }

                return mso.ToArray();
            }
        }

        public static byte[] ZipByte(this byte[] bytes)
        {
            using (var msi = new MemoryStream(bytes))
            using (var mso = new MemoryStream())
            {
                using (var gs = new GZipStream(mso, CompressionMode.Compress))
                {
                    CopyTo(msi, gs);
                }

                return mso.ToArray();
            }
        }


        public static string Unzip(this byte[] bytes)
        {
            using (var msi = new MemoryStream(bytes))
            using (var mso = new MemoryStream())
            {
                using (var gs = new GZipStream(msi, CompressionMode.Decompress))
                {
                    CopyTo(gs, mso);
                }

                return Encoding.UTF8.GetString(mso.ToArray());
            }
        }

        public static byte[] UnzipByte(this byte[] bytes)
        {
            using (var msi = new MemoryStream(bytes))
            using (var mso = new MemoryStream())
            {
                using (var gs = new GZipStream(msi, CompressionMode.Decompress))
                {
                    CopyTo(gs, mso);
                }

                return mso.ToArray();
            }
        }

        #endregion

        public static int ComputeLevenshteinDistance(this string a, string b)
        {
            int x = a.Length;
            int y = b.Length;
            int i, j;

            if (x == 0) return x;
            if (y == 0) return y;
            int[] v0 = new int[(y + 1) << 1];

            for (i = 0; i < y + 1; i++) v0[i] = i;
            for (i = 0; i < x; i++)
            {
                v0[y + 1] = i + 1;
                for (j = 0; j < y; j++)
                    v0[y + j + 2] = Math.Min(Math.Min(v0[y + j + 1], v0[j + 1]) + 1, v0[j] + ((a[i] == b[j]) ? 0 : 1));
                for (j = 0; j < y + 1; j++) v0[j] = v0[y + j + 1];
            }
            return v0[y + y + 1];
        }

        public static int[] GetLevenshteinDistance(this string src, string tar)
        {
            int[,] dist = new int[src.Length + 1, tar.Length + 1];
            for (int i = 1; i <= src.Length; i++) dist[i, 0] = i;
            for (int j = 1; j <= tar.Length; j++) dist[0, j] = j;

            for (int j = 1; j <= tar.Length; j++)
            {
                for (int i = 1; i <= src.Length; i++)
                {
                    if (src[i - 1] == tar[j - 1]) dist[i, j] = dist[i - 1, j - 1];
                    else dist[i, j] = Math.Min(dist[i - 1, j - 1] + 1, Math.Min(dist[i, j - 1] + 1, dist[i - 1, j] + 1));
                }
            }

            // Get diff through backtracking.
            int[] route = new int[src.Length + 1];
            int fz = dist[src.Length, tar.Length];
            for (int i = src.Length, j = tar.Length; i >= 0 && j >= 0;)
            {
                int lu = int.MaxValue;
                int u = int.MaxValue;
                int l = int.MaxValue;
                if (i - 1 >= 0 && j - 1 >= 0) lu = dist[i - 1, j - 1];
                if (i - 1 >= 0) u = dist[i - 1, j];
                if (j - 1 >= 0) l = dist[i, j - 1];
                int min = Math.Min(lu, Math.Min(l, u));
                if (min == fz) route[i] = 1;
                if (min == lu)
                {
                    i--; j--;
                }
                else if (min == u) i--;
                else j--;
                fz = min;
            }
            return route;
        }


        // https://stackoverflow.com/questions/1601834/c-implementation-of-or-alternative-to-strcmplogicalw-in-shlwapi-dll
        public class NaturalComparer : IComparer<string>
        {
            public int Compare(string x, string y)
            {
                if (x == null && y == null) return 0;
                if (x == null) return -1;
                if (y == null) return 1;

                int lx = x.Length, ly = y.Length;

                for (int mx = 0, my = 0; mx < lx && my < ly; mx++, my++)
                {
                    if (char.IsDigit(x[mx]) && char.IsDigit(y[my]))
                    {
                        long vx = 0, vy = 0;

                        for (; mx < lx && char.IsDigit(x[mx]); mx++)
                            vx = vx * 10 + x[mx] - '0';

                        for (; my < ly && char.IsDigit(y[my]); my++)
                            vy = vy * 10 + y[my] - '0';

                        if (vx != vy)
                            return vx > vy ? 1 : -1;
                    }

                    if (mx < lx && my < ly && x[mx] != y[my])
                        return x[mx] > y[my] ? 1 : -1;
                }

                return lx - ly;
            }
        }
    }
}
