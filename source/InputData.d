//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.container;
import std.stdio;
import std.typecons;
import std.path;
import Input;
import Output;
import Data;
import Utilities;

public
{
	IDataBlock ParseData(string filename)
	{
		try
		{
			auto input = new InputStack(filename);
			
			switch(extension(filename))
			{
				case ".ptree":
					return ParseTree(filename);
					
				default:
					writeln("Error : Unrecognised file type : ", filename);
					return null;
			}
		}
		catch (Exception ex)
		{
			writeln("Error : Can't open file : ", filename);
			return null;
		}
	}
}

private
{

IDataBlock ParseTree(string name)
{
	auto top = new TreeNode("[TOP]", "TOP");
	AddEntry(top);
	AddEntry(top);
	AddEntry(top);
	
	return top;
}

void AddEntry(TreeNode top)
{
	auto entry = new TreeNode("[ENTRY]", "ENTRY");
	auto bill  = new TreeNode("[BILL]", "BILL");
	
	top.AddList("ENTRY", entry);
	entry.AddUsing("BILL", bill);
	bill.AddStd("LOIS", "Hello "~bill.Class());
}


final class TreeNode : IDataBlock
{
	this(string posn, string className)
	{
		m_posn  = posn;
		m_class = className;
		AddStd("CLASS", m_class);
	}
	
	void Add(string name, string subtype, string value)
	{
		m_blocks[name~":"~subtype] = value;
	}
	
	void AddStd(string name, string value)
	{
		Add(name, "PASCAL", value);
		Add(name, "CAMEL", value);
		Add(name, "UPPER1", value);
		Add(name, "LOWER1", value);
		Add(name, "UPPER2", value);
		Add(name, "LOWER2", value);
		Add(name, "", value);
	}
	
	void AddUsing(string name, TreeNode node)
	{
		m_using[name] = node;
	}
	
	void AddList(string list, TreeNode node)
	{
		m_lists[list] ~= node;
	}
	
	override string Class()
	{
		return m_class;
	}
	
	// Position of this in the input file
	override string Posn()
	{
		return m_posn;
	}
	
	// Get a sub-item of this data item
	override IDataBlock Using(string item)
	{
		auto pValue = item in m_using;
		if (pValue is null)
		{
			return null;
		}
		else
		{
			return *pValue;
		}
	}
	
	// Get a sub-item of this data item
	override Tuple!(bool, DList!IDataBlock) List(bool leaf, string item)
	{
		auto pList = item in m_lists;
		if (pList is null)
		{
			return tuple(false, DList!IDataBlock());
		}
		else
		{
			return tuple(true, DList!IDataBlock(*pList));
		}
	}
	
	// Expand the block as defined by the data object
	override bool DoBlock(BaseOutput output, string name, string subtype)
	{
		auto pValue = (name~":"~subtype) in m_blocks;
		if (pValue is null)
		{
			pValue = name~":" in m_blocks;
		}
		
		if (pValue is null)
		{
			return false;
		}
		else
		{
			output.Write(FormatName(*pValue, subtype));
			return true;
		}
	}
		
	override void Dump(BaseOutput file)
	{
		file.Write("Dump TBD\n");
	}
	
	string m_posn;
	string m_class;
	string[string]     m_blocks;
	TreeNode[string]   m_using;
	TreeNode[][string] m_lists;
}
	


}

