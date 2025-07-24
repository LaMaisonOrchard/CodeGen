//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

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
		
		Token token = input.Get();
			
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
			auto p = item in m_using;
			
			if (p is null)
			{
				return null;
			}
			else
			{
				return *p;
			}
		}
		
		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			auto p = item in m_list;
			
			if (p is null)
			{
				return tuple(false, DList!IDataBlock());   // Allow missing lists
			}
			else
			{
				return tuple(true, DList!IDataBlock(*p));
			}
		}
		
		// Expand the block as defined by the data object
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			auto p = name in m_blocks;
			
			if (p is null)
			{
				return false;
			}
			else
			{
				string value = *p;
				
				if (IsValue(value))
				{
					output.Write(FormatValue(Evaluate(value), subtype));
					return true;
				}
				else
				{
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
		
		void Parse(Tokenise input)
		{
			Token token = input.Get();
		}
		
		string[string]       m_blocks;
		IDataBlock[string]   m_using;
		IDataBlock[][string] m_list;
		
		string m_posn;
		bool   m_error;
	}
	
	enum Type
	{
		OBJ_OPEN,
		OBJ_CLOSE,
		LIST_OPEN,
		LIST_CLOSE,
		COLON,
		COMMA,
		STRING,
		VALUE,
		LITTERAL,  // true, false, null
		EOF
	}

	struct Token
	{
		Type type;
		string text;
	}

	class Tokenise
	{
		this(InputStack input)
		{
			m_error = false;
			m_input = input;
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
		
		Token Get()
		{
			while (true)
			{
				auto ch = m_input.Get();
				m_posn  = m_input.Posn();
				
				return Token(Type.EOF, "<EOF>");
			}
		}
		
		void Error(string posn, string message)
		{
			writeln(posn, message);
			m_error = true; 
		}
		
		InputStack m_input;
		string     m_posn;
		bool       m_error;
	}

}

