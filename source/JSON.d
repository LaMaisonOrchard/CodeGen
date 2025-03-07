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
		auto input = new Tokenise(new InputStack(name));
		
		Token token;
		do
		{
			token = input.Get();
			writeln(token.text);
		}
		while (token.type != Type.EOF);
		
		return null;
	}

}

private
{

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

