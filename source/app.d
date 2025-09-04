//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.stdio;
import std.container;
import std.typecons;
import std.path;
import Template;
import InputData;
import Data;

int main(string[] args)
{
	SuperBlock          dataFiles = new SuperBlock();
	Template.Template[] templates;
	Template.Template[] superTemplates;
	
	string dest = "tmp";
	string copy;
	
	int rtn = 0;
	
	if (args.length < 2)
	{
		// default to the help message
		args ~= "-h";
	}
	
	for (ulong i = 1; (i < args.length); i += 1)
	{
		switch(args[i])
		{
			case "-h":
			case "-help":
				writeln(baseName(args[0]), " [-i] [-h] [-dest <path>] [-copy <path>] {-tmpl <template>} {-super <template>} {<data file>}");
				writeln("    -i                : Version");
				writeln("    -version          : Version");
				writeln("    -h                : This help output");
				writeln("    -help             : Version");
				writeln("    -dest <path>      : This is where the output files will be written to");
				writeln("    -copy <path>      : This is where the output files will be copied/merged to");
				writeln("    -tmpl <template>  : Template file");
				writeln("    -super <template> : Template file");
				writeln("    <data file>       : The data to be applied to the template");
				return 0;
				
			case "-i":
			case "-version":
				writeln(baseName(args[0]), " : 0.0.1");
				return 0;
				
			case "-tmpl":
			case "-super":
				auto flag = args[i];
				i += 1;
				if (i >= args.length)
				{
					writeln("Missing template name");
					rtn = -1;
				}
				else
				{
					auto tmpl = new Template.Template(args[i]);
					
					if (tmpl.HasError())
					{
						writeln("Illegal template : ", args[i]);
						rtn = -1;
					}
					else if (flag == "-super")
					{
						superTemplates ~= tmpl;
					}
					else
					{
						templates ~= tmpl;
					}
				}
				break;
				
			case "-dest":
				i += 1;
				if (i >= args.length)
				{
					writeln("Missing destination path");
					rtn = -1;
				}
				else
				{
					dest = args[i];
				}
				break;
				
			case "-copy":
				i += 1;
				if (i >= args.length)
				{
					writeln("Missing copy path");
					rtn = -1;
				}
				else
				{
					copy = args[i];
				}
				break;
				
			default:
				if (args[i][0] == '-')
				{
					writeln("Unexpected argument : ", args[i]);
					rtn = -1;
				}
				else
				{
					auto data = ParseData(args[i]);
					if (data is null)
					{
						writeln("Bad input : ", args[i]);
						rtn = -2;
					}
					else
					{
						dataFiles.Add(data);
					}
				}
				break;
		}
	}
	
	if ((copy is null) || (copy == ""))
	{
		// The copy and destination are the same place
		copy = dest;
	}
	
	// Generate what output we can
	foreach(tmpl ; templates)
	{
		foreach(data ; dataFiles.Files())
		{
			tmpl.Generate("stdout", data, dest, copy);
		}
	}
	
	foreach(tmpl ; superTemplates)
	{
		tmpl.Generate("stdout", dataFiles, dest, copy);
	}
	
	return rtn;
}