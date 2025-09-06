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
	final class ProtoBlock : IDataBlock
	{
		this(Tokenise input)
		{
			m_error = false;
			m_posn  = input.Posn();
			Parse(input);
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
				// Find the leaf nodes
				Appender!(IDataBlock[]) leafList;
				
				foreach (entry ; *p)
				{
					auto list = entry.List(leaf, item);
					if (!list[0])
					{
						// This is a leaf entry
						leafList ~= entry;
					}
					else
					{
						bool isLeafy = true;
						foreach (leafy ; list[1])
						{
							// Add the leaf entries in this nodes
							isLeafy = false;
							leafList ~= leafy;
						}
						
						if (isLeafy)
						{
							// This is a leaf node
							leafList ~= entry;
						}
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

		void ParseInclude(Tokenise input)
		{
			auto token = input.Get();

			if ((token.type != Type.NAME) &&
			    (token.type != Type.TEXT))
			{
				Error(token.posn, "Illegal include file : " ~ token.text);
			}
			else
			{
				input.Push(token.text);
			}

			token = input.Get();
			if (token.type != Type.END_STATEMENT)
			{
				Error(token.posn, "Unterminated include statement (expected ; )");
				StripStatement(input, token);
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
				AsignValue(name.text, token.text);
			}
			else
			{
				AsignText(name.text, token.text);
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
					list ~= new ValueObj(token.text);
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
					list ~= new TextObj(token.text);
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
				auto obj = new DataObject(this, this, input, classDefn, name);

				if (obj.HasError)
				{
					Error(classDefn.posn, "Illegal " ~ classDefn.text ~ " definition");
				}
				else if (!IsValid("proto", classDefn.text))
				{
					Error(classDefn.posn, "Object " ~ classDefn.text ~ " not permitted in " ~ "proto");
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

		void AddDefinition(string parent, string child)
		{
			m_defns ~= Defn(parent, child);
		}

		bool IsValid(string parent, string child)
		{
			return canFind(m_defns, Defn(parent, child));
		}

		void AsignValue(string name, string value)
		{
			m_valueBlocks[FormatName(name, "UPPER1")] = value;
		}

		void AsignText(string name, string value)
		{
			m_textBlocks[FormatName(name, "UPPER1")] = value;
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

	class DataObject : IDataBlock
	{
		this(ProtoBlock root, IDataBlock owner, Tokenise input, Token className, Token name)
		{
			m_root  = root;
			m_owner = owner;
			m_posn  = name.posn;
			m_class = className.text;

			m_textBlocks["NAME"] = name.text;

			Parse(input);
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

		// Position of this in the input file
		override string Posn()
		{
			return m_posn;
		}

		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
			if (item == "OWNER")
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
			else
			{
				auto p = item in m_list;

				if (p is null)
				{
					return tuple(false, DList!IDataBlock());   // Allow missing lists
				}
				else if (!leaf)
				{
					return tuple(true, DList!IDataBlock(*p));
				}
				else
				{
					// Find the leaf nodes
					Appender!(IDataBlock[]) leafList;
					
					foreach (entry ; *p)
					{
						auto list = entry.List(leaf, item);
						if (!list[0])
						{
							// This is a leaf entry
							leafList ~= entry;
						}
						else
						{
							bool isLeafy = true;
							foreach (leafy ; list[1])
							{
								// Add the leaf entries in this nodes
								isLeafy = false;
								leafList ~= leafy;
							}
							
							if (isLeafy)
							{
								// This is a leaf node
								leafList ~= entry;
							}
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
						token = input.Get();
						if (token.type != Type.NAME)
						{
							Error(token.posn, "Missing field name : [" ~ token.text ~ "]");
							StripStatement(input, token);
						}
						else
						{
							ParseField(name, token, input, true);
						}
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
					else if (token.type == Type.NAME)
					{
						ParseObject(name, token, input);
					}
					else
					{
						Error(token.posn, "Unexpected token : [" ~ token.text ~ "]");
						StripStatement(input, token);
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
				AsignValue(name.text, token.text);
			}
			else
			{
				AsignText(name.text, token.text);
			}

			token = input.Get();
			if (token.type != Type.END_STATEMENT)
			{
				Error(token.posn, "Unterminated asignment statement (expected ; )");
				StripStatement(input, token);
			}
		}

		void AsignValue(string name, string value)
		{
			m_valueBlocks[FormatName(name, "UPPER1")] = value;
			m_blocks ~= new ValueObj(name, value);
		}

		void AsignText(string name, string value)
		{
			m_textBlocks[FormatName(name, "UPPER1")] = value;
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
					list ~= new ValueObj(token.text);
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
					list ~= new TextObj(token.text);
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

			if (token.type == Type.ASIGN)
			{
				input.Put(token);
				ParseField(classDefn, name, input, false);
			}
			else if (token.type == Type.END_STATEMENT)
			{
				input.Put(token);
				ParseField(classDefn, name, input, false);
			}
			else if ((token.type == Type.NAME) ||
			         (token.type == Type.TEXT))
			{
				input.Put(token);
				ParseField(classDefn, name, input, false);
			}
			else if (token.type != Type.OPEN_BRACE)
			{
				Error(classDefn.posn, "Illegal " ~ classDefn.text ~ " definition");
			}
			else
			{
				auto obj = new DataObject(m_root, this, input, classDefn, name);

				if (obj.HasError)
				{
					Error(classDefn.posn, "Illegal " ~ classDefn.text ~ " definition");
				}
				else if (!m_root.IsValid(m_class, classDefn.text))
				{
					Error(classDefn.posn, "Object " ~ classDefn.text ~ " not permitted in " ~ m_class);
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

		void ParseField(Token type, Token name, Tokenise input, bool optional)
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
						AddField(type.text, name.text, value.text, token.text, optional);
					}
					else
					{
						input.Put(token);
						AddField(type.text, name.text, value.text, "", optional);
					}
				}
			}
			else if (token.type == Type.END_STATEMENT)
			{
				input.Put(token);
				AddField(type.text, name.text, "", "", optional);
			}
			else if ((token.type == Type.NAME) ||
			         (token.type == Type.TEXT))
			{
				AddField(type.text, name.text, "", token.text, optional);
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

		void AddField(string type, string name, string value, string text, bool optional)
		{
			m_fields ~= new Field(type, name, value, text, optional);
		}


		string[string]       m_textBlocks;
		string[string]       m_valueBlocks;
		IDataBlock[][string] m_list;
		IDataBlock[]         m_fields;
		IDataBlock[]         m_blocks;

		ProtoBlock m_root;
		IDataBlock m_owner;

		string m_posn;
		string m_class;
		bool   m_error;
	}

	class Field : IDataBlock
	{
		this(string type, string name, string value, string text, bool optional)
		{
			m_type = type;
			m_name = name;
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
			return "????";
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

		string m_type;
		string m_name;
		string m_value;
		string m_text;
		bool   m_optional;
	}

	class TextObj : IDataBlock
	{
		this(string text)
		{
			m_name = "";
			m_text = text;
		}

		this(string name, string text)
		{
			m_name = name;
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
			return "????";
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

		string m_name;
		string m_text;
	}

	class ValueObj : IDataBlock
	{
		this(string text)
		{
			m_name = "";
			m_text = text;
		}

		this(string name, string text)
		{
			m_name = name;
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
			return "????";
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

		string m_name;
		string m_text;
	}
	
	enum Type
	{
		ASIGN,
		END_STATEMENT,
		OPEN,
		CLOSE,
		OPEN_BRACE,
		CLOSE_BRACE,
		SEP,
		NAME,
		INCLUDE,
		OPTIONAL,
		OBJECT,
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
					return ParseText(ch);
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
}

