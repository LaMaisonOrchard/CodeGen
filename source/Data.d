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
	
	
	class SuperBlock : IDataBlock
	{
		final this()
		{
		}
		
		final string Class() {return "SUPER";}
		
		override string Posn()
		{
			return "<SUPER>";
		}
		
		override bool DoBlock(BaseOutput output, string name, string subtype)
		{
			switch (name)
			{
				case "FILES":
					output.Write(FormatValue(m_files.length, subtype));
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
			if (item == "FILE")
			{
				return tuple(true, DList!IDataBlock(m_files));
			}
			else
			{
				return tuple(false, DList!IDataBlock());
			}
		}
		
		override void Dump(BaseOutput file)
		{
			foreach (block ; m_files)
			{
				block.Dump(file);
			}
		}
		
		void Add(IDataBlock block)
		{
			m_files ~= block;
		}
		
		IDataBlock[] Files()
		{
			return m_files;
		}
		
		private
		{
			IDataBlock[] m_files;
		}
	}
	
	final class DataStack : IDataBlock
	{
		this(IDataBlock data)
		{
			assert(data !is null);
			m_stack = SList!Entry(Entry(data, 0));
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
				return m_stack.front().Data().Class();
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
				return m_stack.front().Data().Posn();
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
				return m_stack.front().Data().DoBlock(output, name, subtype);
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
				return m_stack.front().Data().Using(item);
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
				return m_stack.front().Data().List(leaf, item);
			}
			else
			{
				// No such block
				return tuple(false, DList!IDataBlock());
			}
		}
		
		long Idx()
		{
			if (!m_stack.empty())
			{
				return m_stack.front().Idx();
			}
			else
			{
				return 0;
			}
		}
		
		void Push(IDataBlock data, long idx)
		{
			m_stack.insert(Entry(data, idx));
		}
		
		void Push(Entry entry)
		{
			m_stack.insert(entry);
		}
		
		Entry Pop()
		{
			Entry data;
			
			if (!m_stack.empty())
			{
				data = m_stack.front();
				m_stack.removeFront();
			}
			
			return data;
		}
		
		struct Entry
		{
			this(IDataBlock data, long idx)
			{
				m_data = data;
				m_idx  = idx;
			}
			
			IDataBlock Data() {return m_data;}
			long       Idx()  {return m_idx;}
			
			IDataBlock m_data;
			long m_idx;
		}
		
		override void Dump(BaseOutput file)
		{
			if (!m_stack.empty())
			{
				m_stack.front().Data().Dump(file);
			}
		}
		
		private
		{
			
			SList!Entry m_stack;
			IDataBlock  m_root;
		}
	}
}