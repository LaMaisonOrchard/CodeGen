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
import std.format;
import std.file;
import Input;
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
	
	@trusted string GetMessage(Exception ex)
	{
		return ex.message.idup;
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
	
	bool IsValue(string text)
	{
		if ((text.length > 0) &&
		    ((text[0] == '+') || (text[0] == '-')))
		{
			text = text[1..$];
		}
		
		if (text.length == 0) return false;
		
		foreach (ch ; text)
		{
			if (!isNumber(ch))
			{
				return false;
			}
		}
		
		return true;
	}
	
	// Format the text according to the subtype
	string FormatValue(long value, string subtype)
	{
		switch(subtype)
		{
			case ""      : return format!("%d")(value);
			case "INT"   : return format!("%d")(value);
			case "INT2"  : return format!("%02d")(value);
			case "INT4"  : return format!("%04d")(value);
			case "+INT"  : return format!("%+d")(value);
			case "+INT2" : return format!("%+02d")(value);
			case "+INT4" : return format!("%+04d")(value);
			case "BIN4"  : return format!("%04b")(value);
			case "BIN8"  : return format!("%08b")(value);
			case "BIN16" : return format!("%016b")(value);
			case "BIN24" : return format!("%024b")(value);
			case "BIN32" : return format!("%032b")(value);
			case "HEX2"  : return format!("%02X")(value);
			case "HEX4"  : return format!("%04X")(value);
			case "HEX8"  : return format!("%08X")(value);
			case "HEX16" : return format!("%016X")(value);
			case "hex2"  : return format!("%02x")(value);
			case "hex4"  : return format!("%04x")(value);
			case "hex8"  : return format!("%08x")(value);
			case "hex16" : return format!("%016x")(value);
			default:
				return format("%d", value);
		}
	}
	
	long Evaluate(string text)
	{
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
		
		if (text.length > 0) throw new EvalException("Invalid expression");
		
		return v1.Value;
	}
	
	void FileMerge(string from, string to, bool invertMerge)
	{
		if (!exists(to))
		{
			copy(from, to);
		}
		else if (invertMerge)
		{
			string[string] userSections;
			ReadSections(to, userSections, "GEN");      // Theses are the default section from the source 
			ReadSections(from, userSections, "GEN");    // Override with the actual generated sections
			Copy(to, to, userSections, "GEN");
		}
		else
		{
			string[string] userSections;
			ReadSections(from, userSections, "USER");    // Theses are the default section from the source 
			ReadSections(to, userSections, "USER");      // Override with the actual user sections
			Copy(from, to, userSections, "USER");
		}
	}
}

