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
import std.path;

public
{
	class InputStack
	{
		this(string filename)
		{
			auto fullpath = absolutePath(filename);
			m_stack = SList!Input(Input(fullpath, filename));
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
		
		bool Push(string filename)
		{
			try
			{
				auto fullpath = absolutePath(filename, m_stack.front().Path());
				m_stack.insert(Input(fullpath, filename));
				return true;
			}
			catch (Exception ex)
			{
				return false;
			}
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
		this(string fullPath, string filename)
		{
			m_name = filename;
			m_path = dirName(fullPath);
			m_line = 0;
			m_file = File(fullPath, "r");
		}
		
		string Name() {return m_name;}
		string Path() {return m_path;}
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
		string m_path;
		ulong  m_line;
	}
}

