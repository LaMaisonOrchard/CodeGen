//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.stdio;
import Template;
import Output;
import Data;

void main()
{
	writeln("Edit source/app.d to start your project.");
	
	auto tmpl = new Template.Template("test.tmpl");
	
	//auto output = new TextOutput();
	auto output = new StdOutput();
	tmpl.Generate(output, new DefaultDataBlock("[NONE]"));
}
