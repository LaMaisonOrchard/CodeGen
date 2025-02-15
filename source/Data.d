//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.array;
import std.container;
import std.stdio;
import Output;

public
{
	interface IDataBlock
	{
		// A string to identify this type of data object
		string Type();
		
		// Position of this in the input file
		string Posn();
		
		// Expand the block as defined by the data object
		bool DoBlock(BaseOutput output, string name, string subtype);
	}
	
	class DefaultDataBlock : IDataBlock
	{
		this(string posn)
		{
			m_posn = posn;
		}
		
		override string Type() {return "DEFAULT";}
		
		override string Posn()
		{
			return m_posn;
		}
		
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			switch (name)
			{
				case "TYPE":
					output.Write(Type());
					break;
					
				default:
					// No matching block
					return false;
			}
			
			return true;
		}
		
		private
		{
			string m_posn;
		}
	}
	
	final class DataStack : IDataBlock
	{
		this(IDataBlock data)
		{
			assert(data !is null);
			m_stack = SList!IDataBlock(data);
			m_root  = data;
		}
		
		IDataBlock Root()
		{
			return m_root;
		}
		
		string Type()
		{
			if (!m_stack.empty())
			{
				return m_stack.front().Type();
			}
			else
			{
				return "DATA_STACK";
			}
		}
		
		override string Posn()
		{
			if (!m_stack.empty())
			{
				return m_stack.front().Posn();
			}
			else
			{
				// Undefined position
				return "[EMPTY]";
			}
		}
		
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			if (!m_stack.empty())
			{
				return m_stack.front().DoBlock(output, name, subtype);
			}
			else
			{
				// No such block
				return false;
			}
		}
		
		void Push(IDataBlock data)
		{
			m_stack.insert(data);
		}
		
		void Pop()
		{
			if (!m_stack.empty())
			{
				m_stack.removeFront();
			}
		}
		
		private
		{
			SList!IDataBlock m_stack;
			IDataBlock       m_root;
		}
	}
}