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
import Proto;

public
{
	IDataBlock ParseData(string filename)
	{
		try
		{
			switch(extension(filename))
			{
				case ".proto":
					return ParseProto(filename);
					
				case ".json":
					return ParseJson(filename);
					
				default:
					writeln("Error : Unrecognised file type : ", filename);
					return null;
			}
		}
		catch (Exception ex)
		{
			writeln("Error : ", GetMessage(ex));
			writeln("Error : Can't read file : ", filename);
			return null;
		}
	}
}


