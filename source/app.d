//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.stdio;
import std.container;
import std.typecons;
import Template;
import Output;
import Data;
import Utilities;

void main()
{
	auto tmpl = new Template.Template("test.tmpl");
	
	if (tmpl.HasError())
	{
		writeln("Illegal template");
	}
	else
	{
		tmpl.Generate("stdout", new Top(), ".", ".");
	}
}

class Top : DefaultDataBlock
{
	this()
	{
		super("[TOP]", "TOP");
		m_list.insertBack(new Entry());
		m_list.insertBack(new Entry());
		m_list.insertBack(new Entry());
	}
	
	// Get a sub-item of this data item
	override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
	{
		if (item == "ENTRY")
		{
			return tuple(true, m_list);
		}
		else
		{
			return tuple(false, DList!IDataBlock());
		}
	}
	
	DList!IDataBlock m_list;
}


class Entry : DefaultDataBlock
{
	this()
	{
		super("[ENTRY]", "ENTRY");
		m_bill = new Bill();
	}
		
	// Get a sub-item of this data item
	override IDataBlock Using(string item)
	{
		if (item == "BILL")
		{
			return m_bill;
		}
		else
		{
			return null;
		}
	}
	
	IDataBlock m_bill;
}


class Bill : DefaultDataBlock
{
	this()
	{
		super("[BILL]", "BILL");
	}
		
	override bool DoBlock(BaseOutput output, string name, string subtype)
	{
		switch (name)
		{
			case "LOIS":
				output.Write(FormatName("Hello "~Type(), subtype));
				break;
				
			default:
				// No matching block
				return DefaultDataBlock.DoBlock(output, name, subtype);
		}
		
		return true;
	}
}
