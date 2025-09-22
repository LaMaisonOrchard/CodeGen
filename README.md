# CodeGen

## Introduction
**CodeGen** template based code/text generator. The program takea a template that describes what the output
looks like and and a data file that defines what is to be generated.

**CodeGen -tmpl test.tmpl test.json**

In this case the **test.tmpl** file describes what the output will look like and **test.json** is the data
that is used to generate the output. Currently only JSON and PROTO are supported for the data file but other formats
can be supported. 

* The **-dest** switch specifies a root directory for the output (default tmp).
* The **-copy** switch specifies a root directory where the files are copied to and merged with any existing files.

Multiple tempates and data files can be specified and each data file is applied to each template.

There are also super templates supported. In this case the template is applied to all the files together.
A super objects is created that has a single list which is the files.

**CodeGen -super test.tmpl test1.json test1.json**

| Type   | Name   | Description                 |
| ------ | ------ | --------------------------- |
| Block  | CLASS  | The blocks class == "SUPER" |
| Block  | FILES  | The number of files         |
| List   | FILE   | A list of the files as read |

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

The block **IDX** expands to (zero based) index of the current loop.

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

EXPRESSION = 7*(2+3)
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

EXPRESSION = 7*(2+3)
```

There is a special **ERR** block type.

```
!FIL ROOT file.txt
![HELLO:fred]!
![HELLO:jan]! 
!END

