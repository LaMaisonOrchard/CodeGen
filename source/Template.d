//////////////////////////////////////////////////////////////////
//
//  Copyright 2025 david@the-hut.net
//  All rights reserved
//
@safe:

import std.array;
import std.container;
import std.stdio;
import std.uni;
import std.format;
import std.typecons;
import std.datetime;
import Input;
import Output;
import Data;

public
{	
	class Template
	{
		this(string filename)
		{
			m_error = false;
			Parse(new InputStack(filename));
		}
		
		bool HasError() {return m_error;}
		
		void Generate(NullOutput output, IDataBlock context)
		{
			m_output = new OutputStack(output);
			m_data   = new DataStack(context);
			
			auto block = FindBlock("<ROOT>", "ROOT", "");
			if (block !is null)
			{
				block.Generate(m_output);
			}
			else
			{
				Error("<ROOT>", "No ROOT block");
			}
			
			m_output.Close();
			m_output = null;
		}			
		
		private
		{
			void Error(string[] params ...)
			{
				m_error = true;
				write("Error : ");
				foreach(arg ; params)
				{
					write(arg);
				}
				writeln();
			}
			
			interface IReference
			{
				void Expand(OutputStack output);
			}
			
			// A reference to a piece of litteral text
			class TextRef : IReference
			{
				this(string text)
				{
					m_text = text;
				}
				
				override void Expand(OutputStack output)
				{
					output.Write(m_text);
				}
				
				string m_text;
			}
			
			// A base class common to other references providing common support routines.
			abstract class BaseRef : IReference
			{
				this(string posn)
				{
					m_posn = posn;
				}
				
				final string Posn() { return m_posn;}
				
				final void ExpandBlock(OutputStack output, Block block, string name, string subtype)
				{
					if (block !is null)
					{
						block.Generate(output);
					}
					else if ((name == "CONFIG") && this.outer.m_data.Root().DoBlock(output, name, subtype))
					{
						// Config in the root block
					}
					else if (this.outer.m_data.DoBlock(output, name, subtype))
					{
						// Block is handled by the data item
					}
					else if (BuiltIn(output, name, subtype))
					{
						// Block is handled by the built in blocks
					}
					else
					{
						// No such block
						Error(m_posn, "No such block ", name,":",subtype);
					}
				}
				
				bool BuiltIn(OutputStack output, string name, string subtype)
				{
					switch(name)
					{
						case "YEAR":
						{
							auto now = Clock.currTime();
							output.Write(format("%d", now.year()));
							return true;
						}
						
						default:
							return false;
					}
				}
				
				private
				{
					string m_posn;
				}
			}
			
			// A direct reference to a block of text
			class BlockRef : BaseRef
			{
				this(string posn, string name, Block subtype)
				{
					super(posn);
					m_name    = name;
					m_subtype = subtype;
				}
				
				override void Expand(OutputStack output)
				{
					string subtype = "";
					
					if (m_subtype !is null)
					{
						auto text = new TextOutput();
						auto stack  = new OutputStack(text);
						m_subtype.Generate(stack);
						subtype = text.Text();
						stack.Close();
					}
					
					auto block = this.outer.FindBlock(Posn(), m_name, subtype);
					ExpandBlock(output, block, m_name, subtype);
				}
				
				string m_name;
				Block  m_subtype;
			}
			
			// A reference to a block in the context of a sub-data item of the current data item
			class UsingRef : BaseRef
			{
				this(string posn, string using, string name, Block subtype)
				{
					super(posn);
					m_using   = using;
					m_name    = name;
					m_subtype = subtype;
				}
				
				override void Expand(OutputStack output)
				{
					string subtype = "";
					
					if (m_subtype !is null)
					{
						auto text = new TextOutput();
						auto stack  = new OutputStack(text);
						m_subtype.Generate(stack);
						subtype = text.Text();
						stack.Close();
					}
					
					if (m_using == "PREV")
					{
						IDataBlock data = this.outer.m_data.Pop();
						
						auto block = this.outer.FindBlock(Posn(), m_name, subtype);
						ExpandBlock(output, block, m_name, subtype);
						
						if (data !is null)
						{
							this.outer.m_data.Push(data);
						}						
					}
					else
					{
						IDataBlock data = this.outer.m_data.Using(m_using);
						
						if (data !is null)
						{
							this.outer.m_data.Push(data);
						}
						
						auto block = this.outer.FindBlock(Posn(), m_name, subtype);
						ExpandBlock(output, block, m_name, subtype);
						
						this.outer.m_data.Pop();
					}
				}
				
				string m_using;
				string m_name;
				Block  m_subtype;
			}
			
			// A reference to a block in the context of multiple sub-data items of the current data item
			class LoopRef : BaseRef
			{
				this(string posn, string using, Block sep, string name, Block subtype)
				{
					super(posn);
					m_using   = using;
					m_sep     = sep;
					m_name    = name;
					m_subtype = subtype;
				}
				
				override void Expand(OutputStack output)
				{
					string subtype = "";
					string sep     = "";
					
					if (m_subtype !is null)
					{
						auto text = new TextOutput();
						auto stack  = new OutputStack(text);
						m_subtype.Generate(stack);
						subtype = text.Text();
						stack.Close();
					}
					
					if (m_sep !is null)
					{
						auto text = new TextOutput();
						auto stack  = new OutputStack(text);
						m_sep.Generate(stack);
						sep = text.Text();
						stack.Close();
					}
					
					auto block = this.outer.FindBlock(Posn(), m_name, subtype);
					if (block !is null)
					{
						auto list = this.outer.m_data.List(m_using);
						
						if (list[0])
						{
							bool first = true;
							foreach (data ; list[1])
							{
								this.outer.m_data.Push(data);
							
								if (!first)
								{
									output.Write(sep);
								}
								
								ExpandBlock(output, block, m_name, subtype);
								first = false;
								
								this.outer.m_data.Pop();
							}
						}
						else
						{
							Error(Posn(), "Invalid list : ", m_using);
						}
					}
				}
				
				string m_using;
				string m_name;
				Block  m_sep;
				Block  m_subtype;
			}
			
			// A block of text made up of references to litteral text or other blocks
			final class Block
			{
				this (string posn)
				{
					m_posn     = posn;
					m_name     = "";
					m_subtype  = "";
					m_filename = null;
				}
				
				this (string posn, string name, string subtype, Block filename)
				{
					m_posn     = posn;
					m_name     = name;
					m_subtype  = subtype;
					m_filename = filename;
				}
				
				void Add(IReference data)
				{
					m_blocks ~= data;
				}
				
				string Ref()
				{
					if ((m_subtype is null) || (m_subtype.length == 0))
					{
						return m_name;
					}
					else
					{
						return format("%s:%s", m_name, m_subtype);
					}
				}
				
				string Posn()    {return m_posn;}
				string Name()    {return m_name;}
				string SubType() {return m_subtype;}
				
				bool Match(string name, string subtype)
				{
					return (m_name == name) &&
						   ((m_subtype is null) || (m_subtype == "") || (m_subtype == subtype));
				}
				
				void Generate(OutputStack output)
				{
					if (m_filename !is null)
					{
						auto text_output = new TextOutput();
						auto stack       = new OutputStack(text_output);
						m_filename.Generate(stack);
						if (text_output.Text() == "null")
						{
							output.Push(new NullOutput());
						}
						else if (text_output.Text() == "stdout")
						{
							output.Push(new StdOutput());
						}
						else
						{
							output.Push(new FileOutput(text_output.Text()));
						}
						stack.Close();
					}
					
					foreach (reference; m_blocks)
					{
						reference.Expand(output);
					}
					
					if (m_filename !is null)
					{
						output.Pop();
					}
				}
				
				string       m_name;
				string       m_subtype;
				string       m_posn;
				Block        m_filename;
				IReference[] m_blocks;
			}
		
			void Parse(InputStack input)
			{
				Appender!(char[]) text;
				
				Block block = null;
				
				while (!input.Eof())
				{
					ulong textStart = 0;
					auto  line = input.ReadLine();
					
					if (block !is null)
					{
						for (ulong i = 0; (i < line.length); i += 1)
						{
							if (line[i] == '!')
							{
								if ((i < line.length -1) &&
								    (line[i+1] == '['))
								{
									// Add Text line line[textStart .. i]
									text ~= line[textStart .. i];
									block.Add(new TextRef(text[].idup()));
									text.clear();
									
									// Reference
									i += 2;
									ulong start = i;
									
									for (; (i < line.length-1); i += 1)
									{
										if ((line[i+0] == ']') &&
											(line[i+1] == '!'))
										{
											auto reference = ParseReference(input.Posn(), line[start .. i]);
											if (reference !is null)
											{
												block.Add(reference);
											}
											textStart = i+2;
											i += 1;
											break;
										}
									}
								}
								else if ((i < line.length -4) &&
								    (line[i..i+4] == "!END"))
								{
									text ~= line[textStart .. i];
									block.Add(new TextRef(text[].idup()));
									text.clear();
									
									// End
									block = null;
									break;
								}
								else
								{
									//Nothing to do
								}
							}
						}
						text ~= line[textStart .. $];
					}
					else
					{
						if (line.length > 4)
						{
							if (line[0 .. 4] == "!BLK")
							{
								block = ParseBlock(input.Posn(), line[4..$]);
								text.clear();
								continue;
							}
							else if (line[0 .. 4] == "!FIL")
							{
								block = ParseFileBlock(input.Posn(), line[4..$]);
								text.clear();
								continue;
							}
							else if (line[0 .. 4] == "!INC")
							{
								if (ParseInclude(line[4..$], input))
								{
									// TODO
								}
								continue;
							}
						}
						
						for (ulong i = 0; (i < line.length); i += 1)
						{
							if (isWhite(line[i]))
							{
							}
							else if ((i < line.length -1) &&
							    (line[i+0] == '/') &&
								(line[i+1] == '/'))
							{
								// Comment line
								i = line.length;
							}
							else if ((i < line.length -1) &&
							    (line[i+0] == '%') &&
								(line[i+1] == '%'))
							{
								// Comment line
								i = line.length;
							}
							else
							{
								Error(input.Posn(), "Illegal text : ", line);
							}
						}
					}
				}
				
				if (block !is null)
				{
					Error(input.Posn(), "Unclosed block");
				}
			}
			
			string ParseBlockName(string posn, string line, ref string name, ref string subtype)
			{
				ulong i = 0;
				ulong start;
				
				// Strip white space
				while ((i < line.length) && isWhite(line[i]))
				{
					i += 1;
				}
				
				// Name
				start = i;
				while ((i < line.length) && IsBlockNameChar(line[i]))
				{
					i += 1;
				}
				
				if (start == i)
				{
					// No name
					Error(posn, "Missing block name : ", line);
				}
				else
				{
					name = line[start .. i];
				}
				
				if ((i < line.length) && (line[i] == ':'))
				{
					// Subtype
					i += 1;
					start = i;
					while ((i < line.length) && 
							(isAlphaNum(line[i]) ||
							(line[i] == '_') ||
							(line[i] == '-')))
					{
						i += 1;
					}
					
					if ((i < line.length) && !isWhite(line[i]))
					{
						//Illeghal Subtype
						Error(posn, "Missing illegal subtype : ", line);
					}
					else if (start != i)
					{
						subtype = line[start .. i];
					}
				}
				
				return (i < line.length)?(line[i..$]):("");
			}
			
			
			bool ParseBlockAssignment(string posn, string line, Block block)
			{
				ulong i = 0;
				bool  defined = false;
				
				// Strip white space
				while ((i < line.length) && isWhite(line[i]))
				{
					i += 1;
				}
				
				if ((i < line.length) && (line[i] == '='))
				{
					// block
					Appender!(char[]) text;
					defined = true;
					i += 1;
					ulong textStart = i;
					
					while (i < line.length)
					{
						if (line[i] == '!')
						{
							if ((i < line.length -1) &&
								(line[i+1] == '['))
							{
								// Add Text line line[textStart .. i]
								text ~= line[textStart .. i];
								block.Add(new TextRef(text[].idup()));
								text.clear();
								
								// Reference
								i += 2;
								ulong start = i;
								
								for (; (i < line.length-1); i += 1)
								{
									if ((line[i+0] == ']') &&
										(line[i+1] == '!'))
									{
										IReference reference = ParseReference(posn, line[start .. i]);
										if (reference !is null)
										{
											block.Add(reference);
										}
										textStart = i+2;
										i += 2;
										break;
									}
								}
							}
						}
						else if ((line[i] == '\r') || (line[i] == '\n'))
						{
							text ~= line[textStart .. i];
							block.Add(new TextRef(text[].idup()));
							text.clear();
							textStart = i;
							break;
						}
						else
						{
							//Nothing to do
							i += 1;
						}
					}
					
					if (textStart < i)
					{
						text ~= line[textStart .. i];
						block.Add(new TextRef(text[].idup()));
						text.clear();
					}
				}
				
				return defined;
			}
			
			
			string ParseSubtype(string posn, string line, Block block)
			{
				if (block is null)
				{
					Error(posn, "NULL block reference");
					return line;
				}
				
				Appender!(char[]) text;
				
				ulong i = 0;
				ulong textStart = i;
				for (; (i < line.length); i += 1)
				{
					if (line[i] == '(')
					{
						// Add Text line line[textStart .. i]
						text ~= line[textStart .. i];
						block.Add(new TextRef(text[].idup()));
						text.clear();
						
						// Reference
						i += 1;
						ulong start = i;
						
						for (; (i < line.length-1); i += 1)
						{
							if (line[i] == ')')
							{
								IReference reference = ParseReference(posn, line[start .. i]);
								if (reference !is null)
								{
									block.Add(reference);
								}
								textStart = i+1;
								break;
							}
						}
					}
					else if (isWhite(line[i]))
					{
						block.Add(new TextRef(line[textStart .. i]));
						text.clear();
						return (i < line.length)?(line[i..$]):("");
					}
					else
					{
						// Nothing to do
					}
				}
				
				block.Add(new TextRef(line[textStart .. $]));
				
				return "";
			}
			
			string ParseFileName(string posn, string line, Block block)
			{
				// Strip white space
				ulong i = 0;
				while ((i < line.length) && isWhite(line[i]))
				{
					i += 1;
				}
				
				if ((i < line.length) && (line[i] != '='))
				{
					// block
					line = ParseSubtype(posn, line[i..$], block);
					
					// Strip white space
					i = 0;
					while ((i < line.length) && isWhite(line[i]))
					{
						i += 1;
					}
				}
				else
				{
					// Missing file name
					Error(posn, "Missing file name : ", line);
				}
				
				return (i < line.length)?(line[i..$]):("");
			}
			
			Block ParseBlock(string posn, string line)
			{
				string name;
				string subtype;
				Block  block;
				
				line  = ParseBlockName(posn, line, name, subtype);
				block = AddBlock(posn, new Block(posn, name, subtype, null));
				
				bool defined = ParseBlockAssignment(posn, line, block);
				
				return (defined)?(null):(block);
			}
			
			Block ParseFileBlock(string posn, string line)
			{
				string name;
				string subtype;
				Block  block;
				Block  filename = new Block(posn);
				
				line  = ParseBlockName(posn, line, name, subtype);
				line  = ParseFileName(posn, line, filename);
				block = AddBlock(posn, new Block(posn, name, subtype, filename));
				
				bool defined = ParseBlockAssignment(posn, line, block);
				
				return (defined)?(null):(block);
			}
			
			bool ParseInclude(string line, InputStack input)
			{
				ulong i = 0;
				string posn = input.Posn();
				
				//strip white space
				while ((i < line.length) && isWhite(line[i]))
				{
					i += 1;
				}
				
				if (i >= line.length)
				{
					Error(posn, "No file name specified");
				}
				else if (line[i] == '\"')
				{
					// Quoted text
					ulong start = i;
					while ((i < line.length) && (line[i] != '\"'))
					{
						i += 1;
					}
					
					if (start == i)
					{
						// No name spacified
						Error(posn, "No file name specified");
					}
					else if (line[i] != '\"')
					{
						// Unclosed Quoted
						Error(posn, "Unclosed Quoted : ", line[start..i]);
					}
					else if (!input.Push(line[start..i]))
					{
						Error(posn, "Can't include : ", line[start..i]);
					}
				}
				else
				{
					// Unquoted text
					ulong start = i;
					while ((i < line.length) && !isWhite(line[i]))
					{
						i += 1;
					}
					
					if (!input.Push(line[start..i]))
					{
						Error(posn, "Can't include : ", line[start..i]);
					}
				}
				return true;
			}
			
			IReference ParseReference(string posn, string line)
			{
				IReference reference;
				
				ulong i = 0;
				
				//strip white space
				while ((i < line.length) && isWhite(line[i]))
				{
					i += 1;
				}
				
				// Get the name
				ulong start = i;
				while ((i < line.length) && IsBlockNameChar(line[i]))
				{
					i += 1;
				}
				string name = line[start .. i];
				string item = "";
				string op   = "";
				Block  sep     = null;
				Block  subtype = null;
				
				switch(name)
				{
					case "USING":
					case "FOREACH":
						op = name;
						name = "";
						//strip white space
						while ((i < line.length) && isWhite(line[i]))
						{
							i += 1;
						}
						
						// Get the item
						start = i;
						while ((i < line.length) && IsBlockNameChar(line[i]))
						{
							i += 1;
						}
						item = line[start .. i];
						
						//strip white space
						while ((i < line.length) && isWhite(line[i]))
						{
							i += 1;
						}
						
						// Get the name
						start = i;
						while ((i < line.length) && IsBlockNameChar(line[i]))
						{
							i += 1;
						}
						name = line[start .. i];
						break;
						
					case "LIST":
						op = name;
						name = "";
						//strip white space
						while ((i < line.length) && isWhite(line[i]))
						{
							i += 1;
						}
						
						// Get the item
						start = i;
						while ((i < line.length) && IsBlockNameChar(line[i]))
						{
							i += 1;
						}
						item = line[start .. i];
						
						//strip white space
						while ((i < line.length) && isWhite(line[i]))
						{
							i += 1;
						}
						
						// Get the item
						sep = new Block(posn);
						line = ParseSubtype(posn, line[i..$], sep);
						i = 0;
						
						//strip white space
						while ((i < line.length) && isWhite(line[i]))
						{
							i += 1;
						}
						
						// Get the name
						start = i;
						while ((i < line.length) && IsBlockNameChar(line[i]))
						{
							i += 1;
						}
						name = line[start .. i];
						break;
						
					default:
						break;
				}
				
				if ((i < line.length) && (line[i] == ':'))
				{
					// Block reference
					subtype = new Block(posn);
					line = ParseSubtype(posn, line[i+1..$], subtype);
					i = 0;
				}
				else if ((i >= line.length) || isWhite(line[i]))
				{
					// Complete subtype
				}
				else
				{
					// Error Illegal name
					Error(posn, "Illegal block name : ", line[start..$]);
					i = line.length;
				}
				
				switch(op)
				{
					case "USING":
						reference = new UsingRef(posn, item, name, subtype);
						break;
						
					case "FOREACH":
					case "LIST":
						reference = new LoopRef(posn, item, sep, name, subtype);
						break;
						break;
						
					default:
						reference = new BlockRef(posn, name, subtype);
						break;
				}
				
				//strip white space
				while ((i < line.length) && isWhite(line[i]))
				{
					i += 1;
				}
				
				if (i < line.length)
				{
					// Error ilegal reference
					Error(posn, "Illegal reference : ", line[i..$]);
				}
				
				return reference;
			}
			
			Block AddBlock(string posn, Block block)
			{
				// Check if it has a name
				if (block.Name().length > 0)
				{
					if (FindBlock(posn, block.Name(), block.SubType()) is null)
					{
						m_blocks ~= block;
					}
					else
					{
						Error(posn, "Duplicate block definition : ", block.Ref());
					}
				}
				return block;
			}
			
			Block FindBlock(string posn, string name, string subtype)
			{
				foreach (block ; m_blocks)
				{
					if (block.Match(name, subtype))
					{
						return block;
					}
				}
				
				return null;
			}
			
			Block[]     m_blocks;
			OutputStack m_output;
			DataStack   m_data;
			bool        m_error;
		}
	}
}

private
{
			
	bool IsBlockNameChar(char ch)
	{
		return (isAlpha(ch) && isUpper(ch)) ||
				isNumber(ch) ||
				(ch == '_') ||
				(ch == '-');
	}
}
