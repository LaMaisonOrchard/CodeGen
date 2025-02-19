//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.array;
import std.container;
import std.stdio;
import std.typecons;
import Output;
import Utilities;

public
{
	interface IDataBlock
	{
		// A string to identify this type of data object
		string Class();
		
		// Position of this in the input file
		string Posn();
		
		// Get a sub-item of this data item
		IDataBlock Using(string item);
		
		// Get a sub-item of this data item
		Tuple!(bool, DList!IDataBlock) List(bool leaf, string item);
		
		// Expand the block as defined by the data object
		bool DoBlock(BaseOutput output, string name, string subtype);
		
		void Dump(BaseOutput file);
	}
	
	class DefaultDataBlock : IDataBlock
	{
		final this(string posn)
		{
			m_type = "DEFAULT";
			m_posn = posn;
		}
		
		this(string posn, string type)
		{
			m_type = type;
			m_posn = posn;
		}
		
		final string Class() {return m_type;}
		
		override string Posn()
		{
			return m_posn;
		}
		
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			switch (name)
			{
				case "CLASS":
					output.Write(FormatName(Class(), subtype));
					break;
					
				default:
					// No matching block
					return false;
			}
			
			return true;
		}
		
		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
			return null;
		}
		
		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			return tuple(false, DList!IDataBlock());
		}
		
		override void Dump(BaseOutput file)
		{
			file.Write("Dump not supported\n");
		}
		
		private
		{
			string m_posn;
			string m_type;
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
		
		string Class()
		{
			if (!m_stack.empty())
			{
				return m_stack.front().Class();
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
		
		// Get a sub-item of this data item
		override IDataBlock Using(string item)
		{
			if (!m_stack.empty())
			{
				return m_stack.front().Using(item);
			}
			else
			{
				// No such block
				return null;
			}
		}
		
		// Get a sub-item of this data item
		override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
		{
			if (!m_stack.empty())
			{
				return m_stack.front().List(leaf, item);
			}
			else
			{
				// No such block
				return tuple(false, DList!IDataBlock());
			}
		}
		
		void Push(IDataBlock data)
		{
			m_stack.insert(data);
		}
		
		IDataBlock Pop()
		{
			IDataBlock data;
			
			if (!m_stack.empty())
			{
				data = m_stack.front();
				m_stack.removeFront();
			}
			
			return data;
		}
		
		override void Dump(BaseOutput file)
		{
			if (!m_stack.empty())
			{
				m_stack.front().Dump(file);
			}
		}
		
		private
		{
			SList!IDataBlock m_stack;
			IDataBlock       m_root;
		}
	}
}