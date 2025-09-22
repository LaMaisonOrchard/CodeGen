//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.conv;
import std.container;
import std.stdio;
import std.array;
import std.typecons;
import std.path;
import std.uni;
import Input;
import Output;
import Data;
import Utilities;
import std.algorithm.searching;

/////////////////////////////////////////////////////////////////////
//
//  <name>        ::= (<letter> | "_") { <letter> | <number> | "_" }
//  <value>       ::= { <number> }
//  <text>        ::= { <non-whitespace> } 
//  <quoted text> ::= "\"" { <print> } "\""
//
//  <string>      ::= <value> | <name> | <text> | <quoted text>
//
//  <type>    ::= <name>
//  <param>   ::= <name> "=" <string> ";"
//  <field>   ::= ["optional"] <name> <name> "=" <value>";"
//  <defn>    ::= {<field>} | {<message>}
//  <include> ::= "include"  <quoted text> ";"
//  <type>    ::= "type" <name> "=" <name> ";"
//  <enum>    ::= "enum" <name> "{" {<field>} "}"
//  <message> ::= "message" <name> "{" {<param>} <defn> "}"
//  <root>    ::= {<include> | <param> | <enum> | <type> | {<message>}
//
/////////////////////////////////////////////////////////////////////

public
{
	class ProtoException : Exception
	{
		this(string msg)
		{
			super(msg);
		}
	}

	IDataBlock ParseProto(string name)
	{
		auto      input = new Tokenise(new InputStack(name));
		ProtoBlock root  = null;
			
		root = new ProtoBlock(input);
		
		if (input.HasError() || root.HasError())
		{
			throw new ProtoException(input.Posn()~"Parse error");
		}
		
		return root;
	}

}

