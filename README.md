# CodeGen

## Introduction
**CodeGen** template based code/text generator. The program takea a template that describes what the output
looks like and and a data file that defines what is to be generated.

**CodeGen -tmpl test.tmpl test.json**

In this case the **test.tmpl** file describes what the output will look like and **test.json** is that data
that is used to generate the output. Currently only JSON is supported for the data file but other formats
can be supported. 

* The **-dest** switch specifies a root directory for the output (default tmp).
* The **-copy** switch specifies a root directory where the files are copied to and merged with any existing files.

## Building

**CodeGen** is platform independent code written in **D**. For further details on the lanuage see
[dlang](https://dlang.org/).

The **test.sh** script will build and run the unittests using **dub** and then run an example command.
The application is known to build with a recent version of both **dmd** and **ldc**.

## Templates

The template files are a line based format. The basic element in a template is a named text block.
The template starts with the **ROOT** block.

```
!BLK ROOT
This is some text that will be output
!END
```

The above block will not output anything since there is no output specified. There is a special type
of block that specifies an output file for the block and everthing it referenes.

```
!FIL ROOT file.txt
This is some text that will be output
!END
```

Blocks can have subtypes and can reference other blocks to build up the output.

```
!FIL ROOT file.txt
My name is ![USER:local]!
!END

!BLK USER:local
David
!END
```

Blocks have a shorter form and can be used in references to other blocks.

```
!FIL ROOT file.txt
My name is ![USER:(TYPE)]!
!END

!BLK TYPE =system
!BLK USER:local =David
!BLK USER:system =Fred
```

As this stands it is quite limited. The power comes from the data file. The data file is parsed and
generates a parse tree of **Data Blocks** (IDataBlock). Each data block defines a number of named
text blocks like simple text blocks in the template. In addition they define named data blocks referenced
from the current data block. These can be accessed using the **USING** reference. The data blocks also
defines names lists of data blocks that can be iterated over using **FOREACH** and **LIST**.
All block expand in the context of a data block and has access to the blocks, data blocks and lists defined by
that data block.

The **LIST** and **FOREACH** below step through the **ENTRY** list and expand the blocks (ID and EXPAND)
in the context of each entry. The **LIST** form inserts the block **COMMA** between each entry
(but not at the end).

```
!FIL ROOT file.txt
![USING BILL IDENTIFY]!
![LIST ENTRY (COMMA) ID]!
![FOREACH ENTRY EXPAND]!
!END

!BLK IDENTIFY =My name is ![NAME]!
!BLK ID =![NAME]!
!BLK COMMA =, 
!BLK EXPAND
void ![NAME]!
{
} !END
```

When there is a hierarchy of data blocks you can specify that you want a list of the leaf data blocks
in the hiierarchy.

```
!FIL ROOT file.txt
![LIST LEAF ENTRY (COMMA) ID]!
![FOREACH LEAF ENTRY EXPAND]!
!END
```

There is a special **USING** reference called **PREV**. This switches to the previous data block. When
the data file has a hierarchy you could implement a data block reference **PARENT** to the data block
above the current data block in the hierarchy.

There are also a number of special reference types.

```
!FIL ROOT file.txt
Somthing![COL 30]!:This will be in column 30
Somthing![TAB 10]!:This will a tabbed 10 spaces.
!END
```

There is a special **EVAL** block type.

```
!FIL ROOT file.txt
![EXPRESSION]! = ![EVALUATE]! 
!END

// This will evaluate the text and a numerical expression
// and return the result as text
!EVAL EVALUATE =![EXPRESSION]!

EVALUATE = 7*(2+3)
```

This can be used with a special named block **SUBTYPE**. The block **SUBTYPE** is the subtype
that the block was refernced with. A block with no specified subtype will match a reference
with any subtype. It is the default block for the given named block.

Both **//** and **%%** can be used to add comment lines to the template.

```
!FIL ROOT file.txt
![EXPRESSION]! = ![EVALUATE:(EXPRESSION)]! 
none = ![EVALUATE:none]! 
!END

// This will evaluate the text and a numerical expression
// and return the result as text
!EVAL EVALUATE =![SUBTYPE]!

!BLK EVALUATE:none =No expression

EVALUATE = 7*(2+3)
```

There a few other bits.
* Text blocks can be included into file names in **FIL** definitions.
* The **CONFIG** block inserts blocks (configuration) from the root data block with the name of the subtype.
* There are some built in text blocks.
* For names there some standard subtypes

```
!FIL ROOT (FILE).txt
namespace ![CONFIG:namespace]! 
{
    YEAR     = ![YEAR]!
    USER     = ![USER]!
    USERNAME = ![USERNAME]!
    TMPL     = ![TMPL]!    -- Name of the template.
    CLASS    = ![CLASS]!   -- The class or type of the current data object
    ![FILE]!        = FileName
    ![FILE:CAMEL]!  = fileName
    ![FILE:PASCAL]! = FileName
    ![FILE:UPPER1]! = FILE_NAME
    ![FILE:LOWER1]! = file_name
    ![FILE:SNAKE]!  = file_name
    ![FILE:UPPER2]! = FILE-NAME
    ![FILE:LOWER2]! = file-name
    ![FILE:KEBAB]!  = file-name
}
!END

!BLK FILE =FileName

EVALUATE = 7*(2+3)
```

Finally the **INC** statement will include another template file into this template file.
This is useful to keep common definitions in one place.

```
!INC common.tmpl
!INC "Fancy name.tmpl"

!FIL ROOT file.txt
Do something
!END
```

### Summary ###
Templates are programming with switch statements and recursion!

## Merging file

When merging a generated file into an existing file sections marked below are retain from the 
existing file.

```
<token> USER CODE BEGIN <name>  ...
....
<token> USER CODE END <name>  ...
```

For example:

```
Generated code
// USER CODE BEGIN fred harry
User code
// USER CODE END fred 
Generated code
// USER CODE BEGIN harry
User code
// USER CODE END harry
Generated code
```

The blocks in the two files are matched using the **<name>**. This means that the Blocks
can be reordered in the output. If a block does not exist in the existing file the generated
version will be used.

There is an **experimental** inverse merge option when the template contains the following line.

```
!SET InvertMerge true
```

In this case when merging a generated file into an existing file sections marked below are inserted
into the existing file.

```
<token> GEN CODE BEGIN <name>  ...
....
<token> GEN CODE END <name>  ...
```

For example:

```
User code
// GEN CODE BEGIN fred harry
Generated code
// GEN CODE END fred 
User code
// GEN CODE BEGIN harry
Generated code
// GEN CODE END harry
User code
```

## JSON Data


## Creating Parse Trees

The entry point for parsing a new data format is the **ParseData(string filename)** method
in **InputData.d**. This method uses the file suffix to identify the file format and calls
the correct parsing routine for the data. The parser return the root **IDataBlock** instance.

*This could be updated to 'snif' the file to identify its format*

The JSON parser is a simple example to get you started.

The **IDataBlock** interface defined in **Data.d** defines the following methods.

1. The method **string Class();** returns the CLASS or type of this data Blocks
2. The method **string Posn();** returns a string identifying where in the data file this data block is defined.
This must be generated when parsing the data.
3. The Method **bool DoBlock(BaseOutput output, string name, string subtype);** writes out The
text from a named block with the given subtype. It returns whether the block is defined for this 
data block.
The method **FormatName(text, subtype)** in **Utilities.d** can be used to apply the standard subtypes.
4. The method **IDataBlock Using(string item);** returns the data block for a named **USING** reference. If the 
data block is undefined then it return **null**.
5. The method **Tuple!(bool, DList!IDataBlock) List(bool leaf, string item);** returns a named list
of data blocks. The first entry in the tuple indicates whether the list is defined.

It is up to you to decide how your data maps on to the parse tree and what data it provides.

### Parser Support ###

Your parser can use a **InputStack** defined in **Input.d**. This reads the file a character at 
a time or a line at a time to support different parser types. In addition it supports pushing
and poping files to support **include** statements.

The **string Posn()** methos gives the current position in the input data in a convenient format for
error reporting.


