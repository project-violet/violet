// This source code is a part of Project Violet.
// Copyright (C) 2020. rollrat. Licensed under the MIT Licence.

using Newtonsoft.Json;
using ParserGenerator;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace script
{
    class Program
    {
        static void Main(string[] args)
        {
            var scanner = ScriptScannerDesc.Create();
            var parser = ScriptParserDesc.Create();

#if DEBUG
            //
            //  Accept Test Set
            //
            Test1(scanner, parser, "b=a[1]");
            Test1(scanner, parser, "func(a,b,c) = c");
            Test1(scanner, parser, @"
// Test if-else conflict
if (cc(1))
    if (cc(2))
        bb()
    else
        cc()
else
    aa()
");
            Test1(scanner, parser, @"
if (or(gre(sum(x,y), sub(x,y)), iscon(x,y,z))) [
    foreach (k : arrayx) 
        print(k)
    k[3] = 6 // Assign 6 to k[3]
] else if (not(iscon(x,y,z))) [
    k[2] = 7
]
");

            //
            //  Invalid Test Set
            //
            Test1(scanner, parser, "a[2]] = 3");
#endif

            Console.WriteLine(Compile(scanner, parser, @"
if (or(gre(sum(x,y), sub(x,y)), iscon(x,y,z))) [
    foreach (k : arrayx) 
        print(k)
    k[3] = 6 // Assign 6 to k[3]
] else if (not(iscon(x,y,z))) [
    k[2] = 7
]
"));
        }

        static void Test1(Scanner scanner, ExtendedShiftReduceParser parser, string target)
        {
            parser.Clear();
            Action<string, string, int, int> insert = (string x, string y, int a, int b) =>
            {
                parser.Insert(x, y);
                if (parser.Error())
                    throw new Exception($"[COMPILER] Parser error! L:{a}, C:{b}");
                while (parser.Reduce())
                {
                    var l = parser.LatestReduce();
                    Console.Write(l.Production.PadLeft(8) + " => ");
                    Console.WriteLine(string.Join(" ", l.Childs.Select(z => z.Production)));
                    Console.Write(l.Production.PadLeft(8) + " => ");
                    Console.WriteLine(string.Join(" ", l.Childs.Select(z => z.Contents)));
                    parser.Insert(x, y);
                    if (parser.Error())
                        throw new Exception($"[COMPILER] Parser error! L:{a}, C:{b}");
                }
            };

            try
            {
                var line = target;
                scanner.AllocateTarget(line.Trim());

                while (scanner.Valid())
                {
                    var tk = scanner.Next();
                    Console.WriteLine(tk);
                    if (scanner.Error())
                        throw new Exception("[COMPILER] Tokenize error! '" + tk + "'");
                    insert(tk.Item1, tk.Item2, tk.Item3, tk.Item4);
                }

                if (parser.Error()) throw new Exception();
                insert("$", "$", -1, -1);
                Console.WriteLine();
                var tree = parser.Tree;
                var builder = new StringBuilder();
                tree.Print(builder);
                Console.WriteLine(builder.ToString());
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);
            }

            Console.WriteLine("===========================");
        }

        public static string Compile(Scanner scanner, ExtendedShiftReduceParser parser, string target)
        {
            Action<string, string, int, int> insert = (string x, string y, int a, int b) =>
            {
                parser.Insert(x, y);
                if (parser.Error())
                    throw new Exception($"[COMPILER] Parser error! L:{a}, C:{b}");
                while (parser.Reduce())
                {
                    var l = parser.LatestReduce();
                    Console.Write(l.Production.PadLeft(8) + " => ");
                    Console.WriteLine(string.Join(" ", l.Childs.Select(z => z.Production)));
                    Console.Write(l.Production.PadLeft(8) + " => ");
                    Console.WriteLine(string.Join(" ", l.Childs.Select(z => z.Contents)));
                    parser.Insert(x, y);
                    if (parser.Error())
                        throw new Exception($"[COMPILER] Parser error! L:{a}, C:{b}");
                }
            };

            try
            {
                var line = target;
                scanner.AllocateTarget(line.Trim());

                while (scanner.Valid())
                {
                    var tk = scanner.Next();
                    Console.WriteLine(tk);
                    if (scanner.Error())
                        throw new Exception("[COMPILER] Tokenize error! '" + tk + "'");
                    insert(tk.Item1, tk.Item2, tk.Item3, tk.Item4);
                }

                if (parser.Error()) throw new Exception();
                insert("$", "$", -1, -1);
                Console.WriteLine();
                var tree = parser.Tree;
                var builder = new StringBuilder();
                tree.Print(builder);
                Console.WriteLine(builder.ToString());
                tree.root.Tidy();
                return JsonConvert.SerializeObject(tree.root, Formatting.None, new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore
                });
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);
            }

            return "";
        }
    }
}