private
{
    class ProtoData : IDataBlock
    {
		// A string to identify this type of data object
		override string Class()
        {
            return "BASE_CLASS";
        }
		
		string TrueClass()
        {
            return m_class;
        }
		
		// Position of this in the input file
		override string Posn()
        {
            return "NoWhere";
        }
		
		// Get a sub-item of this data item
		override IDataBlock Using(string item)
        {
            return null;
        }
		
		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
        {
			return tuple(false, DList!IDataBlock());
        }
		
		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
        {
            return false;
        }
		
		override void Dump(BaseOutput file)
        {
        }
    
        ProtoData GetType(string name)
        {
            auto p = name in m_typeList;
            if (p is null)
            {
                if (m_owner is null)
                {
                    return null;
                }
                else
                {
                    return m_owner.GetType(name);
                }
            }
            else
            {
                return *p;
            }
        }
        
        string            m_class;
        ProtoData         m_owner;
        ProtoData[string] m_typeList;
    }
    
	final class ProtoBlock : ProtoData
	{
		this(Tokenise input)
		{
			m_error = false;
			m_posn  = input.Posn();
			Parse(input);
            
            m_class = Class();
		}
		
		bool HasError()
		{
			return m_error;
		}
		
		// A string to identify this type of data object
		override string Class()
		{
			return "PROTO";
		}
		
		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}
		
		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
			return null;
		}
		
		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
            auto p = item in m_list;
                
            if (p is null)
            {
                return tuple(false, DList!IDataBlock());
            }
            else if (!leaf)
            {
                return tuple(true, DList!IDataBlock(*p));
            }
            else
            {
                Appender!(IDataBlock[]) leafList;
                    
                foreach (entry ; *p)
                {
                    auto p2 = entry.List(false, item);
                    if (p2[0])
                    {
                        foreach (entry2 ; entry.List(true, item)[1])
                        {
                            // This is a leaf entry
                            leafList ~= entry2;
                        }
                    }
                    else
                    {
                        leafList ~= entry;
                    }
                }
                    
                return tuple(true, DList!IDataBlock(leafList[]));
            }
		}
		
		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			if (name[$-1] == 'S')
			{
				auto p = name[0..$-1] in m_list;
				if (p !is null)
				{
					output.Write(FormatValue((*p).length, subtype));
					return true;
				}
			}

			auto p = name in m_textBlocks;
			
			if (p is null)
			{
				p = name in m_valueBlocks;
				if (p is null)
				{
					return false;
				}
				else
				{
					string value = *p;
					output.Write(FormatValue(Evaluate(value), subtype));
					return true;
				}
			}
			else
			{
				string value = *p;
				output.Write(FormatName(value, subtype));
				return true;
			}
		}
		
		override void Dump(BaseOutput file)
		{
		}
		
		void Error(string posn, string message)
		{
			writeln(posn, message);
			m_error = true;
		}
		
		void Parse(Tokenise input)
		{
			Token token = input.Get();

			while (token.type != Type.EOF)
			{
				if (token.type == Type.OBJECT)
				{
					ParseObjectDefn(input);
				}
				else if (token.type == Type.TYPE)
				{
					ParseTypeDefn(input);
				}
				else if (token.type == Type.INCLUDE)
				{
					ParseInclude(input);
				}
				else if (token.type == Type.NAME)
				{
					auto name = token;
					token = input.Get();

					if (token.type == Type.ASIGN)
					{
						ParseAsign(name, input);
					}
					else if (token.type == Type.NAME)
					{
						ParseObject(name, token, input);
					}
					else
					{
						Error(token.posn, "Unexpected token : [" ~ token.text ~ "]" ~ to!string(token.type));
						StripStatement(input, token);
					}
				}
				else
			    {
					Error(token.posn, "Unexpected token : [" ~ token.text ~ "]" ~ to!string(token.type));
					StripStatement(input, token);
			    }

			    token = input.Get();
			}
		}

		void ParseObjectDefn(Tokenise input)
		{
			auto token = input.Get();
			if (token.type != Type.OPEN)
			{
				Error(token.posn, "Missing object definition (expected ( )");
			}
			else
			{
				auto parent = input.Get();
				if (parent.type != Type.NAME)
				{
					Error(token.posn, "Missing parent in definition statement (expected <name> )");
				}
				else
				{
					token = input.Get();
					if (token.type != Type.SEP)
					{
						Error(token.posn, "Missing child in definition statement (expected , )");
					}
					else
					{
						auto child = input.Get();
						if (child.type != Type.NAME)
						{
							Error(token.posn, "Missing child in definition statement (expected <name> )");
						}
						else
						{
							token = input.Get();
							if (token.type != Type.CLOSE)
							{
								Error(token.posn, "Unterminated object definition statement (expected ) )");
							}
							else
							{
								AddDefinition(parent.text, child.text);
							}
						}
					}
				}
			}

			token = input.Get();
			if (token.type != Type.END_STATEMENT)
			{
				Error(token.posn, "Unterminated object definition statement (expected ; )");
				StripStatement(input, token);
			}
		}


		void ParseTypeDefn(Tokenise input)
		{
			auto token = input.Get();
			if (token.type != Type.OPEN)
			{
				Error(token.posn, "Missing object definition (expected ( )");
			}
			else
			{
				auto type = input.Get();
				if (type.type != Type.NAME)
				{
					Error(token.posn, "Missing type in definition statement (expected <name> )");
				}
				else
				{
                    token = input.Get();
                    if (token.type != Type.CLOSE)
                    {
                        Error(token.posn, "Unterminated object definition statement (expected ) )");
                    }
                    else
                    {
                        AddType(type.text);
                    }
				}
			}

			token = input.Get();
			if (token.type != Type.END_STATEMENT)
			{
				Error(token.posn, "Unterminated object definition statement (expected ; )");
				StripStatement(input, token);
			}
		}

		void ParseInclude(Tokenise input)
		{
			auto token = input.Get();
            string fileName = "";

			if ((token.type != Type.NAME) &&
			    (token.type != Type.TEXT))
			{
				Error(token.posn, "Illegal include file : " ~ token.text);
			}
			else
			{
				fileName = token.text;
			}

			token = input.Get();
			if (token.type != Type.END_STATEMENT)
			{
				Error(token.posn, "Unterminated include statement (expected ; )");
				StripStatement(input, token);
			}
            else if (fileName == "")
            {
				Error(token.posn, "Undefined include file");
            }
            else
            {
				input.Push(fileName);
            }
		}

		void ParseAsign(Token name, Tokenise input)
		{
			auto token = input.Get();
			if (token.type == Type.OPEN_BRACE)
			{
				ParseList(name, input);
				return;
			}
			else if ((token.type != Type.NAME)  &&
			    (token.type != Type.VALUE) &&
			    (token.type != Type.TEXT))
			{
				Error(token.posn, "Missing asignment value (expected <name> | <value> | <text> )");
			}
			else if (token.type == Type.VALUE)
			{
				AsignValue(name, token.text);
			}
			else
			{
				AsignText(name, token.text);
			}

			token = input.Get();
			if (token.type != Type.END_STATEMENT)
			{
				Error(token.posn, "Unterminated asignment statement (expected ; )");
				StripStatement(input, token);
			}
		}

		void ParseList(Token name, Tokenise input)
		{
			auto token = input.Get();

			IDataBlock[] list;

			if (token.type == Type.VALUE)
			{
				// Value list
				while (token.type == Type.VALUE)
				{
					list ~= new ValueObj(token);
					token = input.Get();
				}

				if (token.type != Type.CLOSE_BRACE)
				{
					Error(token.posn, "Unterminated list : [" ~ token.text ~ "] (expected } )");
					StripStatement(input, token);
				}
				else
				{
					token = input.Get();
					if (token.type != Type.END_STATEMENT)
					{
						Error(token.posn, "Unterminated list statement (expected ; )");
						StripStatement(input, token);
					}
					else
					{
						AddList(name.text, list);
					}
				}
			}
			else if ((token.type == Type.NAME) ||
			         (token.type == Type.TEXT))
			{
				// Text list
				while ((token.type == Type.NAME) ||
			           (token.type == Type.TEXT))
				{
					list ~= new TextObj(token);
					token = input.Get();
				}

				if (token.type != Type.CLOSE_BRACE)
				{
					Error(token.posn, "Unterminated list : [" ~ token.text ~ "] (expected } )");
					StripStatement(input, token);
				}
				else
				{
					token = input.Get();
					if (token.type != Type.END_STATEMENT)
					{
						Error(token.posn, "Unterminated list statement (expected ; )");
						StripStatement(input, token);
					}
					else
					{
						AddList(name.text, list);
					}
				}
			}
			else
			{
				Error(token.posn, "Invalid list item : [" ~ token.text ~ "]");
				StripStatement(input, token);
			}

		}

		void ParseObject(Token classDefn, Token name, Tokenise input)
		{
			auto token = input.Get();

			if (token.type != Type.OPEN_BRACE)
			{
				Error(classDefn.posn, "Illegal " ~ classDefn.text ~ " definition");
			}
			else
			{
				auto obj = new DataObject(this, this, classDefn, name);

				if (!IsValid("proto", classDefn.text))
				{
                    obj.Parse(input);
					Error(classDefn.posn, "Object " ~ classDefn.text ~ " not permitted in " ~ "proto");
				}
				else 
                {
                    if (m_types[obj.TrueClass()])
                    {
                        m_typeList[obj.Name()] = obj;
                    }
                    
                    obj.Parse(input);
                    
                    if (obj.HasError)
                    {
                        Error(classDefn.posn, "Illegal " ~ classDefn.text ~ " definition");
                    }
                    else 
                    {
                        auto p = obj.Class() in m_list;

                        if (p is null)
                        {
                            IDataBlock[] list;
                            m_list[obj.Class()] = list;
                        }

                        m_list[obj.Class()] ~= obj;
                    }
                }
			}
		}

		void AddDefinition(string parent, string child)
		{
			m_defns ~= Defn(parent, child);
            m_types.require(child, false);  // By default it is not a type   
		}

		void AddType(string type)
		{
			m_types[type] = true;
		}

		bool IsValid(string parent, string child)
		{
			return canFind(m_defns, Defn(parent, child));
		}

		void AsignValue(Token name, string value)
		{
			m_valueBlocks[FormatName(name.text, "UPPER1")] = value;
		}

		void AsignText(Token name, string value)
		{
			m_textBlocks[FormatName(name.text, "UPPER1")] = value;
		}

		void AddList(string name, IDataBlock[] list)
		{
			m_list[FormatName(name, "UPPER1")] = list;
		}

		struct Defn
		{
			string parent;
			string child;
		}

		Defn[] m_defns;
		bool[string] m_types;
		
		string[string]       m_textBlocks;
		string[string]       m_valueBlocks;
		IDataBlock[][string] m_list;
		
		string m_posn;
		bool   m_error;
	}

	void StripStatement(Tokenise input, Token token)
	{
		while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
		{
			token = input.Get();
		}
	}

	class DataObject : ProtoData
	{
		this(ProtoBlock root, ProtoData owner, Token className, Token name)
		{
			m_root  = root;
			m_owner = owner;
			m_posn  = name.posn;
			m_class = className.text;
            m_name  = name.text;

			m_textBlocks["NAME"] = name.text;
		}

		bool HasError()
		{
			return m_error;
		}

		// A string to identify this type of data object
		override string Class()
		{
			return FormatName(m_class, "UPPER1");
		}
        
        string Name()
        {
            return m_name;
        }

		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}

		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
            if (item == "TYPE")
            {
				return m_typeObj;
            }
            else if (item == "OWNER")
			{
				return m_owner;
			}
			else
            {
				return null;
			}
		}

		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			if (item == "FIELD")
			{
				return tuple(true, DList!IDataBlock(m_fields));
			}
			else if (item == "BLOCK")
			{
				return tuple(true, DList!IDataBlock(m_blocks));
			}
			else if (item == "HEADING")
			{
				return tuple(true, DList!IDataBlock(m_headings));
			}
			else if (item == "ROW")
			{
				return tuple(true, DList!IDataBlock(m_rows));
			}
			else
			{
                auto p = item in m_list;
                
                
                if (p is null)
                {
                    return tuple(false, DList!IDataBlock());
                }
                else if (!leaf)
                {
                    return tuple(true, DList!IDataBlock(*p));
                }
                else
                {
                    Appender!(IDataBlock[]) leafList;
                        
                    foreach (entry ; *p)
                    {
                        auto p2 = entry.List(false, item);
                        if (p2[0])
                        {
                            foreach (entry2 ; entry.List(true, item)[1])
                            {
                                // This is a leaf entry
                                leafList ~= entry2;
                            }
                        }
                        else
                        {
                            leafList ~= entry;
                        }
                    }
                        
                    return tuple(true, DList!IDataBlock(leafList[]));
                }
			}
		}

		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			if (name == "FIELDS")
			{
				output.Write(FormatValue(cast(long)m_fields.length, subtype));
				return true;
			}
			else if (name == "BLOCKS")
			{
				output.Write(FormatValue(cast(long)m_blocks.length, subtype));
				return true;
			}
			else if (name == "HEADINGS")
			{
				output.Write(FormatValue(cast(long)m_headings.length, subtype));
				return true;
			}
			else if (name == "ROWS")
			{
				output.Write(FormatValue(cast(long)m_rows.length, subtype));
				return true;
			}
			else if (name[$-1] == 'S')
			{
				auto p = name[0..$-1] in m_list;
				if (p !is null)
				{
					output.Write(FormatValue(cast(long)(*p).length, subtype));
					return true;
				}
			}
			else
			{
				// Drop through
			}

			auto p = name in m_textBlocks;

			if (p is null)
			{
				p = name in m_valueBlocks;
				if (p is null)
				{
					return false;
				}
				else
				{
					string value = *p;
					output.Write(FormatValue(Evaluate(value), subtype));
					return true;
				}
			}
			else
			{
				string value = *p;
				output.Write(FormatName(value, subtype));
				return true;
			}
		}

		override void Dump(BaseOutput file)
		{
		}

		void Error(string posn, string message)
		{
			writeln(posn, message);
			m_error = true;
		}

		void Parse(Tokenise input)
		{
			auto token = input.Get();
			while (token.type != Type.EOF)
			{
				if (token.type == Type.CLOSE_BRACE)
				{
					return;
				}
				else if (token.type == Type.OPTIONAL)
				{
					auto name = input.Get();
					if (name.type != Type.NAME)
					{
						Error(token.posn, "Missing field type : [" ~ token.text ~ "]");
						StripStatement(input, token);
					}
					else
					{
						ParseField(name, input, true);
					}
				}
				else if (token.type == Type.NAME)
				{
					auto name = token;
					token = input.Get();

					if (token.type == Type.ASIGN)
					{
						ParseAsign(name, input);
					}
					else if (token.type == Type.OPEN_SQR)
					{
                        input.Put(token);
						ParseField(name, input, false);
					}
					else if (token.type == Type.NAME)
					{
						ParseObject(name, token, input);
					}
					else
					{
						Error(token.posn, "Unexpected token : [" ~ token.text ~ "]"~token.type.to!string);
						StripStatement(input, token);
					}
				}
                else if (token.type == Type.OPEN_BRACE)
                {
                    if (m_headingNames is null)
                    {
                        ParseHeading(token, input);
                    }
                    else
                    {
                        auto row = new Row(token, this, m_headingNames, input);
                        
                        if (row.HasError())
                        {
                            Error(token.posn, "Illegal row");
                        }
                        else
                        {
                            m_rows ~= row;
                        }
                    }
                }
				else
			    {
					Error(token.posn, "Unexpected token : [" ~ token.text ~ "]");
					StripStatement(input, token);
			    }

			    token = input.Get();
			}
		}

		void ParseAsign(Token name, Tokenise input)
		{
			auto token = input.Get();
            
            if (name.text == "TYPE")
            {
                // Parse type value
                if (token.type != Type.NAME)
                {
                    Error(token.posn, "Missing type name (expected <name>)");
                }
                else
                {
                    auto typeObj = GetType(token.text);
                    if (typeObj is null)
                    {
                        Error(m_posn, "Undefined type : " ~ token.text);
                    }
                    else
                    {
                        string typeName = token.text;
                            
                        token = input.Get();
                        if (token.type == Type.END_STATEMENT)
                        {
                            input.Put(token);
                            m_typeObj = typeObj;
                        }
                        else if (token.type == Type.OPEN_SQR)
                        {
                            typeName ~= "[";
                        
                            token = input.Get();
                            if (token.type == Type.VALUE)
                            {
                                typeName ~= token.text;
                                m_typeObj = new FixedArray(name, typeObj, token.text);
                                token = input.Get();
                            }
                            else
                            {
                                m_typeObj = new VarArray(name, typeObj);
                            }
                            
                            if (token.type != Type.CLOSE_SQR)
                            {
                                Error(token.posn, "Unclosed array definition : " ~ token.text);
                                StripStatement(input, token);
                            }
                        }
                        else
                        {
                            Error(token.posn, "Unexpected token : " ~ token.text);
                        }
                        AsignText(name, typeName);
                    }
                }
            }
			else if (token.type == Type.OPEN_BRACE)
			{
				ParseList(name, input);
				return;
			}
			else if ((token.type != Type.NAME)  &&
			    (token.type != Type.VALUE) &&
			    (token.type != Type.TEXT))
			{
				Error(token.posn, "Missing asignment value (expected <name> | <value> | <text> )");
			}
			else if (token.type == Type.VALUE)
			{
				AsignValue(name, token.text);
			}
			else
			{
				AsignText(name, token.text);
			}

			token = input.Get();
			if (token.type != Type.END_STATEMENT)
			{
				Error(token.posn, "Unterminated asignment statement (expected ; )");
				StripStatement(input, token);
			}
		}

		void AsignValue(Token name, string value)
		{
			m_valueBlocks[FormatName(name.text, "UPPER1")] = value;
			m_blocks ~= new ValueObj(name, value);
		}

		void AsignText(Token name, string value)
		{
			m_textBlocks[FormatName(name.text, "UPPER1")] = value;
			m_blocks ~= new TextObj(name, value);
		}

		void AddList(string name, IDataBlock[] list)
		{
			m_list[FormatName(name, "UPPER1")] = list;
		}

		void ParseList(Token name, Tokenise input)
		{
			auto token = input.Get();

			IDataBlock[] list;

			if (token.type == Type.VALUE)
			{
				// Value list
				while (token.type == Type.VALUE)
				{
					list ~= new ValueObj(token);
					token = input.Get();
				}

				if (token.type != Type.CLOSE_BRACE)
				{
					Error(token.posn, "Unterminated list : [" ~ token.text ~ "] (expected } )");
					StripStatement(input, token);
				}
				else
				{
					token = input.Get();
					if (token.type != Type.END_STATEMENT)
					{
						Error(token.posn, "Unterminated list statement (expected ; )");
						StripStatement(input, token);
					}
					else
					{
						AddList(name.text, list);
					}
				}
			}
			else if ((token.type == Type.NAME) ||
			         (token.type == Type.TEXT))
			{
				// Text list
				while ((token.type == Type.NAME) ||
			           (token.type == Type.TEXT))
				{
					list ~= new TextObj(token);
					token = input.Get();
				}

				if (token.type != Type.CLOSE_BRACE)
				{
					Error(token.posn, "Unterminated list : [" ~ token.text ~ "] (expected } )");
					StripStatement(input, token);
				}
				else
				{
					token = input.Get();
					if (token.type != Type.END_STATEMENT)
					{
						Error(token.posn, "Unterminated list statement (expected ; )");
						StripStatement(input, token);
					}
					else
					{
						AddList(name.text, list);
					}
				}
			}
			else
			{
				Error(token.posn, "Invalid list item : [" ~ token.text ~ "]");
				StripStatement(input, token);
			}

		}

		void ParseObject(Token classDefn, Token name, Tokenise input)
		{
			auto token = input.Get();

			if ((token.type == Type.ASIGN) || 
                (token.type == Type.END_STATEMENT) ||
                (token.type == Type.NAME) ||
			    (token.type == Type.TEXT))
			{
                // Field definition
                
                IDataBlock typeObj = null;
                if ((classDefn.text != "-") &&
                    (classDefn.text != "_"))
                {
                    typeObj = GetType(classDefn.text);
                    if (typeObj is null)
                    {
                        Error(m_posn, "Undefined type : " ~ classDefn.text);
                    }
                }
            
				input.Put(token);
				ParseField2(classDefn.text, typeObj, name, input, false);
			}
			else if (token.type != Type.OPEN_BRACE)
			{
				Error(classDefn.posn, "Illegal " ~ classDefn.text ~ " definition");
			}
			else
			{
				auto obj = new DataObject(m_root, this, classDefn, name);

				if (!m_root.IsValid(m_class, classDefn.text))
				{
                    obj.Parse(input);
					Error(classDefn.posn, "Object " ~ classDefn.text ~ " not permitted in " ~ m_class);
				}
				else
                {
                    if (m_root.m_types[obj.TrueClass()])
                    {
                        m_typeList[obj.Name()] = obj;
                    }
                    
                    obj.Parse(input);
                    
                    if (obj.HasError)
                    {
                        Error(classDefn.posn, "Illegal " ~ classDefn.text ~ " definition");
                    }
                    else 
                    {
                        auto p = obj.Class() in m_list;

                        if (p is null)
                        {
                            IDataBlock[] list;
                            m_list[obj.Class()] = list;
                        }

                        m_list[obj.Class()] ~= obj;                        
                    }
                }
			}
		}

		void ParseField(Token type, Tokenise input, bool optional)
		{
			auto token = input.Get();
            
            IDataBlock typeObj = null;
            if ((type.text != "-") &&
                (type.text != "_"))
            {
                typeObj = GetType(type.text);
                if (typeObj is null)
                {
                    Error(m_posn, "Undefined type : " ~ type.text);
                }
            }

			if (token.type == Type.NAME)
			{
                ParseField2(type.text, typeObj, token, input, optional);
            }
			else if (token.type == Type.OPEN_SQR)
			{
                string typeName = type.text ~ "[";
            
                token = input.Get();
                if (token.type == Type.VALUE)
                {
                    typeName ~= token.text;
                    typeObj = new FixedArray(type, typeObj, token.text);
                    token = input.Get();
                }
                else
                {
                    typeObj = new VarArray(type, typeObj);
                }
                
                if (token.type != Type.CLOSE_SQR)
                {
                    Error(token.posn, "Unclosed array definition : " ~ token.text);
                    StripStatement(input, token);
                }
                else
                {
                    typeName ~= "]";
                    Token name = input.Get();
                    if (name.type == Type.NAME)
                    {
                        ParseField2(typeName, typeObj, name, input, optional);
                    }
                    else
                    {
                        Error(token.posn, "Missing field name : " ~ name.text);
                        StripStatement(input, name);
                    }
                }
            }
            else
            {
				Error(token.posn, "Unexpected token : " ~ token.text);
            }
        }

		void ParseField2(string type, IDataBlock typeObj, Token name, Tokenise input, bool optional)
		{
			auto token = input.Get();

			if (token.type == Type.ASIGN)
			{
				auto value = input.Get();
				if (value.type != Type.VALUE)
				{
					Error(token.posn, "Illegal field value [" ~ value.text ~ "] (expected <value> )");
				}
				else
				{
					token = input.Get();
					if ((token.type == Type.NAME) ||
						(token.type == Type.TEXT))
					{
						AddField(type, typeObj, name, value.text, token.text, optional);
					}
					else
					{
						input.Put(token);
						AddField(type, typeObj, name, value.text, "", optional);
					}
				}
			}
			else if (token.type == Type.END_STATEMENT)
			{
				input.Put(token);
				AddField(type.text, typeObj, name, "", "", optional);
			}
			else if ((token.type == Type.NAME) ||
			         (token.type == Type.TEXT))
			{
				AddField(type, typeObj, name, "", token.text, optional);
			}
			else
			{
			}

			token = input.Get();
			if (token.type != Type.END_STATEMENT)
			{
				Error(token.posn, "Unterminated field statement (expected ; )");
				StripStatement(input, token);
			}
		}

		void AddField(string type, IDataBlock typeObj, Token name, string value, string text, bool optional)
		{
			m_fields ~= new Field(type, typeObj, name, this, value, text, optional);
		}

        void ParseHeading(Token token, Tokenise input)
        {
            while (token.type != Type.CLOSE_BRACE)
            {
                token = input.Get();
            
                if ((token.type == Type.NAME) ||
                    (token.type == Type.TEXT))
                {
                    m_headingNames ~= token.text;
                    m_headings ~= new TextObj(token);
                }
                else
                {
					Error(token.posn, "Unexpected heading : [" ~ token.text ~ "]");
                    while (token.type != Type.CLOSE_BRACE)
                    {
                        token = input.Get();
                    }
                    return;
                }
                
                token = input.Get();
                if ((token.type != Type.SEP) &&
                    (token.type != Type.CLOSE_BRACE))
                {
					Error(token.posn, "Unexpected heading : [" ~ token.text ~ "]");
                    while (token.type != Type.CLOSE_BRACE)
                    {
                        token = input.Get();
                    }
                    return;
                }
            }
        }
        
		string[string]       m_textBlocks;
		string[string]       m_valueBlocks;
		IDataBlock[][string] m_list;
		IDataBlock[]         m_fields;
		IDataBlock[]         m_blocks;
		IDataBlock[]         m_headings;
		IDataBlock[]         m_rows;
        string[]             m_headingNames;
		IDataBlock           m_typeObj;

		ProtoBlock  m_root;

		string m_posn;
        string m_name;
		bool   m_error;
	}

	class Field : IDataBlock
	{
		this(string type, IDataBlock typeObj, Token name, DataObject owner, string value, string text, bool optional)
		{
			m_posn = name.posn;
			m_type = type;
            m_typeObj = typeObj;
			m_name = name.text;
            m_owner = owner;
			m_value = value;
			m_text = text;
			m_optional = optional;
		}

		bool HasError()
		{
			return false;
		}

		// A string to identify this type of data object
		override string Class()
		{
			return "FIELD";
		}

		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}

		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
            if (item == "TYPE")
            {
                return m_typeObj;
            }
            else
            {
                return null;
            }
		}

		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			return tuple(false, DList!IDataBlock());
		}

		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			if (name == "TYPE")
			{
				output.Write(FormatName(m_type, subtype));
				return true;
			}
			else if (name == "NAME")
			{
				output.Write(FormatName(m_name, subtype));
				return true;
			}
			else if (name == "VALUE")
			{
				output.Write(FormatValue(Evaluate(m_value), subtype));
				return true;
			}
			else if (name == "TEXT")
			{
				output.Write(FormatName(m_text, subtype));
				return true;
			}
			else if (name == "OPTIONAL")
			{
				output.Write(FormatName((m_optional?"TRUE":"FALSE"), subtype));
				return true;
			}

			return false;
		}

		override void Dump(BaseOutput file)
		{
		}

		void Error(string posn, string message)
		{
			writeln(posn, message);
		}

		string     m_posn;
		string     m_type;
		string     m_name;
        DataObject m_owner;
		string     m_value;
		string     m_text;
        IDataBlock m_typeObj;
		bool       m_optional;
	}

	class VarArray : IDataBlock
	{
		this(Token type, IDataBlock typeObj)
		{
            m_posn = type.posn;
			m_typeObj = typeObj;
		}

		bool HasError()
		{
			return false;
		}

		// A string to identify this type of data object
		override string Class()
		{
			return "VAR_ARRAY";
		}

		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}

		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
            if (item == "TYPE")
            {
                return m_typeObj;
            }
			return null;
		}

		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			return tuple(false, DList!IDataBlock());
		}

		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			return false;
		}

		override void Dump(BaseOutput file)
		{
		}

		void Error(string posn, string message)
		{
			writeln(posn, message);
		}

		string m_posn;
		IDataBlock m_typeObj;
	}

	class FixedArray : IDataBlock
	{
		this(Token type, IDataBlock typeObj, string size)
		{
            m_posn = type.posn;
			m_typeObj = typeObj;;
			m_size = size;
		}

		bool HasError()
		{
			return false;
		}

		// A string to identify this type of data object
		override string Class()
		{
			return "FIXED_ARRAY";
		}

		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}

		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
            if (item == "TYPE")
            {
                return m_typeObj;
            }
			return null;
		}

		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			return tuple(false, DList!IDataBlock());
		}

		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
            if (name == "SIZE")
            {
				output.Write(FormatValue(Evaluate(m_size), subtype));
				return true;
            }
            
			return false;
		}

		override void Dump(BaseOutput file)
		{
		}

		void Error(string posn, string message)
		{
			writeln(posn, message);
		}

		string m_posn;
		string m_size;
		IDataBlock m_typeObj;
	}


	class TextObj : IDataBlock
	{
		this(Token text)
		{
			m_posn = text.posn;
			m_name = "";
			m_text = text.text;
		}

		this(Token name, string text)
		{
			m_posn = name.posn;
			m_name = name.text;
			m_text = text;
		}

		bool HasError()
		{
			return false;
		}

		// A string to identify this type of data object
		override string Class()
		{
			return "TEXT";
		}

		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}

		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
			return null;
		}

		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			return tuple(false, DList!IDataBlock());
		}

		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			if (name == "NAME")
			{
				output.Write(FormatName(m_name, subtype));
				return true;
			}

			if (name == "TEXT")
			{
				output.Write(FormatName(m_text, subtype));
				return true;
			}

			return false;
		}

		override void Dump(BaseOutput file)
		{
		}

		void Error(string posn, string message)
		{
			writeln(posn, message);
		}

		string m_posn;
		string m_name;
		string m_text;
	}

	class ValueObj : IDataBlock
	{
		this(Token text)
		{
			m_posn = text.posn;
			m_name = "";
			m_text = text.text;
		}

		this(Token name, string text)
		{
			m_posn = name.posn;
			m_name = name.text;
			m_text = text;
		}

		bool HasError()
		{
			return false;
		}

		// A string to identify this type of data object
		override string Class()
		{
			return "VALUE";
		}

		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}

		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
			return null;
		}

		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			return tuple(false, DList!IDataBlock());
		}

		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			if (name == "NAME")
			{
				output.Write(FormatName(m_name, subtype));
				return true;
			}

			if (name == "TEXT")
			{
				output.Write(FormatName(m_text, subtype));
				return true;
			}

			if (name == "VALUE")
			{
				output.Write(FormatValue(Evaluate(m_text), subtype));
				return true;
			}

			return false;
		}

		override void Dump(BaseOutput file)
		{
		}

		void Error(string posn, string message)
		{
			writeln(posn, message);
		}

		string m_posn;
		string m_name;
		string m_text;
	}
	
	class Row : ProtoData
	{
		this(Token token, ProtoData owner, string[] headings, Tokenise input)
		{
			m_posn  = token.posn;
            m_owner = owner;
            m_error = false;
            Parse(token, headings, input);
		}

		bool HasError()
		{
			return m_error;
		}

		// A string to identify this type of data object
		override string Class()
		{
			return "ROW";
		}

		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}

		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
            if (item == "TYPE")
            {
                return m_typeObj;
            }
			return null;
		}

		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
            if (item == "ENTRY")
            {
                return tuple(false, DList!IDataBlock(m_entries));
            }
			return tuple(false, DList!IDataBlock());
		}

		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
            if (name == "ENTRIES")
            {
                output.Write(FormatValue(m_entries.length, subtype));
                return true;
            }
            else
            {
                auto p = name in m_textBlocks;

                if (p is null)
                {
                    p = name in m_valueBlocks;
                    if (p is null)
                    {
                        return false;
                    }
                    else
                    {
                        string value = *p;
                        output.Write(FormatValue(Evaluate(value), subtype));
                        return true;
                    }
                }
                else
                {
                    string value = *p;
                    output.Write(FormatName(value, subtype));
                    return true;
                }
            }
		}

		override void Dump(BaseOutput file)
		{
		}

		void Error(string posn, string message)
		{
			writeln(posn, message);
            m_error = true;
		}
        
        void Parse(Token token, string[] headings, Tokenise input)
        {
            int idx = 0;
            while (token.type != Type.CLOSE_BRACE)
            {
                token = input.Get();
            
                if (idx >= headings.length)
                {
					Error(token.posn, "To many row entries");
                }
                else if (FormatName(headings[idx], "UPPER1") == "TYPE")
                {
                    ProtoData typeObj; 
                    if (token.type != Type.NAME)
                    {
                        Error(token.posn, "Illegal type name : [" ~ token.text ~ "]");
                        while (token.type != Type.CLOSE_BRACE)
                        {
                            token = input.Get();
                        }
                        return;
                    }
                    else if ((typeObj = GetType(token.text)) is null)
                    {
                        Error(token.posn, "Undefined type : [" ~ token.text ~ "]");
                        while (token.type != Type.CLOSE_BRACE)
                        {
                            token = input.Get();
                        }
                        return;
                    }
                    else
                    {
                        string typeName = token.text;
                        
                        token = input.Get();
                        
                        if ((token.type == Type.SEP)||
                            (token.type == Type.CLOSE_BRACE))
                        {
                            input.Put(token);
                            m_typeObj = typeObj;
                        }
                        else if (token.type == Type.OPEN_SQR)
                        {
                            typeName ~= "[";
                        
                            token = input.Get();
                            if (token.type == Type.VALUE)
                            {
                                typeName ~= token.text;
                                m_typeObj = new FixedArray(token, typeObj, token.text);
                                token = input.Get();
                            }
                            else
                            {
                                m_typeObj = new VarArray(token, typeObj);
                            }
                            
                            if (token.type != Type.CLOSE_SQR)
                            {
                                Error(token.posn, "Unclosed array definition : " ~ token.text);
                                input.Put(token);
                            }
                            else
                            {
                                typeName ~= "]";
                            }
                        }
                        else
                        {
                            Error(token.posn, "Unexpected token : " ~ token.text);
                        }
                        
                        m_textBlocks[FormatName(headings[idx], "UPPER1")] = typeName;
                    }
                }
                else if ((token.type == Type.NAME) ||
                         (token.type == Type.TEXT))
                {
                    m_textBlocks[FormatName(headings[idx], "UPPER1")] = token.text;
                    m_entries ~= new TextObj(token);
                }
                else if (token.type == Type.VALUE)
                {
                    m_valueBlocks[FormatName(headings[idx], "UPPER1")] = token.text;
                    m_entries ~= new ValueObj(token);
                }
                else
                {
					Error(token.posn, "Unexpected row value : [" ~ token.text ~ "]");
                    while (token.type != Type.CLOSE_BRACE)
                    {
                        token = input.Get();
                    }
                    return;
                }
                
                token = input.Get();
                if ((token.type != Type.SEP) &&
                    (token.type != Type.CLOSE_BRACE))
                {
					Error(token.posn, "Unexpected row value : [" ~ token.text ~ "]");
                    while (token.type != Type.CLOSE_BRACE)
                    {
                        token = input.Get();
                    }
                    return;
                }
                
                idx += 1;
            }
            
            if (idx < headings.length)
            {
                Error(token.posn, "Missing row entries");
            }
        }

		string m_posn;
		string[string] m_textBlocks;
		string[string] m_valueBlocks;
        IDataBlock     m_typeObj;
        IDataBlock[]   m_entries;
        bool   m_error;
	}
	
	enum Type
	{
		ASIGN,
		END_STATEMENT,
		OPEN,
		CLOSE,
		OPEN_BRACE,
		CLOSE_BRACE,
		OPEN_SQR,
		CLOSE_SQR,
		SEP,
		NAME,
		INCLUDE,
		OPTIONAL,
		OBJECT,
        TYPE,
		VALUE,
		TEXT,
		EOF
	}

	struct Token
	{
		Type type;
		string text;
		string posn;
	}

	class Tokenise
	{
		this(InputStack input)
		{
			m_error = false;
			m_input = input;
			m_token.type = Type.EOF;
			m_posn  = "<START>";
		}
		
		string Posn()
		{
			return m_posn;
		}
		
		bool HasError()
		{
			return m_error;
		}
		
		bool Push(string file)
		{
			return m_input.Push(file);
		}

		void Put(Token token)
		{
			m_token = token;
		}
		
		Token Get()
		{
			if (m_token.type != Type.EOF)
			{
				auto token = m_token;
				m_token.type = Type.EOF;
				return token;
			}

			while (!m_input.Eof())
			{
				auto ch = m_input.Get();
				m_posn  = m_input.Posn();
				
				m_text.clear();
				
				if (ch == 0)
				{
					return Token(Type.EOF, "<EOF>");
				}
				else if (isWhite(ch))
				{
					// Ignore white space
				}
				else if (ch == '/')
				{
					ParseComment(ch);
				}
				else if (ch == '%')
				{
					ParseComment(ch);
				}
				else if (ch == '"')
				{
					return ParseQuoted(ch);
				}
				else if (ch == '=')
				{
					return Token(Type.ASIGN, "=", m_input.Posn());
				}
				else if (ch == ';')
				{
					return Token(Type.END_STATEMENT, ";", m_input.Posn());
				}
				else if (ch == '[')
				{
					return Token(Type.OPEN_SQR, "[", m_input.Posn());
				}
				else if (ch == ']')
				{
					return Token(Type.CLOSE_SQR, "]", m_input.Posn());
				}
				else if (ch == '{')
				{
					return Token(Type.OPEN_BRACE, "{", m_input.Posn());
				}
				else if (ch == '}')
				{
					return Token(Type.CLOSE_BRACE, "}", m_input.Posn());
				}
				else if (ch == '(')
				{
					return Token(Type.OPEN, "(", m_input.Posn());
				}
				else if (ch == ')')
				{
					return Token(Type.CLOSE, ")", m_input.Posn());
				}
				else if (ch == ',')
				{
					return Token(Type.SEP, ",", m_input.Posn());
				}
				else if ((ch == '_') || (isAlpha(ch)))
				{
					return ParseName(ch);
				}
				else if (isNumber(ch) || (ch == '-'))
				{
					return ParseValue(ch);
				}
				else if (!isWhite(ch))
				{
					return ParseText(ch);
				}
				else
				{
					Error(m_input.Posn(), "Unexpected char : " ~ ch);
				}
			}
				
			return Token(Type.EOF, "<EOF>");
		}
		
		void ParseComment(char leadCh)
		{
			auto ch = m_input.Get();
			if (ch == leadCh)
			{
				// Comment
				while ((ch != '\0') && (ch != '\n') && (ch != '\r'))
				{
					ch = m_input.Get();
				}
			}
			else
			{
				m_input.Put(ch);
				Error(m_input.Posn(), "Unexpected char : " ~ leadCh);
			}
		}
		
		Token ParseName(char leadCh)
		{
//  <name>        ::= (<letter> | "_") { <letter> | <number> | "_" }
//  <text>        ::= { <non-whitespace> } 
			auto ch = leadCh;
			while ((ch != '\0') && ((ch == '_') || (ch == '-') || isAlphaNum(ch)))
			{
				m_text.put(ch);
				ch = m_input.Get();
			}
			
			if ((ch != '\0') &&
			    (ch != '"')  &&
			    (ch != '=')  &&
			    (ch != ';')  &&
			    (ch != '{')  &&
			    (ch != '}')  &&
			    (ch != '[')  &&
			    (ch != ']')  &&
			    (ch != '(')  &&
			    (ch != ')')  &&
			    (ch != ',')  &&
			    !isWhite(ch))
			{
				return ParseText(ch);
			}
			else
			{
				m_input.Put(ch);
				
				string text = m_text[].idup;
				Type   type;
				
				switch (text)
				{
					case "optional" : type = Type.OPTIONAL; break;
					case "include"  : type = Type.INCLUDE; break;
					case "object"   : type = Type.OBJECT; break;
					case "type"     : type = Type.TYPE; break;
					default: type = Type.NAME; break;
				}
				
				return Token(type, text, m_input.Posn());
			}
		}
		
		Token ParseText(char leadCh)
		{
//  <name>        ::= (<letter> | "_") { <letter> | <number> | "_" }
//  <text>        ::= { <non-whitespace> } 
			auto ch = leadCh;
			while ((ch != '\0') &&
			    (ch != '"')  &&
			    (ch != '=')  &&
			    (ch != ';')  &&
			    (ch != '[')  &&
			    (ch != ']')  &&
			    (ch != '{')  &&
			    (ch != '}')  &&
			    (ch != '(')  &&
			    (ch != ')')  &&
			    (ch != ',')  &&
			    !isWhite(ch))
			{
				m_text.put(ch);
				ch = m_input.Get();
			}
			
			m_input.Put(ch);
				
			return Token(Type.TEXT, m_text[].idup, m_input.Posn());
		}
		
		Token ParseValue(char leadCh)
		{
//  <value>       ::= { <number> }
			auto ch = leadCh;
			
			if (ch == '-')
			{
				m_text.put(ch);
				ch = m_input.Get();
			}
			
			while (!m_input.Eof() && isNumber(ch))
			{
				m_text.put(ch);
				ch = m_input.Get();
			}
			
			if (ch == '.')
			{
				return ParseText(ch);
			}
			else
			{
				string value = m_text[].idup;

				if (value == "-")
				{
					return ParseName(ch);
				}

				m_input.Put(ch);

				return Token(Type.VALUE, value, m_input.Posn());
			}
		}
		
		Token ParseQuoted(char leadCh)
		{
//  <quoted text> ::= "\"" { <print> } "\""
			
			if (m_input.Eof())
			{
				Error(m_input.Posn(), "Unterminated string");
				return Token(Type.TEXT, "");
			}
			
			auto ch = m_input.Get();
			while ((ch != '\0') && (ch != leadCh) && (ch != '\n') && (ch != '\r'))
			{
				if (!m_input.Eof() && (ch == '\\'))
				{
					ch = m_input.Get();
					switch (ch)
					{
						case 'n' : m_text.put('\n'); break;
						case 'r' : m_text.put('\r'); break;
						case 't' : m_text.put('\t'); break;
						default  : m_text.put(ch); break;
					}
				}
				else
				{
					m_text.put(ch);
				}
				ch = m_input.Get();
			}
			
			auto text = m_text[].idup;
			
			if (ch != leadCh)
			{
				Error(m_input.Posn(), "Unterminated string : " ~ text);
			}
			
			return Token(Type.TEXT, text, m_input.Posn());
		}
		
		void Error(string posn, string message)
		{
			writeln(posn, message);
			m_error = true; 
		}
		
		Token      m_token;
		InputStack m_input;
		string     m_posn;
		bool       m_error;
		Appender!(char[]) m_text;
	}
}

