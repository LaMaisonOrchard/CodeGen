//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.array;
import std.container;
import std.stdio;
import std.uni;
import std.format;

public
{
	class InputStack
	{
		this(string filename)
		{
			m_stack = SList!Input(Input(filename));
		}
		
		string Posn()
		{
			auto active = m_stack.front();
			return format("[%s:%d]", active.Name(), active.Line());
		}
		
		string ReadLine()
		{
			if (Eof())
			{
				return "";
			}
			else
			{
				return m_stack.front().Readln();
			}
		}
		
		bool Eof()
		{
			while (!m_stack.empty() && m_stack.front().Eof())
			{
				Pop();
			}
			
			return m_stack.empty();
		}
		
		void Push(string filename)
		{
			m_stack.insert(Input(filename));
		}
		
		void Pop()
		{
			if (!m_stack.empty())
			{
				m_stack.front().Close();
				m_stack.removeFront();
			}
		}
		
		SList!Input m_stack;
		int         m_line;
	}
}

private
{
	struct Input
	{
		this(string filename)
		{
			m_name = filename;
			m_line = 0;
			m_file = File(filename, "r");
		}
		
		string Name() {return m_name;}
		ulong  Line() {return m_line;}
		
		void Close()
		{
			m_file.close();
		}
		
		bool Eof()
		{
			return m_file.eof();
		}
		
		string Readln()
		{
			m_line += 1;
			return m_file.readln();
		}
		
		File   m_file;
		string m_name;
		ulong  m_line;
	}
}