!BLK HELLO:fred = Hi how are you Fred
!ERR HELLO = Unrecognised subtype error
```

If an **ERR** block is referenced then a fatal error is raise and the code generation stop.
The body of the block is used as the errors message.

There a few other bits.
* Text blocks can be included into file names in **FIL** definitions.
* The **CONFIG** block inserts blocks (configuration) from the root data block with the name of the subtype.
* There are some built in text blocks.
* For names there some standard subtypes

```
!FIL ROOT (FILE).txt
namespace ![CONFIG:namespace]! 
{
    YEAR            = ![YEAR]!
    MONTH           = ![MONTH]!
    DAY             = ![DAY]!
    HOUR            = ![HOUR]!
    MINUTE          = ![MINUTE]!
    SECOND          = ![SECOND]!
    USER            = ![USER]!
    USERNAME        = ![USERNAME]!
    TMPL            = ![TMPL]!           -- Name of the template.
    CLASS           = ![CLASS]!          -- The class or type of the current data object
    TMPL_VERSION    = ![TMPL_VERSION]!   -- Template version
    ![FILE]!        = FileName
    ![FILE:CAMEL]!  = fileName
    ![FILE:PASCAL]! = FileName
    ![FILE:UPPER1]! = FILE_NAME
    ![FILE:LOWER1]! = file_name
    ![FILE:SNAKE]!  = file_name
    ![FILE:UPPER2]! = FILE-NAME
    ![FILE:LOWER2]! = file-name
    ![FILE:KEBAB]!  = file-name
    ![VALUE]!       = 26
    ![VALUE:INT]!   = 26                  -- For text that can be interpreted as a value.
    ![VALUE:INT2]!  = 26                  -- For text that can be interpreted as a value.
    ![VALUE:INT4]!  = 0026                -- For text that can be interpreted as a value.
    ![VALUE:+INT]!  = +26                 -- For text that can be interpreted as a value.
    ![VALUE:+INT2]! = +26                 -- For text that can be interpreted as a value.
    ![VALUE:+INT4]! = +026                -- For text that can be interpreted as a value.
    ![VALUE:BIN4]!  = 11010               -- For text that can be interpreted as a value.
    ![VALUE:BIN8]!  = 00011010            -- For text that can be interpreted as a value.
    ![VALUE:BIN16]! = 0...0               -- For text that can be interpreted as a value.
    ![VALUE:BIN24]! = 0...0               -- For text that can be interpreted as a value.
    ![VALUE:BIN32]! = 0...0               -- For text that can be interpreted as a value.
    ![VALUE:HEX2]!  = 1A                  -- For text that can be interpreted as a value.
    ![VALUE:HEX4]!  = 001A                -- For text that can be interpreted as a value.
    ![VALUE:HEX8]!  = 0000001A            -- For text that can be interpreted as a value.
    ![VALUE:HEX16]! = 0...1A              -- For text that can be interpreted as a value.
    ![VALUE:hex2]!  = 1a                  -- For text that can be interpreted as a value.
    ![VALUE:hex4]!  = 001a                -- For text that can be interpreted as a value.
    ![VALUE:hex8]!  = 0000001a            -- For text that can be interpreted as a value.
    ![VALUE:hex16]! = 0...1a              -- For text that can be interpreted as a value.
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

## PROTO Data

The **proto** files have a self defining syntax. The root object in a **proto** file is the **proto** object.
The **object** definition defines which objects can be contain in other objects with **proto** being the root.

```
object(proto, enum);       // Top level enum objects
object(proto, message);    // Top level message objects
object(message, message);  // A message object can contain message objects
```

Some objects can be type definitions.

```
object(proto, enum);       // There can be a top level enum object
type(enum);                // Enum objects define a type
```

An object can contain named values, named text and named lists. Aswell as **fields**, **tables** and other **objects**.

```
message sendMe
{
    ID = 1;                     // Named value
    DEST = control;             // Named text
    SRC = [ ui, WiFi ];         // Named list
    
    uint8 src  = 1 "Source id"; // Full field
    uint8 dest = 2;             // No optional text
    uint8 value;                // No optional value or text
    
    {Type,     Name,  Description)
    {uint8,    Fred,  "Just an entry}
    {unit8[8], Harry, "Another entry")
    
    message sub_part            // Sub-object
    {
        uint16 payload;
        optional uint32 more_data;   // An optional field
    }
}
```

The first name in a **field** is a type and must be a valid pre-declared type defined using a type object. Array types
are of the form **<type>[]** or **<type>[<value>]**.

The first row in a table is the heading. The headings form a list **HEADING** of item withc class **TEXT** and block **TEST**.
The subsequent rows but have the same number of enties as the headings and define a lis **ROW**. Eecho row entry has a class of 
**ROW** a list of **ENTRY** where each entry has a class of **TEXT** or **VALUE** and a block of **TEXT** or **VALUE**.
The **ROW** also has a block for each **HEADING** which names the entry for that **HEADING**. The entry for a **HEADING**
**TYPE** must be a valid type and is accessable as **![USING TYPE ...]!**.

```
object(proto, enum);    
object(proto, typeDefn);
type(enum) ;             
type(typeDefn)  ; 

typeDefn uint8  {}
typeDefn uint16 {}  

enum errors   // enum type
{
    - OK = 0    "Passed correctly";              // The "-" in a field indicates that there is no type reference
    - FAIL = 1  "Failed to function correctly";
}

message sub_part            // Sub-object
{
    uint16 length;
    uint8[8] data
    uint8[] more_data;
}         
```

Named text where the name is "TYPE" must also define a valid type. Types referenced via a bnamed block or field Typecan be accessed
using **![USING TYPE <block>]!**. The underlying type of an array is accessed the the same way. A fixed size array has
a **CLASS** of **FIXED_ARRAY** and a block of **SIZE**. A variable sized array has a **CLASS** of **VAR_ARRAY**.

### Defined template items

Each named value defines a block that is the value.

**Proto**
```
fred = 7;
```
**Tmpl**
```
![FRED]!
```
Each named text defines a block that is the text. Named text with the name "TYPE" defines a type reference.
**Proto**
```
typeDefn UNIT8
{
    CTYPE=uint8_t;
}
harry = bill;
TYPE = UINT8;
```
**Tmpl**
```
![HARRY]!
![TYPE]!
![USING TYPE CTYPE]!
```
You can even have named lists. Each element of the list defines a class of TEXT or VALUE and a block TEXT. A value also has a block VALUE.
**Proto**
```
harry = { janet, lois, jean, brian, 78};
```
**Tmpl**
```
![FOREACH HARRY CLASS]!
```
Each object defintion defines a list of sub objects. A FOREAH LEAF will return a list of the leaf objects of a given type. 
An object defines a CLASS block which is the object type (uppercase and underscore) and a NAME block which is the instance name.
**Proto**
```
message fred
{
}
```
**Tmpl**
```
![FOREACH MESSAGE CLASS]!
![FOREACH LEAF MESSAGE NAME]!
```
An object can contain a list of FIELDs and BLOCKs. The BLOCK list is a list of named values and text. The named values define a
block VALUE and class VALUE. The named block TEXT and a cless TEXT. They both define a block NAME.
**proto**
```
message fred
{
    harry = 7;
    lois = orchard;
    UINT8 bill = 1 "The price";
}
```
**Tmpl**
```
![FOREACH BLOCK NAME]!
![FOREACH FIELD TYPE]!
```
A field defines servera; blocks and a type.
**Proto**
```
UINT8 bill = 1 "The price";
```
**Tmpl**
```
![TYPE]!
![NAME]!
![VALUE]!
![TEXT]!
![OPTIONAL]!    TRUE/FALSE
![USING TYPE NAME]!
```
Foreach list there is a block ending 'S' that is a value equal to the number of items in the list.
**proto**
```
message fred
{
    harry = 7;
    lois = orchard;
    UINT8 bill = 1 "The price";
}
```
**Tmpl**
```
![MESSAGES]!
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


