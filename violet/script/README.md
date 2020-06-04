# Violet Script

## Tokenizer Rule

This tokenizer can only scan ASCII code sets.
Therefore, all characters that exceed the maximum value of ASCII code 
must be replaced with one of the ASCII code alphabets.

```
��          => [\r\n ]
��          => //[^\n]*\n
=          => =
[          => \[
]          => \]
var        => var
:          => :
,          => ,
(          => \(
)          => \)
loop       => loop
foreach    => foreach
if         => if
to         => to
else       => else
function   => function
name       => [_a-zA-Z][_a-zA-Z0-9]*
number     => [0-9]+
string     => "([^\\"]|\\")*"
```

## Parser Rule

```
   1:         S' -> script
   2:     script -> block
   3:       line -> stmt
   4:       stmt -> function
   5:       stmt -> index = index
   6:       stmt -> runnable
   7:      block -> [ block ]
   8:      block -> line block
   9:      block ->
  10:     consts -> number
  11:     consts -> string
  12:      index -> variable
  13:      index -> variable [ variable ]
  14:   variable -> name
  15:   variable -> function
  16:   variable -> consts
  17:   argument -> index
  18:   argument -> index , argument
  19:   function -> name ( )
  20:   function -> name ( argument )
  21:   runnable -> loop ( name = index to index ) block
  22:   runnable -> foreach ( name : index ) block
  23:   runnable -> if ( index ) block
  24:   runnable -> if ( index ) block else block
```

## Test 

### Test 1

```
b=a[1]
```

```
+-script
  +-block
    |-line
    | +-stmt
    |   |-index
    |   | +-variable
    |   |   +-name b
    |   |-= =
    |   +-index
    |     |-variable
    |     | +-name a
    |     |-[ [
    |     |-variable
    |     | +-consts
    |     |   +-number 1
    |     +-] ]
    +-block
```

### Test 2

```
func(a,b,c) = c
```

```
+-script
  +-block
    |-line
    | +-stmt
    |   |-index
    |   | +-variable
    |   |   +-function
    |   |     |-name func
    |   |     |-( (
    |   |     |-argument
    |   |     | |-index
    |   |     | | +-variable
    |   |     | |   +-name a
    |   |     | |-, ,
    |   |     | +-argument
    |   |     |   |-index
    |   |     |   | +-variable
    |   |     |   |   +-name b
    |   |     |   |-, ,
    |   |     |   +-argument
    |   |     |     +-index
    |   |     |       +-variable
    |   |     |         +-name c
    |   |     +-) )
    |   |-= =
    |   +-index
    |     +-variable
    |       +-name c
    +-block
```

### Test 3

```
// Test if-else conflict
if (cc(1))
    if (cc(2))
        bb()
    else
        cc()
else
    aa()
```

```
+-script
  +-block
    |-line
    | +-stmt
    |   +-runnable
    |     |-if if
    |     |-( (
    |     |-index
    |     | +-variable
    |     |   +-function
    |     |     |-name cc
    |     |     |-( (
    |     |     |-argument
    |     |     | +-index
    |     |     |   +-variable
    |     |     |     +-consts
    |     |     |       +-number 1
    |     |     +-) )
    |     |-) )
    |     |-block
    |     | |-line
    |     | | +-stmt
    |     | |   +-runnable
    |     | |     |-if if
    |     | |     |-( (
    |     | |     |-index
    |     | |     | +-variable
    |     | |     |   +-function
    |     | |     |     |-name cc
    |     | |     |     |-( (
    |     | |     |     |-argument
    |     | |     |     | +-index
    |     | |     |     |   +-variable
    |     | |     |     |     +-consts
    |     | |     |     |       +-number 2
    |     | |     |     +-) )
    |     | |     |-) )
    |     | |     |-block
    |     | |     | |-line
    |     | |     | | +-stmt
    |     | |     | |   +-function
    |     | |     | |     |-name bb
    |     | |     | |     |-( (
    |     | |     | |     +-) )
    |     | |     | +-block
    |     | |     |-else else
    |     | |     +-block
    |     | |       |-line
    |     | |       | +-stmt
    |     | |       |   +-function
    |     | |       |     |-name cc
    |     | |       |     |-( (
    |     | |       |     +-) )
    |     | |       +-block
    |     | +-block
    |     |-else else
    |     +-block
    |       |-line
    |       | +-stmt
    |       |   +-function
    |       |     |-name aa
    |       |     |-( (
    |       |     +-) )
    |       +-block
    +-block
```

