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
	class EvalException : Exception
	{
		this(string msg)
		{
			super(msg);
		}
	}
	
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
	
	long Evaluate(string text)
	{
		//writeln("EVAL : ", text);
	
		auto v1 = EvaluateValue(text);
		 
		if (text.length > 0)
		{
			if ((text[0] == '*') || (text[0] == '/') || (text[0] == '%'))
			{
				v1 = EvaluateMulti(v1, text);
			}
			
			if (text.length > 0)
			{
				if ((text[0] == '+') || (text[0] == '-'))
				{
					v1 = EvaluateSum(v1, text);
				}
			}
		}
		
		if (text.length > 0) new EvalException("Invalid expression");
		
		return v1.Value;
	}
	
}

private
{
	interface IValue
	{
		long Value();
	}
	
	class Value : IValue
	{
		this (long v1)
		{
			m_value = v1;
		}
		
		override long Value()
		{
			return m_value;
		}
	
		private long m_value;
	}
	
	class ValueOp : IValue
	{
		this (char op, IValue v1, IValue v2)
		{
			m_op = op;
			m_v1 = v1;
			m_v2 = v2;
			
			//writeln("OP : ", m_v1.Value, m_op, m_v2.Value);
		}
		
		override long Value()
		{
			switch (m_op)
			{
				case '+':
					return m_v1.Value + m_v2.Value;
					
				case '-':
					return m_v1.Value - m_v2.Value;
					
				case '*':
					return m_v1.Value * m_v2.Value;
					
				case '/':
					return m_v1.Value / m_v2.Value;
					
				case '%':
					return m_v1.Value % m_v2.Value;
					
				default:
					throw new EvalException("Illegal operation");
			}
		}
	
		private char   m_op;
		private IValue m_v1;
		private IValue m_v2;
	}
	
	IValue EvaluateValue(ref string text)
	{
		long value = 0;
		long sign = 1;
		
		ulong i = 0;
		while ((i < text.length) && isWhite(text[i])) {i += 1;}
		
		if ((i < text.length-1) && (text[i] == '('))
		{
			i += 1;
			text = text[i..$];
			return EvaluateBrackets(text);
		}
		else
		{
			if ((i < text.length) && (text[i] == '-'))
			{
				sign = -1;
				i += 1;
			}
			
			if ((i >= text.length) || !isNumber(text[i]))
			{
				throw new EvalException("Invalid number");
			}
			
			while ((i < text.length) && isNumber(text[i]))
			{
				value *= 10;
				value += (text[i] - '0');
				i += 1;
			}
			
			while ((i < text.length) && isWhite(text[i])) {i += 1;}
			text = (i >= text.length)?(""):(text[i..$]);
			
			return new Value(value*sign);
		}
	}
	
	IValue EvaluateBrackets(ref string text)
	{
		auto v1 = EvaluateValue(text);
		 
		if (text.length == 0)
		{
			throw new EvalException("Unclosed brackets");
		}
		else if ((text.length > 0) && (text[0] == ')'))
		{
			// Single value
		}
		else
		{
			if ((text[0] == '*') || (text[0] == '/') || (text[0] == '%'))
			{
				v1 = EvaluateMulti(v1, text);
			}
			
			if (text.length == 0) throw new EvalException("Unclosed brackets");
			
			if ((text[0] == '+') || (text[0] == '-'))
			{
				v1 = EvaluateSum(v1, text);
			}
			
			if ((text.length == 0) || (text[0] != ')')) throw new EvalException("Unclosed brackets");
		}
		
		ulong i = 1;
		while ((i < text.length) && isWhite(text[i])) {i += 1;}
		text = (i < text.length)?(text[i..$]):("");
		
		return v1;
	}
	
	IValue EvaluateSum(IValue v1, ref string text)
	{
		assert(text.length >0);
		
		char op = text[0];
		text = text[1..$];
		
		IValue v2 = EvaluateValue(text);
		
		if (text.length == 0)
		{
			v1 = new ValueOp(op, v1, v2);
		}
		else
		{
			if ((text[0] == '*') || (text[0] == '/') || (text[0] == '%'))
			{
				v2 = EvaluateMulti(v2, text);
			}
			
			if (text.length == 0)
			{
				v1 = new ValueOp(op, v1, v2);
			}
			else if ((text[0] == '+') || (text[0] == '-'))
			{
				v1 = new ValueOp(op, v1, v2);
				v1 = EvaluateSum(v1, text);
			}
			else
			{
				v1 = new ValueOp(op, v1, v2);
			}
		}
		
		return v1;
	}
	
	IValue EvaluateMulti(IValue v1, ref string text)
	{
		assert(text.length >0);
		
		char op = text[0];
		text = text[1..$];
		
		IValue v2 = EvaluateValue(text);
		
		if (text.length == 0)
		{
			v1 = new ValueOp(op, v1, v2);
		}
		else
		{
			if ((text[0] == '*') || (text[0] == '/') || (text[0] == '%'))
			{
				v1 = new ValueOp(op, v1, v2);
				v1 = EvaluateMulti(v1, text);
			}
			else
			{
				v1 = new ValueOp(op, v1, v2);
			}
		}
		
		return v1;
	}
	
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
		string text = " 0 A";
		assert(EvaluateValue(text).Value == 0);
		assert(text == "A");
	}
	
	unittest
	{
		string text = " 00 A";
		assert(EvaluateValue(text).Value == 0);
		assert(text == "A");
	}
	
	unittest
	{
		string text = " -0 A";
		assert(EvaluateValue(text).Value == 0);
		assert(text == "A");
	}
	
	unittest
	{
		string text = " -00 A";
		assert(EvaluateValue(text).Value == 0);
		assert(text == "A");
	}
	
	unittest
	{
		string text = " 0123456789 A";
		assert(EvaluateValue(text).Value == 123456789);
		assert(text == "A");
	}
	
	unittest
	{
		string text = " -0123456789 A";
		assert(EvaluateValue(text).Value == -123456789);
		assert(text == "A");
	}
	
	unittest
	{
		string text = " 01234.56789 A";
		assert(EvaluateValue(text).Value == 1234);
		assert(text == ".56789 A");
	}
	
	unittest
	{
		string text = " -01234.56789 A";
		assert(EvaluateValue(text).Value == -1234);
		assert(text == ".56789 A");
	}
	
	unittest
	{
		string text = " ( -01234 ) A";
		assert(EvaluateValue(text).Value == -1234);
		assert(text == "A");
	}
	
	unittest
	{
		string text = "5 + 6";
		assert(Evaluate(text) == (5 + 6));
	}
	
	unittest
	{
		string text = "(5 + 6)";
		assert(Evaluate(text) == (5 + 6));
	}
	
	unittest
	{
		string text = "5 + 6 -7 +4";
		assert(Evaluate(text) == (5 + 6 -7 + 4));
	}
	
	unittest
	{
		string text = "(5 + 6 - 7 +4)";
		assert(Evaluate(text) == (5 + 6 - 7 +4));
	}
	
	unittest
	{
		string text = "5 + 6*2/3 -7 ";
		assert(Evaluate(text) == (5 + 6*2/3 -7));
	}
	
	unittest
	{
		string text = "6*(2+4) -7 ";
		assert(Evaluate(text) == (6*(2+4) -7));
	}
	
	unittest
	{
		string text = "(2+4)";
		assert(Evaluate(text) == (2+4));
	}
	
	unittest
	{
		string text = "(2*4)";
		assert(Evaluate(text) == (2*4));
	}
	
	unittest
	{
		string text = "8*3/4";
		assert(Evaluate(text) == 8*3/4);
	}
	
	unittest
	{
		string text = "(8*3/4)";
		assert(Evaluate(text) == 8*3/4);
	}
	
	unittest
	{
		try
		{
			string text = " -A";
			EvaluateValue(text);
			assert(false);
		}
		catch (EvalException ex1)
		{
			assert(true);
		}
		catch (Exception ex1)
		{
			assert(false);
		}
	}
	
	unittest
	{
		try
		{
			string text = " - 6";
			EvaluateValue(text);
			assert(false);
		}
		catch (EvalException ex1)
		{
			assert(true);
		}
		catch (Exception ex1)
		{
			assert(false);
		}
	}
	
	unittest
	{
		try
		{
			string text = " A ";
			EvaluateValue(text);
			assert(false);
		}
		catch (EvalException ex1)
		{
			assert(true);
		}
		catch (Exception ex1)
		{
			assert(false);
		}
	}
	
	unittest
	{
		try
		{
			string text = "  ";
			EvaluateValue(text);
			assert(false);
		}
		catch (EvalException ex1)
		{
			assert(true);
		}
		catch (Exception ex1)
		{
			assert(false);
		}
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