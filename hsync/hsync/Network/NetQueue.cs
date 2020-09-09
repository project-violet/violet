﻿// This source code is a part of project violet-server.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

using hsync.Utils;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace hsync.Network
{
    /// <summary>
    /// Download Queue Implementation
    /// </summary>
    public class NetQueue
    {
        public Queue<NetTask> queue = new Queue<NetTask>();

        SemaphoreSlim semaphore;
        int capacity = 0;

        public NetQueue(int capacity = 0)
        {
            this.capacity = capacity;

            if (this.capacity == 0)
                this.capacity = Environment.ProcessorCount;

            ThreadPool.SetMinThreads(816, 816);
            semaphore = new SemaphoreSlim(816, 816);
        }

        public Task Add(NetTask task)
        {
            return Task.Run(async () =>
            {
                await semaphore.WaitAsync().ConfigureAwait(false);
                _ = Task.Run(() =>
                {
                    NetField.Do(task);
                    semaphore.Release();
                }).ConfigureAwait(false);
            });
        }

    }
}