### Test 4

```
if (or(gre(sum(x,y), sub(x,y)), iscon(x,y,z))) [
    foreach (k : arrayx) 
        print(k)
    k[3] = 6 // Assign 6 to k[3]
] else if (not(iscon(x,y,z))) [
    k[2] = 7
]
```

```
+-script
  +-block
    |-line
    | +-stmt
    |   +-runnable
    |     |-if if
    |     |-( (
    |     |-index
    |     | +-variable
    |     |   +-function
    |     |     |-name or
    |     |     |-( (
    |     |     |-argument
    |     |     | |-index
    |     |     | | +-variable
    |     |     | |   +-function
    |     |     | |     |-name gre
    |     |     | |     |-( (
    |     |     | |     |-argument
    |     |     | |     | |-index
    |     |     | |     | | +-variable
    |     |     | |     | |   +-function
    |     |     | |     | |     |-name sum
    |     |     | |     | |     |-( (
    |     |     | |     | |     |-argument
    |     |     | |     | |     | |-index
    |     |     | |     | |     | | +-variable
    |     |     | |     | |     | |   +-name x
    |     |     | |     | |     | |-, ,
    |     |     | |     | |     | +-argument
    |     |     | |     | |     |   +-index
    |     |     | |     | |     |     +-variable
    |     |     | |     | |     |       +-name y
    |     |     | |     | |     +-) )
    |     |     | |     | |-, ,
    |     |     | |     | +-argument
    |     |     | |     |   +-index
    |     |     | |     |     +-variable
    |     |     | |     |       +-function
    |     |     | |     |         |-name sub
    |     |     | |     |         |-( (
    |     |     | |     |         |-argument
    |     |     | |     |         | |-index
    |     |     | |     |         | | +-variable
    |     |     | |     |         | |   +-name x
    |     |     | |     |         | |-, ,
    |     |     | |     |         | +-argument
    |     |     | |     |         |   +-index
    |     |     | |     |         |     +-variable
    |     |     | |     |         |       +-name y
    |     |     | |     |         +-) )
    |     |     | |     +-) )
    |     |     | |-, ,
    |     |     | +-argument
    |     |     |   +-index
    |     |     |     +-variable
    |     |     |       +-function
    |     |     |         |-name iscon
    |     |     |         |-( (
    |     |     |         |-argument
    |     |     |         | |-index
    |     |     |         | | +-variable
    |     |     |         | |   +-name x
    |     |     |         | |-, ,
    |     |     |         | +-argument
    |     |     |         |   |-index
    |     |     |         |   | +-variable
    |     |     |         |   |   +-name y
    |     |     |         |   |-, ,
    |     |     |         |   +-argument
    |     |     |         |     +-index
    |     |     |         |       +-variable
    |     |     |         |         +-name z
    |     |     |         +-) )
    |     |     +-) )
    |     |-) )
    |     |-block
    |     | |-[ [
    |     | |-block
    |     | | |-line
    |     | | | +-stmt
    |     | | |   +-runnable
    |     | | |     |-foreach foreach
    |     | | |     |-( (
    |     | | |     |-name k
    |     | | |     |-: :
    |     | | |     |-index
    |     | | |     | +-variable
    |     | | |     |   +-name arrayx
    |     | | |     |-) )
    |     | | |     +-block
    |     | | |       |-line
    |     | | |       | +-stmt
    |     | | |       |   +-function
    |     | | |       |     |-name print
    |     | | |       |     |-( (
    |     | | |       |     |-argument
    |     | | |       |     | +-index
    |     | | |       |     |   +-variable
    |     | | |       |     |     +-name k
    |     | | |       |     +-) )
    |     | | |       +-block
    |     | | |         |-line
    |     | | |         | +-stmt
    |     | | |         |   |-index
    |     | | |         |   | |-variable
    |     | | |         |   | | +-name k
    |     | | |         |   | |-[ [
    |     | | |         |   | |-variable
    |     | | |         |   | | +-consts
    |     | | |         |   | |   +-number 3
    |     | | |         |   | +-] ]
    |     | | |         |   |-= =
    |     | | |         |   +-index
    |     | | |         |     +-variable
    |     | | |         |       +-consts
    |     | | |         |         +-number 6
    |     | | |         +-block
    |     | | +-block
    |     | +-] ]
    |     |-else else
    |     +-block
    |       |-line
    |       | +-stmt
    |       |   +-runnable
    |       |     |-if if
    |       |     |-( (
    |       |     |-index
    |       |     | +-variable
    |       |     |   +-function
    |       |     |     |-name not
    |       |     |     |-( (
    |       |     |     |-argument
    |       |     |     | +-index
    |       |     |     |   +-variable
    |       |     |     |     +-function
    |       |     |     |       |-name iscon
    |       |     |     |       |-( (
    |       |     |     |       |-argument
    |       |     |     |       | |-index
    |       |     |     |       | | +-variable
    |       |     |     |       | |   +-name x
    |       |     |     |       | |-, ,
    |       |     |     |       | +-argument
    |       |     |     |       |   |-index
    |       |     |     |       |   | +-variable
    |       |     |     |       |   |   +-name y
    |       |     |     |       |   |-, ,
    |       |     |     |       |   +-argument
    |       |     |     |       |     +-index
    |       |     |     |       |       +-variable
    |       |     |     |       |         +-name z
    |       |     |     |       +-) )
    |       |     |     +-) )
    |       |     |-) )
    |       |     +-block
    |       |       |-[ [
    |       |       |-block
    |       |       | |-line
    |       |       | | +-stmt
    |       |       | |   |-index
    |       |       | |   | |-variable
    |       |       | |   | | +-name k
    |       |       | |   | |-[ [
    |       |       | |   | |-variable
    |       |       | |   | | +-consts
    |       |       | |   | |   +-number 2
    |       |       | |   | +-] ]
    |       |       | |   |-= =
    |       |       | |   +-index
    |       |       | |     +-variable
    |       |       | |       +-consts
    |       |       | |         +-number 7
    |       |       | +-block
    |       |       +-] ]
    |       +-block
    +-block
```

