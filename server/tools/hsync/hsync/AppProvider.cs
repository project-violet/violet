// This source code is a part of project violet-server.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

using hsync.Log;
using hsync.Network;
using hsync.Setting;
using hsync.Utils;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Runtime;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading;

namespace hsync
{
    public class AppProvider
    {
        public static string ApplicationPath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        public static string DefaultSuperPath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);

        public static Dictionary<string, object> Instance =>
            InstanceMonitor.Instances;

        public static NetScheduler Scheduler { get; set; }

        public static DateTime StartTime = DateTime.Now;

        public static void Initialize()
        {
            // Initialize logs instance
            GCLatencyMode oldMode = GCSettings.LatencyMode;
            RuntimeHelpers.PrepareConstrainedRegions();
            GCSettings.LatencyMode = GCLatencyMode.Batch;

            ServicePointManager.DefaultConnectionLimit = int.MaxValue;

            Scheduler = new NetScheduler(Settings.Instance.Model.ThreadCount);

            GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced);
        }

        public static void Deinitialize()
        {
        }
    }
}
