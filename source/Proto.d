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
		ASIGN,
		END_STATEMENT,
		OPEN,
		CLOSE,
		NAME,
		INCLUDE,
		OPTIONAL,
		TYPE,
		ENUM,
		MESSAGE,
		VALUE,
		TEXT,
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
		
		bool Push(string file)
		{
			return m_input.Push(file);
		}
		
		Token Get()
		{
			while (!m_input.Eof())
			{
				auto ch = m_input.Get();
				m_posn  = m_input.Posn();
				
				m_text.clear();
				
				if (isWhite(ch))
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
					return Token(Type.ASIGN, "=");
				}
				else if (ch == ';')
				{
					return Token(Type.END_STATEMENT, ";");
				}
				else if (ch == '{')
				{
					return Token(Type.OPEN, "{");
				}
				else if (ch == '}')
				{
					return Token(Type.CLOSE, "}");
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
			while ((ch != '\0') && ((ch == '_') || isAlphaNum(ch)))
			{
				m_text.put(ch);
				ch = m_input.Get();
			}
			
			if ((ch != '\0') && (ch != '"') && (ch != '=') && (ch != ';') && (ch != '{') && (ch != '}') && !isWhite(ch))
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
					case "type"     : type = Type.TYPE; break;
					case "enum"     : type = Type.ENUM; break;
					case "message"  : type = Type.MESSAGE; break;
					default: type = Type.NAME; break;
				}
				
				return Token(type, text);
			}
		}
		
		Token ParseText(char leadCh)
		{
//  <name>        ::= (<letter> | "_") { <letter> | <number> | "_" }
//  <text>        ::= { <non-whitespace> } 
			auto ch = leadCh;
			while ((ch != '\0') && (ch != '"') && (ch != '=') && (ch != ';') && (ch != '{') && (ch != '}') && !isWhite(ch))
			{
				m_text.put(ch);
				ch = m_input.Get();
			}
			
			m_input.Put(ch);
				
			return Token(Type.TEXT, m_text[].idup);
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
			
			m_input.Put(ch);
			
			string value = m_text[].idup;
			
			if (value == "-")
			{
				Error(m_input.Posn(), "Illegal value : " ~ value);
			}
			
			return Token(Type.VALUE, value);
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
			
			return Token(Type.TEXT, text);
		}
		
		void Error(string posn, string message)
		{
			writeln(posn, message);
			m_error = true; 
		}
		
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
		auto text = " {;} ";
		auto tokeniser = new Tokenise(new InputStack(new LitteralInput(text)));
		
		auto token = tokeniser.Get();
		assert(token.type == Type.OPEN);
		assert(token.text == "{");
		
		token = tokeniser.Get();
		assert(token.type == Type.END_STATEMENT);
		assert(token.text == ";");
		
		token = tokeniser.Get();
		assert(token.type == Type.CLOSE);
		assert(token.text == "}");
		
		token = tokeniser.Get();
		assert(token.type == Type.EOF);
		
		assert(!tokeniser.HasError());
	}
	
	unittest
	{
		auto text = " fred optional include message enum type ";
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
		assert(token.type == Type.MESSAGE);
		assert(token.text == "message");
		
		token = tokeniser.Get();
		assert(token.type == Type.ENUM);
		assert(token.text == "enum");
		
		token = tokeniser.Get();
		assert(token.type == Type.TYPE);
		assert(token.text == "type");
		
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

