//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.container;
import std.stdio;
import std.array;
import std.typecons;
import std.path;
import Input;
import Output;
import Data;
import Utilities;
import JSON;

public
{
	IDataBlock ParseData(string filename)
	{
		try
		{
			auto input = new InputStack(filename);
			
			switch(extension(filename))
			{
				case ".json":
					return ParseJson(filename);
					
				default:
					writeln("Error : Unrecognised file type : ", filename);
					return null;
			}
		}
		catch (Exception ex)
		{
			writeln("Error : ", ex.message);
			writeln("Error : Can't read file : ", filename);
			return null;
		}
	}
}