//// Tokenise //////////////////////////////////////////////
private
{
	unittest
	{
        writeln("Proto test 1");
		auto text = "";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		
		assert(token.type == Type.EOF);
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(!tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 2");
		auto text = " _fredFred;Harry ";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "_fredFred");
		
		token = tokeniser.Get();
		assert(token.type == Type.END_STATEMENT);
		assert(token.text == ";");
		
		token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "Harry");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(!tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 3");
		auto text = " _fredFred ; Harry ";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "_fredFred");
		
		token = tokeniser.Get();
		assert(token.type == Type.END_STATEMENT);
		assert(token.text == ";");
		
		token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "Harry");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(!tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 4");
		auto text = " {;},() ";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.OPEN_BRACE);
		assert(token.text == "{");
		
		token = tokeniser.Get();
		assert(token.type == Type.END_STATEMENT);
		assert(token.text == ";");
		
		token = tokeniser.Get();
		assert(token.type == Type.CLOSE_BRACE);
		assert(token.text == "}");

		token = tokeniser.Get();
		assert(token.type == Type.SEP);
		assert(token.text == ",");

		token = tokeniser.Get();
		assert(token.type == Type.OPEN);
		assert(token.text == "(");

		token = tokeniser.Get();
		assert(token.type == Type.CLOSE);
		assert(token.text == ")");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(!tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 5");
		auto text = " fred optional include object ";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "fred");
		
		token = tokeniser.Get();
		assert(token.type == Type.OPTIONAL);
		assert(token.text == "optional");
		
		token = tokeniser.Get();
		assert(token.type == Type.INCLUDE);
		assert(token.text == "include");
		
		token = tokeniser.Get();
		assert(token.type == Type.OBJECT);
		assert(token.text == "object");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(!tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 6");
		auto text = " fred\"harry lois\"bill ";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "fred");
		
		token = tokeniser.Get();
		assert(token.type == Type.TEXT);
		assert(token.text == "harry lois");
		
		token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "bill");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(!tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 7");
		auto text = " fred\"harry lois";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "fred");
		
		token = tokeniser.Get();
		assert(token.type == Type.TEXT);
		assert(token.text == "harry lois");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 8");
		auto text = " fred\"harry\\r\\n\\\\ \\\"lois\" bill";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "fred");
		
		token = tokeniser.Get();
		assert(token.type == Type.TEXT);
		assert(token.text == "harry\r\n\\ \"lois");
		
		token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "bill");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(!tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 9");
		auto text = " fred\"harry lois\n bill";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "fred");
		
		token = tokeniser.Get();
		assert(token.type == Type.TEXT);
		assert(token.text == "harry lois");
		
		token = tokeniser.Get();
		writeln("XXX : ", token.type, " : ", token.text);
		assert(token.type == Type.NAME);
		assert(token.text == "bill");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(tokeniser.HasError());
	}
	
	unittest
	{
        writeln("Proto test 10");
		auto text = " fred\"harry lois\r bill";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "fred");
		
		token = tokeniser.Get();
		assert(token.type == Type.TEXT);
		assert(token.text == "harry lois");
		
		token = tokeniser.Get();
		assert(token.type == Type.NAME);
		assert(token.text == "bill");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(tokeniser.HasError());
	}
    
	unittest
	{
        writeln("Proto test 11");
		auto text = "object(proto, fred); object (fred,fred); fred bill {fred bill {}}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FRED")[1].front.Class() == "FRED");
    }
    
	unittest
	{
        writeln("Proto test 12");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {bill lois;}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE").Class() == "FRED");
    }
    
	unittest
	{
        writeln("Proto test 13");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {bill lois = 1;}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE").Class() == "FRED");
    }
    
	unittest
	{
        writeln("Proto test 14");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {bill lois \"hello\";}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE").Class() == "FRED");
    }
    
	unittest
	{
        writeln("Proto test 15");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {bill lois = 1 \"hello\";}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE").Class() == "FRED");
    }
    
	unittest
	{
        writeln("Proto test 16");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {bill[] lois;}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE").Class() == "VAR_ARRAY");
    }
    
	unittest
	{
        writeln("Proto test 17");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {bill[3] lois = 1;}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE").Class() == "FIXED_ARRAY");
    }
    
	unittest
	{
        writeln("Proto test 18");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {bill[] lois \"hello\";}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE").Class() == "VAR_ARRAY");
    }
    
	unittest
	{
        writeln("Proto test 19");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {bill[3] lois = 1 \"hello\";}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE").Class() == "FIXED_ARRAY");
    }
    
	unittest
	{
        writeln("Proto test 20");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {- lois = 1 \"hello\";}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") is null);
    }
    
	unittest
	{
        writeln("Proto test 21");
		auto text = "object(proto, fred); object (fred,fred); type (fred); fred bill {_ lois = 1 \"hello\";}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "FIELD")[1].front.Using("TYPE") is null);
    }
    
	unittest
	{
        writeln("Proto test 22");
		auto text = "object(proto, fred); type (fred); fred bill {TYPE = bill;}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.Using("TYPE").Class() == "FRED");
    }
    
	unittest
	{
        writeln("Proto test 23");
		auto text = "object(proto, fred); type (fred); fred bill { TYPE = bill[];}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.Using("TYPE").Class() == "VAR_ARRAY");
    }
    
	unittest
	{
        writeln("Proto test 24");
		auto text = "object(proto, fred); type (fred); fred bill { TYPE = bill[3];}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.Using("TYPE") !is null);
		assert(root.List(false, "FRED")[1].front.Using("TYPE").Class() == "FIXED_ARRAY");
    }
    
	unittest
	{
        writeln("Proto test 25");
		auto text = "object(proto, fred); type (fred); fred bill { {name, lois} {7,8}}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "HEADING")[0]);
		//assert(root.List(false, "FRED")[1].front.List(false, "HEADING")[1].length == 2);
		assert(root.List(false, "FRED")[1].front.List(false, "ROW")[0]);
		//assert(root.List(false, "FRED")[1].front.List(false, "ROW")[1].length == 1);
		assert(root.List(false, "FRED")[1].front.List(false, "ROW")[1].front.Using("TYPE") is null);
    }
    
	unittest
	{
        writeln("Proto test 26");
		auto text = "object(proto, fred); type (fred); fred bill { {name, \"type\"} {1,bill} {2,bill[]} {3,bill[3]}}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(!root.HasError());
		assert(root.List(false, "FRED")[0]);
		assert(root.List(false, "FRED")[1].front.List(false, "HEADING")[0]);
		//assert(root.List(false, "FRED")[1].front.List(false, "HEADING")[1].length == 2);
		assert(root.List(false, "FRED")[1].front.List(false, "ROW")[0]);
		//assert(root.List(false, "FRED")[1].front.List(false, "ROW")[1].length == 1);
		assert(root.List(false, "FRED")[1].front.List(false, "ROW")[1].front.Using("TYPE") !is null);
    }
    
	unittest
	{
        writeln("Proto test 25");
		auto text = "object(proto, fred); type (fred); fred bill { {name, value} {lois}}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(root.HasError());
    }
    
	unittest
	{
        writeln("Proto test 26");
		auto text = "object(proto, fred); type (fred); fred bill { {name, value} {lois, janet, mum}}";
		auto root = new ProtoBlock(new Tokenise(new InputStack(new LitteralInput(text))));
        
		assert(root.HasError());
    }
}

