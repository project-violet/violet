// This source code is a part of project violet-server.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

using System;
using System.Collections.Generic;
using System.Text;

namespace hsync
{
    public class Version
    {
        public const int MajorVersion = 2020;
        public const int MinorVersion = 09;
        public const int BuildVersion = 02;

        public const string Name = "hsync";
        public static string Text { get; } = $"{MajorVersion}.{MinorVersion}.{BuildVersion}";
    }
}
