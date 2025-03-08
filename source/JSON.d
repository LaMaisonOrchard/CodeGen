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
		}
		else
		{
			throw new JsonException("Requires outer object");
		}
		
		token = input.Get();
		if (token.type != Type.EOF)
		{
			throw new JsonException("Extra data at the end");
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
			m_posn = input.Posn();
			Parse(input);
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
				return tuple(false, DList!IDataBlock(*p));
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
		
		void Parse(Tokenise input)
		{
			Token token = input.Get();
			
			while (true)
			{
				switch (token.type)
				{
					case Type.EOF:
						throw new JsonException("Unclosed object");
						
					case Type.STRING:
						{
							string name = token.text;
							
							token = input.Get();
							if (token.type != Type.COLON)
							{
								throw new JsonException("Missing Colon");
							}
							else
							{
								token = input.Get();
								switch (token.type)
								{
									case Type.EOF:
										throw new JsonException("Missing value");
										
									case Type.STRING:
									case Type.VALUE:
									case Type.LITTERAL:
										Add(name, token.text);
										break;
										
									case Type.OBJ_OPEN:
										Add(name, new JsonBlock(input));
										break;
										
									case Type.LIST_OPEN:
										Add(name, ParseList(input));
										break;
										
									default:
										throw new JsonException("Invalid object");
										break;
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
								throw new JsonException("Invalid object");
							}
							
							break;
						}
						
					case Type.OBJ_CLOSE:
						return;
						
					default:
						throw new JsonException("Invalid object");
						break;
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
						throw new JsonException("Unclosed list");
						
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
						throw new JsonException("List of lists are not supported");
						break;
						
					default:
						throw new JsonException("Invalid object");
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
					throw new JsonException("Invalid list");
				}
			}
			
			return list[].dup;
		}
		
		void Add(string name, string value)
		{
			m_blocks[name] = value;
		}
		
		void Add(string name, IDataBlock value)
		{
			m_using[name] = value;
		}
		
		void Add(string name, IDataBlock[] value)
		{
			m_list[name] = value;
		}
		
		string[string]       m_blocks;
		IDataBlock[string]   m_using;
		IDataBlock[][string] m_list;
		string m_posn;
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
			m_input = input;
		}
		
		string Posn()
		{
			return m_posn;
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
						break;  // White space
						
					default:
						throw new JsonException("Illegal input char");
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
							break;
							
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
				else if (ch == '\0')
				{
					throw new JsonException("Unterminated string");
				}
				else if (ch == '\"')
				{
				
				}
				else
				{
					text ~= ch;
				}
				
				if (ch == '\0')
				{
					throw new JsonException("Unterminated string");
				}
			}
			while (ch != '\"');
			
			return text[].idup;
		}

		string ParseTrue()
		{
			if (m_input.Get() != 'r')
			{
				throw new JsonException("Illegal litteral");
			}
			else if (m_input.Get() != 'u')
			{
				throw new JsonException("Illegal litteral");
			}
			else if (m_input.Get() != 'e')
			{
				throw new JsonException("Illegal litteral");
			}
			else
			{
				return "true";
			}
		}

		string ParseFalse()
		{
			if (m_input.Get() != 'a')
			{
				throw new JsonException("Illegal litteral");
			}
			else if (m_input.Get() != 'l')
			{
				throw new JsonException("Illegal litteral");
			}
			else if (m_input.Get() != 's')
			{
				throw new JsonException("Illegal litteral");
			}
			else if (m_input.Get() != 'e')
			{
				throw new JsonException("Illegal litteral");
			}
			else
			{
				return "false";
			}
		}

		string ParseNull()
		{
			if (m_input.Get() != 'u')
			{
				throw new JsonException("Illegal litteral");
			}
			else if (m_input.Get() != 'l')
			{
				throw new JsonException("Illegal litteral");
			}
			else if (m_input.Get() != 'l')
			{
				throw new JsonException("Illegal litteral");
			}
			else
			{
				return "null";
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
	}

}

