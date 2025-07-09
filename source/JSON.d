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

enum AllowMissingLists = true;

public
{
	class JsonException : Exception
	{
		this(string msg)
		{
			super(msg);
		}
	}

	IDataBlock ParseJson(string name)
	{
		auto      input = new Tokenise(new InputStack(name));
		JsonBlock root  = null;
		
		Token token = input.Get();
			
		if (token.type == Type.OBJ_OPEN)
		{
			root = new JsonBlock(input);
			root.Add("[ROOT]", "FILENAME", baseName(name, ".json"));
		}
		else
		{
			throw new JsonException(input.Posn()~"Requires outer object");
		}
		
		token = input.Get();
		if (token.type != Type.EOF)
		{
			throw new JsonException(input.Posn()~"Extra data at the end");
		}
		
		if (input.HasError() || root.HasError())
		{
			throw new JsonException(input.Posn()~"Parse error");
		}
		
		return root;
	}

}

private
{
	final class JsonBlock : IDataBlock
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
			return "JSON";
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
				return tuple(AllowMissingLists, DList!IDataBlock());   // Allow missing lists
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
				output.Write(FormatName(*p, subtype));
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
			
			while (true)
			{
				switch (token.type)
				{
					case Type.EOF:
						Error(input.Posn(), "Unclosed object");
						return;
						
					case Type.STRING:
						{
							string name = token.text;
							string posn = input.Posn();
							
							token = input.Get();
							if (token.type != Type.COLON)
							{
								Error(input.Posn(), "Missing Colon");
							}
							else
							{
								token = input.Get();
								switch (token.type)
								{
									case Type.EOF:
										Error(input.Posn(), "Missing Colon");
										return;
										
									case Type.STRING:
									case Type.VALUE:
									case Type.LITTERAL:
										Add(posn, name, token.text);
										break;
										
									case Type.OBJ_OPEN:
										auto block = new JsonBlock(input);
										Add(posn, name, block);
										m_error = m_error || block.HasError();
										break;
										
									case Type.LIST_OPEN:
										Add(posn, name, ParseList(input));
										break;
										
									default:
										Error(input.Posn(), "Invalid object");
										SkipObject(input);
										return;
								}
							}
							
							token = input.Get();
							
							if (token.type == Type.COMMA)
							{
								token = input.Get();
							}
							else if (token.type == Type.OBJ_CLOSE)
							{
								return;
							}
							else
							{
								Error(input.Posn(), "Missing comma");
								SkipObject(input);
								return;
							}
							
							break;
						}
						
					case Type.OBJ_CLOSE:
						return;
						
					default:
						Error(input.Posn(), "Invalid object");
						SkipObject(input);
						return;
				}
			}
		}
		
		IDataBlock[] ParseList(Tokenise input)
		{
			Appender!(IDataBlock[]) list;
			
			Token token = input.Get();
			
			while (token.type != Type.LIST_CLOSE)
			{
				switch (token.type)
				{
					case Type.EOF:
						Error(input.Posn(), "Unclosed list");
						return list[].dup;
						
					case Type.STRING:
					case Type.VALUE:
					case Type.LITTERAL:
						list ~= new ValueBlock(input.Posn(), token.text);
						token = input.Get();
						break;
						
					case Type.OBJ_OPEN:
						list ~= new JsonBlock(input);
						token = input.Get();
						break;
						
					case Type.LIST_OPEN:
						Error(input.Posn(), "List of lists are not supported");
						ParseList(input);
						break;
						
					default:
						Error(input.Posn(), "Invalid list");
						token = input.Get();
						break;
				}
				
				if (token.type == Type.COMMA)
				{
					token = input.Get();
				}
				else if (token.type == Type.LIST_CLOSE)
				{
					// the end
				}
				else
				{
					Error(input.Posn(), "Missing comma");
					token = input.Get();
				}
			}
			
			return list[].dup;
		}
		
		void Add(string posn, string name, string value)
		{
			name = FormatName(name, "UPPER1");
			if ((name in m_names) !is null)
			{
				Error(posn, "duplicate field : " ~ name);
			}
			
			m_names[name] = true;
			m_blocks[name] = value;
		}
		
		void Add(string posn, string name, IDataBlock value)
		{
			name = FormatName(name, "UPPER1");
			if ((name in m_names) !is null)
			{
				Error(posn, "duplicate field : " ~ name);
			}
			
			m_names[name] = true;
			m_using[name] = value;
		}
		
		void Add(string posn, string name, IDataBlock[] value)
		{
			name = FormatName(name, "UPPER1");
			if ((name in m_names) !is null)
			{
				Error(posn, "duplicate field : " ~ name);
			}
			
			m_names[name] = true;
			m_list[name] = value;
		}
		
		void SkipObject(Tokenise input)
		{
			int count = 1;
			
			while (count > 0)
			{
				Token token = input.Get();
				
				if (token.type == Type.EOF)
				{
					count = 0;
				}
				else if (token.type == Type.OBJ_OPEN)
				{
					count += 1;
				}
				else if (token.type == Type.OBJ_CLOSE)
				{
					count -= 1;
				}
				else
				{
					//Skip
				}
			}
		}
		
		bool[string]         m_names;
		string[string]       m_blocks;
		IDataBlock[string]   m_using;
		IDataBlock[][string] m_list;
		string m_posn;
		bool   m_error;
	}
	
	final class ValueBlock : IDataBlock
	{
		this(string posn, string value)
		{
			m_posn  = posn;
			m_value = value;
		}
		
		// A string to identify this type of data object
		override string Class()
		{
			return "JSON_VALUE";
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
			if (name == "VALUE")
			{
				output.Write(FormatName(m_value, subtype));
				return true;
			}
			
			return false;
		}
		
		override void Dump(BaseOutput file)
		{
		}
		
		string m_posn;
		string m_value;
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
				
				switch (ch)
				{
					case '\0': return Token(Type.EOF, "<EOF>");
					case '{':  return Token(Type.OBJ_OPEN, "{");
					case '}':  return Token(Type.OBJ_CLOSE, "}");
					case '[':  return Token(Type.LIST_OPEN, "[");
					case ']':  return Token(Type.LIST_CLOSE, "]");
					case ':':  return Token(Type.COLON, ":");
					case ',':  return Token(Type.COMMA, ",");
					case '\"': return Token(Type.STRING, ParseString());
					case 't':  return Token(Type.LITTERAL, ParseTrue());
					case 'f':  return Token(Type.LITTERAL, ParseFalse());
					case 'n':  return Token(Type.LITTERAL, ParseNull());
					
					case '-':
					case '1':
					case '2':
					case '3':
					case '4':
					case '5':
					case '6':
					case '7':
					case '8':
					case '9':  return Token(Type.LITTERAL, ParseValue(ch));
					
					case ' ':
					case '\r':
					case '\n':
					case '\t':
						while (isWhite(ch))
						{
							ch = m_input.Get();
						}
						m_input.Put(ch);
						break;  // White space
						
					default:
						Error(m_input.Posn(), "Illegal input char");
						ch = m_input.Get();
						break;
				}
			}
		}

		string ParseString()
		{
			char ch;
			Appender!(char[]) text;
			
			do
			{
				ch = m_input.Get();
				
				if (ch == '\\')
				{
					ch = m_input.Get();
					
					switch (ch)
					{
						case '\0':
							Error(m_input.Posn(), "Unterminated string");
							return text[].idup;
							
						case 'n':
							text ~= '\n';
							break;
							
						case 'r':
							text ~= '\r';
							break;
							
						case 't':
							text ~= '\t';
							break;
							
						default:
							text ~= ch;
							break;
					}
				}
				else if ((ch == '\0') || (ch == '\r') || (ch == '\n'))
				{
					Error(m_input.Posn(), "Unterminated string");
					return text[].idup;
				}
				else if (ch == '\"')
				{
					return text[].idup;
				}
				else
				{
					text ~= ch;
				}
				
				if (ch == '\0')
				{
					Error(m_input.Posn(), "Unterminated string");
					return text[].idup;
				}
			}
			while (ch != '\"');
			
			return text[].idup;
		}

		string ParseTrue()
		{
			if (m_input.Get() != 'r')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else if (m_input.Get() != 'u')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else if (m_input.Get() != 'e')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else
			{
				return "true";
			}
			
			return "<error>";
		}

		string ParseFalse()
		{
			if (m_input.Get() != 'a')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else if (m_input.Get() != 'l')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else if (m_input.Get() != 's')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else if (m_input.Get() != 'e')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else
			{
				return "false";
			}
			
			return "<error>";
		}

		string ParseNull()
		{
			if (m_input.Get() != 'u')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else if (m_input.Get() != 'l')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else if (m_input.Get() != 'l')
			{
				Error(m_input.Posn(), "Illegal litteral");
				SkipText();
			}
			else
			{
				return "null";
			}
			
			return "<error>";
		}
		
		void Error(string posn, string message)
		{
			writeln(posn, message);
			m_error = true; 
		}
		
		void SkipText()
		{
			char ch;
			
			do
			{
				ch = m_input.Get();
			}
			while (isAlpha(ch));
			
			if (ch != '\"')
			{
				m_input.Put(ch);
			}
		}

		string ParseValue(char ch)
		{
			Appender!(char[]) text;
			
			do
			{
				text ~= ch;
				ch = m_input.Get();
			}
			while (isNumber(ch));
			
			m_input.Put(ch);
			
			return text[].idup;
		}
		
		InputStack m_input;
		string     m_posn;
		bool       m_error;
	}

}

