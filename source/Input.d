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
			m_put = '\0';
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
		
		void Put(char ch)
		{
			m_put = ch;
		}
		
		char Get()
		{
			if (m_put != '\0')
			{
				auto ch = m_put;
				m_put = '\0';
				return ch;
			}
			else if (Eof())
			{
				return '\0';
			}
			else 
			{
				return m_stack.front().Get();
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
		char        m_put;
	}
}

struct Input
{
	this(string filename)
	{
		auto fullPath = absolutePath(filename);
		m_name = filename;
		m_path = dirName(fullPath);
		m_line = 0;
		m_file = File(fullPath, "r");
		m_lastCh = '\0';
	}
	
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
	
	@trusted string Readln()
	{
		m_line += 1;
		return m_file.readln();
	}
	
	@trusted char Get()
	{
		char[1] ch_a;
		
		if (m_file.rawRead(ch_a).length > 0)
		{
			if (ch_a[0] == '\r')
			{
				if (m_lastCh != '\n')
				{
					m_lastCh = ch_a[0];
					m_line += 1;
				}
			}
			else if (ch_a[0] =='\n')
			{
				if (m_lastCh != '\r')
				{
					m_lastCh = ch_a[0];
					m_line += 1;
				}
			}
			else
			{
				m_lastCh = ch_a[0];
			}
			
			return ch_a[0];
		}
		
		return '\0';
	}
	
	File   m_file;
	string m_name;
	string m_path;
	char   m_lastCh;
	ulong  m_line;
}