private  // Evaluate
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
		
		if (((i+1) < text.length) && (text[i] == '('))
		{
			i += 1;
			text = text[i..$];
			return EvaluateBrackets(text);
		}
		else
		{
			if (i < text.length)
			{
				if (text[i] == '-')
				{
					sign = -1;
					i += 1;
				}
				else if (text[i] == '+')
				{
					i += 1;
				}
				else
				{
					// Not a sign prefix
				}
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
		string text = "-81";
		assert(Evaluate(text) == -81);
	}
	
	unittest
	{
		string text = "+81";
		assert(Evaluate(text) == 81);
	}
	
	unittest
	{
		string text = "81";
		assert(Evaluate(text) == 81);
	}
	
	unittest
	{
		string text = "-4 + +9";
		assert(Evaluate(text) == 5);
	}
	
	unittest
	{
		try
		{
			string text = "";
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
}

private  // FormatName
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
			if ((text[i] == '-') || (text[i] == '_') || isWhite(text[i]))
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
	
	unittest
	{
		auto list = DecomposeName("hello World	BILL    lois");
		writeln(list);
		assert (list.length == 4);
		assert (list[0] == "hello");
		assert (list[1] == "World");
		assert (list[2] == "BILL");
		assert (list[3] == "lois");
	}
}

private // IsValue
{
	unittest
	{
		assert (IsValue("0"));
		assert (IsValue("1"));
		assert (IsValue("+1"));
		assert (IsValue("-1"));
		assert (IsValue("123456789"));
		
		assert (!IsValue(""));
		assert (!IsValue("    "));
		assert (!IsValue(" 1"));
		assert (!IsValue("1 "));
		assert (!IsValue("1F"));
	}
}

private // FormatValue
{
	unittest
	{
		assert (FormatValue(10, "") == "10");
		assert (FormatValue(-10, "") == "-10");
	}
	
	unittest
	{
		assert (FormatValue(10, "FRED") == "10");
		assert (FormatValue(-10, "FRED") == "-10");
	}
	
	unittest
	{
		assert (FormatValue(10, "INT") == "10");
		assert (FormatValue(-10, "INT") == "-10");
	}
	
	unittest
	{
		assert (FormatValue(7, "INT2") == "07");
		assert (FormatValue(-7, "INT2") == "-7");
	}
	
	unittest
	{
		assert (FormatValue(7, "INT4") == "0007");
		assert (FormatValue(-7, "INT4") == "-007");
	}
	
	unittest
	{
		assert (FormatValue(10, "+INT") == "+10");
		assert (FormatValue(-10, "+INT") == "-10");
	}
	
	unittest
	{
		assert (FormatValue(7, "+INT2") == "+7");
		assert (FormatValue(-7, "+INT2") == "-7");
	}
	
	unittest
	{
		assert (FormatValue(7, "+INT4") == "+007");
		assert (FormatValue(-7, "+INT4") == "-007");
	}
	
	unittest
	{
		assert (FormatValue(10, "BIN4") == "1010");
		assert (FormatValue(10, "BIN8") == "00001010");
		assert (FormatValue(10, "BIN16") == "0000000000001010");
		assert (FormatValue(10, "BIN24") == "000000000000000000001010");
		assert (FormatValue(10, "BIN32") == "00000000000000000000000000001010");
	}
	
	unittest
	{
		assert (FormatValue(10, "HEX2") == "0A");
		assert (FormatValue(10, "HEX4") == "000A");
		assert (FormatValue(10, "HEX8") == "0000000A");
		assert (FormatValue(10, "HEX16") == "000000000000000A");
	}
	
	unittest
	{
		assert (FormatValue(10, "hex2") == "0a");
		assert (FormatValue(10, "hex4") == "000a");
		assert (FormatValue(10, "hex8") == "0000000a");
		assert (FormatValue(10, "hex16") == "000000000000000a");
	}
	
	unittest
	{
		assert (FormatValue(0xA000, "HEX2") == "A000");
	}
}

private  // Copy
{
	
	string[string] userSections;
	void ReadSections(string file, ref string[string] sections, string type)
	{
		auto input = new Input.Input(file);
		
		while (!input.Eof())
		{
			string name; 
			auto   block = appender!(char[])();
			
			while (!input.Eof())
			{
				auto line = input.Readln();
				auto token  = split(line);
				
				if ((token.length >= 5) &&
					(token[1] == type) &&
					(token[2] == "CODE"))
				{
					if (token[3] == "END")
					{
						writeln("Code section END before BEGIN : ", token[4]);
					}
					else if (token[3] == "BEGIN")
					{
						//if ((token[4] in sections) != null)
						//{
						//	writeln("Duplicate code sections : ", token[4]);
						//}
						//else
						{					
							name = token[4];
							block.clear();
							block ~= line;
							break;
						}
					}
				}
			}
			
			while (!input.Eof())
			{
				auto line = input.Readln();
				auto token  = split(line);
				
				block ~= line;
				
				if ((token.length >= 5) &&
					(token[1] == type) &&
					(token[2] == "CODE"))
				{
					if (token[3] == "END")
					{
						sections[name] = block[].idup;
						break;
					}
					else if (token[3] == "BEGIN")
					{
						writeln("Code section BEGIN before END : ", name);
					}
				}
			}
		}
		
		input.Close();
	}
	
	void Copy(string from, string to, string[string] sections, string type)
	{
		BaseInput input = new Input.Input(from);
		
		// Cache the input
		auto text = appender!(char[])();
		while (!input.Eof())
		{
			text ~= input.Readln();
		}
		input.Close();
		input = new LitteralInput(text[].idup());
		
		auto output = new FileOutput(to);
		
		while (!input.Eof())
		{
			
			while (!input.Eof())
			{
				auto line = input.Readln();
				auto token  = split(line);
				
				if ((token.length >= 5) &&
					(token[1] == type) &&
					(token[2] == "CODE"))
				{
					if (token[3] == "END")
					{
						writeln("Code section END before BEGIN : ", token[4]);
					}
					else if (token[3] == "BEGIN")
					{
						output.Write(sections[token[4]]);
						break;
					}
				}
				
				output.Write(line);
			}
			
			while (!input.Eof())
			{
				auto line = input.Readln();
				auto token  = split(line);
				
				if ((token.length >= 5) &&
					(token[1] == type) &&
					(token[2] == "CODE"))
				{
					if (token[3] == "END")
					{
						break;
					}
					else if (token[3] == "BEGIN")
					{
						writeln("Code section BEGIN before END : ", token[4]);
					}
				}
			}
		}
		
		input.Close();
		output.Close();
	}
	
	
}