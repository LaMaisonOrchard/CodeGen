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
import InputData;

void main()
{
	auto tmpl = new Template.Template("test.tmpl");
	
	if (tmpl.HasError())
	{
		writeln("Illegal template");
	}
	else
	{
		auto data = ParseData("test.proto");
		
		if (data !is null)
		{
			tmpl.Generate("stdout", data, ".", ".");
		}
	}
}