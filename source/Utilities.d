//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.array;
import std.uni;
import std.stdio;
import std.typecons;
import Output;

public
{
	// Format the text according to the subtype
	string FormatName(string text, string subtype)
	{
		switch(subtype)
		{
			case "CAMEL":
				return BuildCamel(DecomposeName(text));
				
			case "PASCAL":
				return BuildPascal(DecomposeName(text));
				
			case "UPPER1":
				return BuildUpper1(DecomposeName(text));
				
			case "SNAKE":
			case "LOWER1":
				return BuildLower1(DecomposeName(text));
				
			case "UPPER2":
				return BuildUpper2(DecomposeName(text));
				
			case "KEBAB":
			case "LOWER2":
				return BuildLower2(DecomposeName(text));
				
			default:
				return text;
		}
	}
}

private
{
	// Identify the type of formatting and decompose into the elements
	string[] DecomposeName(string text)
	{
		string[] list;
		
		foreach(word ; DecomposeName1(text))
		{
			list ~= DecomposeName2(word);
		}
		
		if (list.length == 0)
		{
			list ~= "";
		}
		
		return list;
	}
	
	// Split on under scrore or hiphen
	string[] DecomposeName1(string text)
	{
		string[] list;
		
		ulong i = 0;
		ulong start = i;
		
		while (i < text.length)
		{
			if ((text[i] == '-') || (text[i] == '_'))
			{
				if (start != i)
				{
					list ~= text[start..i];
				}
				i += 1;
				start = i;
			}
			else
			{
				i += 1;
			}
		}
		
		if (start != i)
		{
			list ~= text[start..i];
		}
		
		return list;
	}
	
	// Split on upper case
	string[] DecomposeName2(string text)
	{
		string[] list;
		
		
		bool hasLowerCase = false;
		foreach (ch ; text) {hasLowerCase = hasLowerCase || isLower(ch);}
		
		if (hasLowerCase)
		{
			ulong start = 0;
			ulong i = 1;
			
			while (i < text.length)
			{
				if (isUpper(text[i]))
				{
					list ~= text[start..i];
					start = i;
					i += 1;
				}
				else
				{
					i += 1;
				}
			}
		
			if (start != i)
			{
				list ~= text[start..i];
			}
		}
		else
		{
			list ~= text;
		}
		
		return list;
	}
	
	string BuildCamel(string[] parts)
	{
		Appender!(char[]) text;
		
		foreach (ch ; parts[0])
		{
			text.put(toLower(ch));
		}
			
		foreach(word ; parts[1..$])
		{
			bool first = true;
			foreach (ch ; word)
			{
				if (first)
				{
					text.put(toUpper(ch));
					first = false;
				}
				else
				{
					text.put(toLower(ch));
				}
			}
		}
		
		return text[].idup;
	}
	
	string BuildPascal(string[] parts)
	{
		Appender!(char[]) text;
		
		foreach(word ; parts)
		{
			bool first = true;
			foreach (ch ; word)
			{
				if (first)
				{
					text.put(toUpper(ch));
					first = false;
				}
				else
				{
					text.put(toLower(ch));
				}
			}
		}
		
		return text[].idup;
	}
	
	string BuildUpper1(string[] parts)
	{
		Appender!(char[]) text;
		
		bool first = true;
		foreach(word ; parts)
		{
			if (!first)
			{
				text.put('_');
			}
			
			first = false;
			foreach (ch ; word)
			{
				text.put(toUpper(ch));
			}
		}
		
		return text[].idup;
	}
	
	string BuildLower1(string[] parts)
	{
		Appender!(char[]) text;
		
		bool first = true;
		foreach(word ; parts)
		{
			if (!first)
			{
				text.put('_');
			}
			
			first = false;
			foreach (ch ; word)
			{
				text.put(toLower(ch));
			}
		}
		
		return text[].idup;
	}
	
	string BuildUpper2(string[] parts)
	{
		Appender!(char[]) text;
		
		bool first = true;
		foreach(word ; parts)
		{
			if (!first)
			{
				text.put('-');
			}
			
			first = false;
			foreach (ch ; word)
			{
				text.put(toUpper(ch));
			}
		}
		
		return text[].idup;
	}
	
	string BuildLower2(string[] parts)
	{
		Appender!(char[]) text;
		
		bool first = true;
		foreach(word ; parts)
		{
			if (!first)
			{
				text.put('-');
			}
			
			first = false;
			foreach (ch ; word)
			{
				text.put(toLower(ch));
			}
		}
		
		return text[].idup;
	}
	
	unittest
	{
		auto list = DecomposeName("");
		
		assert (list.length == 1);
		assert (list[0] == "");
	}
	
	unittest
	{
		auto list = DecomposeName("NAME");
		
		assert (list.length == 1);
		assert (list[0] == "NAME");
	}
	
	unittest
	{
		auto list = DecomposeName("name");
		
		assert (list.length == 1);
		assert (list[0] == "name");
	}
	
	unittest
	{
		auto list = DecomposeName("Name");
		
		assert (list.length == 1);
		assert (list[0] == "Name");
	}
	
	unittest
	{
		auto list = DecomposeName("HELLO_WORLD");
		
		assert (list.length == 2);
		assert (list[0] == "HELLO");
		assert (list[1] == "WORLD");
	}
	
	unittest
	{
		auto list = DecomposeName("HELLO-WORLD");
		
		assert (list.length == 2);
		assert (list[0] == "HELLO");
		assert (list[1] == "WORLD");
	}
	
	unittest
	{
		auto list = DecomposeName("hello_world");
		
		assert (list.length == 2);
		assert (list[0] == "hello");
		assert (list[1] == "world");
	}
	
	unittest
	{
		auto list = DecomposeName("hello-world");
		
		assert (list.length == 2);
		assert (list[0] == "hello");
		assert (list[1] == "world");
	}
	
	unittest
	{
		auto list = DecomposeName("HelloWorld");
		
		assert (list.length == 2);
		assert (list[0] == "Hello");
		assert (list[1] == "World");
	}
	
	unittest
	{
		auto list = DecomposeName("helloWorld");
		
		assert (list.length == 2);
		assert (list[0] == "hello");
		assert (list[1] == "World");
	}
	
	unittest
	{
		auto list = DecomposeName("helloWorld_BILL-lois");
		
		assert (list.length == 4);
		assert (list[0] == "hello");
		assert (list[1] == "World");
		assert (list[2] == "BILL");
		assert (list[3] == "lois");
	}
}