```
{"p":"script","c":[{"p":"block","c":[{"p":"line","c":[{"p":"stmt","c":[{"p":"runnable","c":[{"p":"if"},{"p":"index","c":[{"p":"variable","c":[{"p":"function","c":[{"p":"name","t":"or"},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"function","c":[{"p":"name","t":"gre"},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"function","c":[{"p":"name","t":"sum"},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"x"}]}]},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"y"}]}]}]}]}]}]}]},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"function","c":[{"p":"name","t":"sub"},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"x"}]}]},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"y"}]}]}]}]}]}]}]}]}]}]}]}]},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"function","c":[{"p":"name","t":"iscon"},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"x"}]}]},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"y"}]}]},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"z"}]}]}]}]}]}]}]}]}]}]}]}]}]},{"p":"block","c":[{"p":"block","c":[{"p":"line","c":[{"p":"stmt","c":[{"p":"runnable","c":[{"p":"foreach"},{"p":"name","t":"k"},{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"arrayx"}]}]},{"p":"block","c":[{"p":"line","c":[{"p":"stmt","c":[{"p":"function","c":[{"p":"name","t":"print"},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"k"}]}]}]}]}]}]},{"p":"block","c":[{"p":"line","c":[{"p":"stmt","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"k"}]},{"p":"variable","c":[{"p":"consts","c":[{"p":"number","t":"3"}]}]}]},{"p":"index","c":[{"p":"variable","c":[{"p":"consts","c":[{"p":"number","t":"6"}]}]}]}]}]},{"p":"block","t":""}]}]}]}]}]},{"p":"block","t":""}]}]},{"p":"else"},{"p":"block","c":[{"p":"line","c":[{"p":"stmt","c":[{"p":"runnable","c":[{"p":"if"},{"p":"index","c":[{"p":"variable","c":[{"p":"function","c":[{"p":"name","t":"not"},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"function","c":[{"p":"name","t":"iscon"},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"x"}]}]},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"y"}]}]},{"p":"argument","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"z"}]}]}]}]}]}]}]}]}]}]}]}]},{"p":"block","c":[{"p":"block","c":[{"p":"line","c":[{"p":"stmt","c":[{"p":"index","c":[{"p":"variable","c":[{"p":"name","t":"k"}]},{"p":"variable","c":[{"p":"consts","c":[{"p":"number","t":"2"}]}]}]},{"p":"index","c":[{"p":"variable","c":[{"p":"consts","c":[{"p":"number","t":"7"}]}]}]}]}]},{"p":"block","t":""}]}]}]}]}]},{"p":"block","t":""}]}]}]}]},{"p":"block","t":""}]}]}
```

### Test 5

```
a[2]] = 3
```

```
+-index
  |-variable
  | +-name a
  |-[ [
  |-variable
  | +-consts
  |   +-number 2
  +-] ]

[COMPILER] Parser error! L:1, C:5
```