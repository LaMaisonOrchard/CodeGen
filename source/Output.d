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
			m_fp = File(filename, "wb"); 
		}
		
		override void Write(string[] params ...)
		{
			BaseOutput.Write(params);
			
			foreach (string arg ; params)
			{
				m_fp.write(arg);
			}
		}
		
		override void Close()
		{
			BaseOutput.Close();
			m_fp.close();
		}
			
		private
		{
			File m_fp;
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
			m_stack = SList!BaseOutput(output);
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
		
		void Push(BaseOutput output)
		{
			if (IsOpen())
			{
				m_stack.insert(output);
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
		
		SList!BaseOutput m_stack;
	}
	
}

