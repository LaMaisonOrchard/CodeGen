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

			while (token.type != Type.EOF)
			{
				if (token.type == Type.OBJECT)
				{
					ParseObjectDefn(input);
				}
				else if (token.type == Type.NAME)
				{
					auto name = token;
					token = input.Get();

					if (token.type == Type.ASIGN)
					{
						ParseAsign(name, input);
					}
					else if (token.type == Type.OPEN_BRACE)
					{
						ParseList(name, input);
					}
					else if (token.type == Type.NAME)
					{
						ParseObject(name, token, input);
					}
					else
					{
						Error(token.posn, "Unexpected token : [" ~ token.text ~ "]");
						while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
						{
							token = input.Get();
						}
					}
				}
				else
			    {
					Error(token.posn, "Unexpected token : [" ~ token.text ~ "]");
					while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
					{
						token = input.Get();
					}
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
				while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
				{
					token = input.Get();
				}
			}
		}

		void ParseAsign(Token name, Tokenise input)
		{
			auto token = input.Get();
			if ((token.type != Type.NAME)  ||
			    (token.type != Type.VALUE) ||
			    (token.type != Type.TEXT))
			{
				Error(token.posn, "Missing asignment value (expected <name> | <value> | <text> )");
			}
			else if (token.type != Type.VALUE)
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
				while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
				{
					token = input.Get();
				}
			}
		}

		void ParseList(Token name, Tokenise input)
		{
			auto token = input.Get();

			string[] list;

			if (token.type == Type.VALUE)
			{
				// Value list
				while (token.type == Type.VALUE)
				{
					list ~= token.text;
					token = input.Get();
				}

				if (token.type != Type.CLOSE_BRACE)
				{
					Error(token.posn, "Unterminated list : [" ~ token.text ~ "] (expected } )");
					while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
					{
						token = input.Get();
					}
				}
				else
				{
					token = input.Get();
					if (token.type != Type.END_STATEMENT)
					{
						Error(token.posn, "Unterminated list statement (expected ; )");
						while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
						{
							token = input.Get();
						}
					}
					else
					{
						AddValueList(name.text, list);
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
					list ~= token.text;
					token = input.Get();
				}

				if (token.type != Type.CLOSE_BRACE)
				{
					Error(token.posn, "Unterminated list : [" ~ token.text ~ "] (expected } )");
					while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
					{
						token = input.Get();
					}
				}
				else
				{
					token = input.Get();
					if (token.type != Type.END_STATEMENT)
					{
						Error(token.posn, "Unterminated list statement (expected ; )");
						while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
						{
							token = input.Get();
						}
					}
					else
					{
						AddValueList(name.text, list);
					}
				}
			}
			else
			{
				Error(token.posn, "Invalid list item : [" ~ token.text ~ "]");
				while ((token.type != Type.END_STATEMENT) && (token.type != Type.EOF))
				{
					token = input.Get();
				}
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
				auto obj = new DataObject(this, input, classDefn, name);

				if (obj.HasError)
				{
					Error(classDefn.posn, "Illegal " ~ classDefn.text ~ " definition");
				}

				if (!IsValid("proto", classDefn.text))
				{
					Error(classDefn.posn, "Object " ~ classDefn.text ~ " not permitted in " ~ "proto");
				}
			}
		}

		void AddDefinition(string parent, string child)
		{
			writeln("Add defn ==> ", parent, " :: ", child);
		}

		bool IsValid(string parent, string child)
		{
			return true;
		}

		void AsignValue(string name, string value)
		{
			writeln(name, " ==> ", value);
		}

		void AsignText(string name, string value)
		{
			writeln(name, " ==> ", value);
		}

		void AddValueList(string name, string[] list)
		{
			writeln("Value list ==> ", name);
		}

		void AddTextList(string name, string[] list)
		{
			writeln("Text list ==> ", name);
		}
		
		string[string]       m_blocks;
		IDataBlock[string]   m_using;
		IDataBlock[][string] m_list;
		
		string m_posn;
		bool   m_error;
	}

	class DataObject : IDataBlock
	{
		this(ProtoBlock root, Tokenise input, Token className, Token name)
		{
			m_posn = name.posn;
			m_class = className.text;
			m_name = name.text;

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
			auto token = input.Get();
			while ((token.type != Type.CLOSE_BRACE) && (token.type != Type.EOF))
			{
				token = input.Get();
			}
		}

		string[string]       m_blocks;
		IDataBlock[string]   m_using;
		IDataBlock[][string] m_list;

		string m_posn;
		string m_class;
		string m_name;
		bool   m_error;
	}

	class TextObj : IDataBlock
	{
		this(string text)
		{
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

		string m_text;
	}

	class ValueObj : IDataBlock
	{
		this(string text)
		{
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
			while ((ch != '\0') && (ch != '"') && (ch != '=') && (ch != ';') && (ch != '{') && (ch != '}') && !isWhite(ch))
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
			
			m_input.Put(ch);
			
			string value = m_text[].idup;
			
			if (value == "-")
			{
				Error(m_input.Posn(), "Illegal value : " ~ value);
			}
			
			return Token(Type.VALUE, value, m_input.Posn());
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

