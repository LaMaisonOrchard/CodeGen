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
			m_stack.insert(new Input(fullpath, filename));
			m_put = '\0';
		}
		
		this(BaseInput input)
		{
			m_stack.insert(input);
			m_put = '\0';
		}
		
		string Posn()
		{
			if (!m_stack.empty())
			{
				auto active = m_stack.front();
				return format("[%s:%d]", active.Name(), active.Line());
			}
			else
			{
				return "<EOF>";
			}
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
                char ch = m_stack.front().Get();
                while ((ch == '\0') && !m_stack.empty())
                {
                    ch = Get();
                }
				return ch;
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
		
		@trusted bool Push(string filename)
		{
			try
			{
				auto fullpath = absolutePath(filename, m_stack.front().Path());
				m_stack.insert(new Input(fullpath, filename));
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
		
		SList!BaseInput m_stack;
		int             m_line;
		char            m_put;
	}
}

class BaseInput
{
	string Name() {return "";}
	string Path() {return "";}
	ulong  Line() {return 0;}
	
	void Close()
	{
	}
	
	bool Eof()
	{
		return true;
	}
	
	string Readln()
	{
		return "";
	}
	
	char Get()
	{
		return '\0';
	}
	
}

class LitteralInput : BaseInput
{
	this(string text)
	{
		m_text = text;
		m_posn = 0;
		m_line = 0;
	}
	
	override string Name() {return "<INTERNAL>";}
	override string Path() {return "";}
	override ulong  Line() {return m_line;}
	
	override void Close()
	{
		m_text = "";
		m_posn = 0;
	}
	
	override bool Eof()
	{
		return (m_posn >= m_text.length);
	}
	
	override string Readln()
	{
		m_line += 1;
		ulong start = m_posn;
		while ((m_posn < m_text.length) &&
		       (m_text[m_posn] != '\n') &&
			   (m_text[m_posn] != '\r'))
		{
			m_posn += 1;
		}
		
		if (m_posn < m_text.length)
		{
			auto first = m_text[m_posn];
			m_posn += 1;
			
			if (m_posn < m_text.length)
			{
				if ((first == '\n') && (m_text[m_posn] == '\r'))
				{
					m_posn += 1;
				}
				if ((first == '\r') && (m_text[m_posn] == '\n'))
				{
					m_posn += 1;
				}
			}
		}
		
		return m_text[start .. m_posn];
	}
	
	override char Get()
	{
		char[1] ch_a;
		
		if (m_line == 0)
		{
			m_line = 1;
		}
		
		if (m_posn < m_text.length)
		{
			auto ch = m_text[m_posn];
			m_posn += 1;
			return ch;
		}
		
		return '\0';
	}
	
	string m_text;
	ulong  m_posn;
	ulong  m_line;
}



class Input : BaseInput
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
	
	override string Name() {return m_name;}
	override string Path() {return m_path;}
	override ulong  Line() {return m_line;}
	
	override void Close()
	{
		m_file.close();
	}
	
	override bool Eof()
	{
		return m_file.eof();
	}
	
	@trusted override string Readln()
	{
		m_line += 1;
		return m_file.readln();
	}
	
	@trusted override char Get()
	{
		char[1] ch_a;
		
		if (m_line == 0)
		{
			m_line = 1;
		}
		
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

