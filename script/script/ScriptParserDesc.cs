// This source code is a part of Project Violet.
// Copyright (C) 2020. rollrat. Licensed under the MIT Licence.

using ParserGenerator;
using System;
using System.Collections.Generic;
using System.Text;

namespace script
{
    /*
        
        EBNF: VIOLET-SCRIPT
        
            script   -> block

            comment  -> ##.*?
            line     -> comment
                      | stmt
                      | stmt comment
                      | e
            
            stmt     -> func
                      | index = index
                      | runnable
                      
            block    -> [ block ]
                     -> line block
                     -> e
                     
            name     -> [_a-zA-Z]\w*
                      | $name            ; Inernal functions

            number   -> [0-9]+
            string   -> "([^\\"]|\\")*"
            const    -> number
                      | string
                     
            var      -> name
            
            index    -> variable
                      | variable [ variable ]
            variable -> var
                      | function
                      | const

            argument -> index
                      | index, argument
            function -> name ( )
                      | name ( argument )
            
            runnable -> loop (var = index "to" index) block
                      | foreach (var : index)         block
                      | if (index)                    block
                      | if (index)                    block else block
    */

    public class ScriptParserDesc
    {
        public static ExtendedShiftReduceParser Create()
        {
            var gen = new ParserGenerator.ParserGenerator();

            var script = gen.CreateNewProduction("script", false);
            var line = gen.CreateNewProduction("line", false);
            var stmt = gen.CreateNewProduction("stmt", false);
            var block = gen.CreateNewProduction("block", false);
            var consts = gen.CreateNewProduction("consts", false);
            var index = gen.CreateNewProduction("index", false);
            var variable = gen.CreateNewProduction("variable", false);
            var argument = gen.CreateNewProduction("argument", false);
            var function = gen.CreateNewProduction("function", false);
            var runnable = gen.CreateNewProduction("runnable", false);

            script |= block;

            line |= stmt;

            stmt |= function;
            stmt |= index + "=" + index;
            stmt |= runnable;

            block |= "[" + block + "]";
            block |= line + block;
            block |= ParserGenerator.ParserGenerator.EmptyString;

            consts |= "number";
            consts |= "string";

            index |= variable;
            index |= variable + "[" + variable + "]";

            variable |= "name";
            variable |= "function";
            variable |= consts;

            argument |= index;
            argument |= index + "," + argument;

            function |= "name" + gen.TryCreateNewProduction("(") + ")";
            function |= "name" + gen.TryCreateNewProduction("(") + argument + ")";

            runnable |= gen.TryCreateNewProduction("loop") + "(" + gen.TryCreateNewProduction("name") + "=" + index + "to" + index + ")" + block;
            runnable |= gen.TryCreateNewProduction("foreach") + "(" + gen.TryCreateNewProduction("name") + ":" + index + ")" + block;
            runnable |= gen.TryCreateNewProduction("if") + "(" + index + ")" + block;
            runnable |= gen.TryCreateNewProduction("if") + "(" + index + ")" + block + "else" + block;

            gen.PushConflictSolver(true, gen.TryCreateNewProduction("name"),
                                         gen.TryCreateNewProduction("loop"),
                                         gen.TryCreateNewProduction("foreach"),
                                         gen.TryCreateNewProduction("number"),
                                         gen.TryCreateNewProduction("string"),
                                         gen.TryCreateNewProduction("else"),
                                         gen.TryCreateNewProduction("if"));


            gen.PushConflictSolver(true, gen.TryCreateNewProduction("["));
            gen.PushConflictSolver(false, new Tuple<ParserProduction, int>(index, 0));

            gen.PushConflictSolver(false, new Tuple<ParserProduction, int>(block, 0));
            gen.PushConflictSolver(false, new Tuple<ParserProduction, int>(block, 2));

            gen.PushConflictSolver(false, new Tuple<ParserProduction, int>(runnable, 3));
            gen.PushConflictSolver(false, new Tuple<ParserProduction, int>(runnable, 2));

            gen.PushStarts(script);
            gen.PrintProductionRules();
            try
            {
                gen.Generate();
            }
            catch { }
            gen.PrintTable();

            Console.WriteLine(gen.GlobalPrinter.ToString());

            return gen.CreateExtendedShiftReduceParserInstance();
        }


    }
}
