# CodeGen

##Introduction
**CodeGen** template based code/text generator. The program takea a template that describes what the output ..
looks like and and a data file that defines what is to be generated.

** CodeGen -tmpl test.tmpl test.json **

In this case the **test.tmpl** file describes what the output will look like and **test.json** is that data ..
that is used to generate the output. Currently only JSON is supported for the data file but other formats ..
can be supported. 

* The **-dest** switch specifies a root directory for the output (default tmp).
* The **-copy** switch specifies a root directory where the files are copied to and merged with any existing files.

## Building

**CodeGen** is platform independent code written in **D**. For further details on the lanuage see ..
[dlang](https://dlang.org/).

The **test.sh** script will build and run the unittests using **dub** and then run an example command. ..
The application is known to build with a recent version of both **dmd** and **ldc**.

## Templates

The template files are a line based format. The basic element in a template is a named text block. ..
The template starts with the **ROOT** block.

> !BLK ROOT ..
> This is some text that will be output ..
> !END ..

The above block will not output anything since there is no output specified. There is a special type ..
of block that specifies an output file for the block and everthing it referenes.

> !FIL ROOT file.txt ..
> This is some text that will be output ..
> !END ..

Blocks can have subtypes and can reference other blocks to build up the output.

> !FIL ROOT file.txt ..
> My name is ![USER:local]! ..
> !END ..
> ..
> !BLK USER:local ..
> David ..
> !END ..

Blocks have a shorter form and can be used in references to other blocks.

> !FIL ROOT file.txt ..
> My name is ![USER:(TYPE)]! ..
> !END ..
> ..
> !BLK TYPE =system ..
> !BLK USER:local =David ..
> !BLK USER:system =Fred ..

As this stands it is quite limited. The power comes from the data file. The data file is parse and ..
generates a parse tree of **Data Blocks** (IDataBlock). Each data block defines a number of named ..
text blocks like simple text blocks in the template. In addition then define named data blocks referenced ..
from the current data block. These can be accessed using the **USING** reference. The data blocks all so ..
defines names lists of data blocks that can be iterated over using **FOREACH** and **LIST**.

> !FIL ROOT file.txt ..
> ![USING BILL IDENTIFY]! ..
> ![LIST ENTRY (COMMA) ID]! ..
> ![FOREACH ENTRY EXPAND]! ..
> !END ..
> ..
> !BLK IDENTIFY =My name is ![NAME]! ..
> !BLK ID =![NAME]! ..
> !BLK COMMA =,  ..
> !BLK EXPAND ..
> void ![NAME]! ..
> { ..
> } !END ..

When there is a hierarch of data blocks you can specify that you want a list of the leaf data blocks ..
in the hiierarchy.

> !FIL ROOT file.txt ..
> ![LIST ENTRY LEAF (COMMA) ID]! ..
> ![FOREACH ENTRY LEAF EXPAND]! ..
> !END ..

There are also a number of special reference types.

> !FIL ROOT file.txt ..
> Somthing![COL 30]!:This will be in column  ..
> Somthing![TAB 10]!:This will a tabbed 10 spaces. ..
> !END ..

There is a special **EVAL** block type.

> !FIL ROOT file.txt ..
> ![EXPRESSION]! = ![EVALUATE]! 
> !END ..
> ..
> // This will evaluate the text and a numerical expression ..
> // and return the result as text ..
> !EVAL EVALUATE =![EXPRESSION]! ..
> ..
> EVALUATE = 7*(2+3) ..

This can be used with a special named block **SUBTYPE**. The block **SUBTYPE** is the subtype ..
that the block was refernced with. A block with no specified subtype will match a reference ..
with any subtype. If is the defauly block for the given named block.

> !FIL ROOT file.txt ..
> ![EXPRESSION]! = ![EVALUATE:(EXPRESSION)]!  ..
> !END ..
> ..
> // This will evaluate the text and a numerical expression ..
> // and return the result as text ..
> !EVAL EVALUATE =![SUBTYPE]!v
> ..
> EVALUATE = 7*(2+3) ..

There a few other bits.
* Text blocks can be included into file names in **FIL** definitions.
* The **CONFIG** block inserts configuration values with the name of the subtype.
* There are some built in text blocks.
* For names there some standard subtypes

> !FIL ROOT (FILE).txt ..
> namespace ![CONFIG:namespace]!  ..
> { ..
>     YEAR     = ![YEAR]! ..
>     USER     = ![USER]! ..
>     USERNAME = ![USERNAME]! ..
>     ![FILE]!        = FileName ..
>     ![FILE:CAMEL]!  = fileName ..
>     ![FILE:PASCAL]! = FileName ..
>     ![FILE:UPPER1]! = FILE_NAME ..
>     ![FILE:LOWER1]! = file_name ..
>     ![FILE:SNAKE]!  = file_name ..
>     ![FILE:UPPER2]! = FILE-NAME ..
>     ![FILE:LOWER2]! = file-name ..
>     ![FILE:KEBAB]!  = file-name ..
> } ..
> !END ..
> ..
> !BLK FILE =FileName ..
> ..
> EVALUATE = 7*(2+3) ..

Finally the **INC** statement will include another template file into this template file. ..
This is useful to keep common definitions in one place.

> !INC common.tmpl ..
> !INC "Fancy name.tmpl" ..
> ..
> !FIL ROOT file.txt ..
> Do something ..
> !END ..

## Merging file

To Do

## Creating Parse Trees

To Do