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
import std.file;
import std.path;
import Utilities;

public
{
	class OutputException : Exception
	{
		this(string msg)
		{
			super(msg);
		}
	}

	class BaseOutput
	{
		this()
		{
			m_column = 0;
			m_open = true;
		}
		
		void Write(string[] params ...)
		{
			if (!m_open)
			{
				throw new OutputException("File not open");
			}
			
			foreach (string arg ; params)
			{
				foreach (char ch ; arg)
				{
					if ((ch == '\n') || (ch == '\r'))
					{
						m_column = 0;
					}
					else
					{
						m_column += 1;
					}
				}
			}
		}
		
		void Merge(string dest, bool invertMerge)
		{
		}
		
		int Column()
		{
			return m_column;
		}
		
		void Close()
		{
			m_open = false;
		}
		
		bool IsOpen()
		{
			return m_open;
		}
		
		private
		{
			int  m_column;
			bool m_open;
		}
	}
	
	alias NullOutput = BaseOutput;
	
	class TextOutput : BaseOutput
	{
		this()
		{
			m_text = appender!(char[])();
		}
		
		string Text()
		{
			return m_text[].idup();
		}
		
		override void Write(string[] params ...)
		{
			BaseOutput.Write(params);
			
			foreach (string arg ; params)
			{
				m_text ~= arg;
			}
		}
			
		private
		{
			Appender!(char[]) m_text;
		}
	}
	
	class FileOutput : BaseOutput
	{
		this(string filename)
		{
			m_dir = ".";
			m_filename = filename;
			
			auto fullpath = absolutePath(filename);
			auto path     = dirName(fullpath);
			mkdirRecurse(path);
			m_fp = File(fullpath, "wb"); 
		}
		
		this(string dir, string filename)
		{
			m_dir = dir;
			m_filename = filename;
			
			auto fullpath = absolutePath(filename, absolutePath(dir));
			auto path     = dirName(fullpath);
			mkdirRecurse(path);
			m_fp = File(fullpath, "wb"); 
		}
		
		override void Write(string[] params ...)
		{
			BaseOutput.Write(params);
			
			foreach (string arg ; params)
			{
				m_fp.write(arg);
			}
		}
		
		override void Merge(string dest, bool invertMerge)
		{
			auto from = absolutePath(m_filename, absolutePath(m_dir));
			auto to   = absolutePath(m_filename, absolutePath(dest));
			auto path = dirName(to);
			mkdirRecurse(path);
			FileMerge(from, to, invertMerge);
		}
		
		override void Close()
		{
			BaseOutput.Close();
			m_fp.close();
		}
			
		private
		{
			File   m_fp;
			string m_dir;
			string m_filename;
		}
	}
	
	class StdOutput : BaseOutput
	{
		this()
		{
		}
		
		override void Write(string[] params ...)
		{
			BaseOutput.Write(params);
			
			foreach (string arg ; params)
			{
				write(arg);
			}
		}
	}
	
	class OutputStack : BaseOutput
	{
		this(BaseOutput output)
		{
			m_dir = ".";
			m_copy = ".";
			m_stack = SList!BaseOutput(output);
			m_invertMerge = false;
		}
		
		this(string name, string dir, string copy, bool invertMerge)
		{
			m_dir = dir;
			m_copy = copy;
			m_stack = SList!BaseOutput();
			m_invertMerge = invertMerge;
			Push(name);
		}
		
		override void Write(string[] params ...)
		{
			if (!m_stack.empty())
			{
				m_stack.front().Write(params);
			}
		}
		
		override void Close()
		{
			while (!m_stack.empty())
			{
				m_stack.front().Close();
				m_stack.removeFront();
			}
		}
		
		override int Column()
		{
			return m_stack.front().Column();
		}
		
		void Push(string name)
		{		
			if (IsOpen())
			{
				assert (name.length != 0);
				
				if (name == "null")
				{
					m_stack.insert(new NullOutput());
				}
				else if (name == "stdout")
				{
					m_stack.insert(new StdOutput());
				}
				else
				{
					m_stack.insert(new FileOutput(m_dir, name));
				}
			}
		}
		
		void Pop()
		{
			if (!m_stack.empty())
			{
				m_stack.front().Close();
				
				if (m_dir != m_copy)
				{
					// Merge the files
					m_stack.front().Merge(m_copy, m_invertMerge);
				}
				
				m_stack.removeFront();
			}
		}
		
		string m_dir;
		string m_copy;
		SList!BaseOutput m_stack;
		
		bool m_invertMerge;
	}
	
}

