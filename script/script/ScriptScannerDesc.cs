// This source code is a part of Project Violet.
// Copyright (C) 2020. rollrat. Licensed under the MIT Licence.

using ParserGenerator;
using System;
using System.Collections.Generic;
using System.Text;

namespace script
{
    public class ScriptScannerDesc
    {
        public static Scanner Create()
        {
            var gen = new ScannerGenerator();

            gen.PushRule("", @"[\r\n ]");
            gen.PushRule("", @"//[^\n]*\n");
            gen.PushRule("=", "=");
            gen.PushRule("[", @"\[");
            gen.PushRule("]", @"\]");
            gen.PushRule("var", "var");
            gen.PushRule(":", ":");
            gen.PushRule(",", ",");
            gen.PushRule("(", @"\(");
            gen.PushRule(")", @"\)");
            gen.PushRule("loop", "loop");
            gen.PushRule("foreach", "foreach");
            gen.PushRule("if", "if");
            gen.PushRule("to", "to");
            gen.PushRule("else", "else");
            gen.PushRule("function", "function");
            gen.PushRule("name", "[_a-zA-Z][_a-zA-Z0-9]*");
            gen.PushRule("number", "[0-9]+");
            gen.PushRule("string", @"""([^\\""]|\\"")*""");

            gen.Generate();

            Console.WriteLine(gen.PrintDiagram());

            return gen.CreateScannerInstance();
        }
    }
}
