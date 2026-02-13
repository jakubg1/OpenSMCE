#!/bin/python
import os, sys, json


#
#    UTILITIES
#

C_RESET = "\33[0m"
C_BOLD = "\33[1m"
C_RED = "\33[91m"
C_GREEN = "\33[92m"
C_YELLOW = "\33[93m"
C_CYAN = "\33[96m"
C_WHITE = "\33[97m"

def load_file(path):
	file = open(path, "r")
	contents = file.read()
	file.close()
	return contents

def save_file(path, contents):
	file = open(path, "w")
	file.write(contents)
	file.close()

#  Converts case like_this to case LikeThis.
def case_snake_to_pascal(line):
	return "".join(word[0].upper() + word[1:].lower() for word in line.split("_"))

# Adds a number of spaces before each line of any multiline text.
def indent_text(text, spaces):
	return "\n".join((" " * spaces) + line for line in text.split("\n"))

# Returns `True` if the given regex is numeric (any string satisfying it must be parseable into a number).
def is_regex_numeric(regex):
	return regex in ["^[-]?[0-9]*$", "^[0-9]*$", "^-[0-9]*$"]



#
#    BEAUTIFIER
#

def get_pretty_value(value, indent):
	if type(value) is dict:
		return get_pretty_dict(value, indent + 1)
	elif type(value) is list:
		return get_pretty_list(value, indent + 1)
	elif type(value) is int or type(value) is float:
		return C_BOLD + C_YELLOW + str(value) + C_RESET
	elif type(value) is str:
		if "\33" in value:
			return C_BOLD + C_YELLOW + "<\"" + C_RESET + value + C_RESET + C_BOLD + C_YELLOW + "\">" + C_RESET
		else:
			return C_BOLD + "\"" + value + "\"" + C_RESET
	elif type(value) is bool:
		if value:
			return C_BOLD + C_GREEN + "True" + C_RESET
		else:
			return C_BOLD + C_RED + "False" + C_RESET
	else:
		return str(value)



def get_pretty_dict(data, indent = 0):
	keys = list(data.keys())
	keys.sort()
	# Type key will be always first.
	if "type" in keys:
		keys.remove("type")
		keys = ["type"] + keys
	###
	has_compound_values = False
	for key in keys:
		if type(data[key]) is dict or type(data[key]) is list:
			has_compound_values = True
			break
	s = "{"
	if has_compound_values:
		s += "\n"
	for key in keys:
		value = data[key]
		value_str = get_pretty_value(value, indent)
		if has_compound_values:
			s += " " * ((indent + 1) * 4)
		if key == "type":
			s += C_YELLOW + key + C_RESET + ": " + value_str
		else:
			s += key + ": " + value_str
		if key != keys[-1]:
			s += ","
			if not has_compound_values:
				s += " "
		if has_compound_values:
			s += "\n"
	if has_compound_values:
		s += " " * (indent * 4)
	s += "}"
	return s



def get_pretty_list(data, indent = 0):
	has_compound_values = False
	for value in data:
		if type(value) is dict or type(value) is list:
			has_compound_values = True
			break
	s = "["
	if has_compound_values:
		s += "\n"
	for i in range(len(data)):
		value = data[i]
		value_str = get_pretty_value(value, indent)
		if has_compound_values:
			s += " " * ((indent + 1) * 4)
		s += value_str
		if i != len(data) - 1:
			s += ","
			if not has_compound_values:
				s += " "
		if has_compound_values:
			s += "\n"
	if has_compound_values:
		s += " " * (indent * 4)
	s += "]"
	return s



def print_pretty_dict(data):
	print(get_pretty_dict(data))



# Finds all pairs of Markdown. Kinda dodgy because it's not extensively used. Available pairs are `code`, *italic*, **bold** and ***bold italic***.
# Returns a list of text segments with a formatting field.
# ex: "This is **bold** text!" -> [{"text":"This is ","style":"default"},{"text":"bold","style":"bold"},{"text":" text!","style":"default"}]
def markdown_find(text):
	styles = {
		"`": "code",
		"*": "italic",
		"**": "bold",
		"***": "bold_italic"
	}

	out = []
	search_index = 0
	while search_index < len(text):
		# Find nearest spell.
		nearest_index = None
		nearest_index_end = None
		nearest_style = None
		nearest_spell_length = None
		for mark in styles:
			spell = mark # " " + mark
			find_index = search_index
			# There may not be a space just after the spell. But we gotta crack on until we're sure absolutely nothing matches the spell.
			while (find_index != -1 and len(text) < find_index + len(spell) - 2 and text[find_index + len(spell)] == " ") or find_index == search_index:
				find_index = text.find(spell, find_index + 1)
			# If we haven't found anything, OR we've already found something closer, move on to the next style.
			if find_index == -1 or (nearest_index != None and nearest_index < find_index):
				continue
			# But wait! There's more! We need to make sure there is a closing spell as well.
			closing_spell = mark # mark + " "
			closing_find_index = find_index
			# This time we're looking for a lack of space BEFORE the closing spell.
			while (closing_find_index != -1 and text[closing_find_index - 1] == " ") or closing_find_index == find_index:
				closing_find_index = text.find(closing_spell, closing_find_index + 1)
			# Found one? Great! Store the index.
			if closing_find_index != -1:
				nearest_index = find_index
				nearest_index_end = closing_find_index
				nearest_style = styles[mark]
				nearest_spell_length = len(spell)
		# If no spell has been found, that's the end. Make sure to store the rest!
		if nearest_index == None:
			out.append({"text": text[search_index:], "style": "default"})
			break
		# Otherwise, we move on!
		# Store everything before the mark as raw text.
		out.append({"text": text[search_index:nearest_index], "style": "default"})
		# Now, store everything enclosed in the mark.
		out.append({"text": text[nearest_index+nearest_spell_length:nearest_index_end], "style": nearest_style})
		# Update the search index.
		search_index = nearest_index_end + nearest_spell_length
	
	return out



# Strips all Markdown that can be detected via markdown_find.
def markdown_strip(text):
	out = ""
	compound = markdown_find(text)
	for element in compound:
		out += element["text"]
	return out



# Returns the type of the root node of the provided JSON schema, converted from the JSON types to the format used by me :)
# ex:   anyOf:["integer","string"] --> "number|string"
def convert_schema_type(schema):
	schema_type_assoc = {
		"integer": "number",
		"array": "list",
		"Color*": "Color",
		"Vector2*": "Vector2",
		"ExprVector2*": "Expression|Vector2"
	}
	
	if "anyOf" in schema:
		# Multitypes aggregate all elements and convert them one by one, separating them with |.
		types = []
		for child in schema["anyOf"]:
			type = convert_schema_type(child)
			if not type in types:
				types.append(type)
		type = "|".join(types)
	elif "$ref" in schema:
		# References check if it's a structure, then a star is prepended; otherwise, it's an object.
		ref_path = schema["$ref"].split("/")
		if len(ref_path) > 1 and ref_path[-2] == "_structures":
			type = ref_path[-1].split(".")[0] + "*"
		else:
			type = "object"
	elif "const" in schema or "enum" in schema:
		# Consts and enums are strings.
		type = "string"
	else:
		type = schema["type"]
	
	# If it's one of these in the table at the top, convert to the provided value.
	if type in schema_type_assoc:
		type = schema_type_assoc[type]

	return type



#
#    CONVERSION PROCEDURES
#

# Converts a JSON schema to the internal intermediate DocLangHTML format (this is the format used by data.txt).
# To be deprecated at some point, with DocLangHTML (doclh) being generated from DocLangData (docld) instead.
def schema_to_doclh(schema, page, references, name = "", indent = 1):
	# Alternatives use special syntax.
	if "oneOf" in schema and not "type" in schema:
		output = "D" + "\t" * indent + "R <div class=\"jsonChoice\">\n"
		output += "D" + "\t" * indent + "R One of the following:\n"
		for data in schema["oneOf"]:
			output += schema_to_doclh(data, page, references, name, indent)
		output += "D" + "\t" * indent + "R </div>\n"
		return output
	
	
	
	if name != "":
		name += " "

	type = convert_schema_type(schema)
	
	description = schema["description"].split("\n")
	if "markdownDescription" in schema:
		description = schema["markdownDescription"].split("\n")
	if "const" in schema:
		# Overwrite the description and just enter the only valid value instead.
		description = ["<b><i>\"" + schema["const"] + "\"</i></b>"]
	if "oneOf" in schema or "enum" in schema:
		# Prepare for enum generation.
		if len(description) == 1:
			description[0] += " Available values are:"
		else:
			description.append("Available values are:")
		if "enum" in schema:
			for i in range(len(schema["enum"])):
				if i > 0:
					description[-1] += ","
				description[-1] += " <b>\"" + schema["enum"][i] + "\"</b>"
			description[-1] += "."
	if "$ref" in schema:
		ref_path = schema["$ref"].split("/")
		# If we're referencing to a full file, and not just a sturcture, add a link in the document.
		if (len(ref_path) <= 1 or ref_path[-2] != "_structures") and ref_path[0] != "#":
			reference = ref_path[-1].split(".")[0]
			if not reference in references:
				message = "More info... uhh dead link :( Fix me! (" + reference + ")"
			elif page == references[reference]:
				# The reference is located on the current page.
				message = "<a href=\"#" + reference + "\">More info below.</a>"
			else:
				# The reference is located on another page.
				message = "<a href=\"" + references[reference] + ".html#" + reference + "\">More info here.</a>"
			if len(description) == 1:
				description[0] += " " + message
			else:
				description.append(message)
	
	# Add description. Apply formatting and multiline changes.
	for i in range(len(description)):
		line = ""
		line_segments = description[i].split("`")
		for j in range(len(line_segments)):
			if j % 2 == 0:
				line += line_segments[j]
			else:
				line += "<i>" + line_segments[j] + "</i>"

		# Second line and beyond gets an extra indent.
		if i == 0:
			output = "D" + "\t" * indent + "- " + name + "(" + type + ") - " + line + "\n"
		else:
			output += "D" + "\t" * (indent + 1) + "R " + line + "<br/>\n"
	
	# Describe enums.
	if "oneOf" in schema:
		list_indent = indent
		if len(description) > 1:
			list_indent += 1
		output += "D" + "\t" * list_indent + "R <ol>\n"
		for value in schema["oneOf"]:
			output += "D" + "\t" * list_indent + "R <li><b>\"" + value["const"] + "\"</b> - " + value["description"] + "</li>\n"
		output += "D" + "\t" * list_indent + "R </ol>\n"

	if "properties" in schema:
		for key in schema["properties"]:
			if key == "$schema":
				continue
			key_data = schema["properties"][key]
			if not key in schema["required"]:
				key += "*"
			output += schema_to_doclh(key_data, page, references, key, indent + 1)
	elif "patternProperties" in schema:
		output += schema_to_doclh(schema["patternProperties"][list(schema["patternProperties"].keys())[0]], page, references, "", indent + 1)
	
	if "items" in schema:
		output += schema_to_doclh(schema["items"], page, references, "", indent + 1)
	
	return output



# Converts a JSON schema which is an enum schema to an internal DocLangHTML format.
# This is just a schema_to_doclh wrapper with some extra sauce.
def schema_to_doclh_enum(schema, page, references):
	output = ""

	for i in range(len(schema["allOf"])):
		if i == 0:
			# The first item is the type variable itself - we don't use it.
			continue
		else:
			b_if = schema["allOf"][i]["if"]
			b_then = schema["allOf"][i]["then"]

			# Name of the type variable.
			type_name = list(b_if["properties"].keys())[0]
			# Add a header and description for this option.
			output += "H3\t<i>" + b_if["properties"][type_name]["const"] + "</i>\n"
			output += "P\t" + b_if["properties"][type_name]["description"] + "\n"
			# Prepare some data to be passed by schema_to_doclh(...).
			enum_data = {
				"type": schema["type"],
				"description": schema["description"],
				"properties": {},
				"required": b_if["required"]
			}
			# Add properties to the data.
			for property in b_then["properties"]:
				if property == "$schema":
					continue
				# Copy all properties from the "then" section, if it has a True value then borrow from the "if" section, or from the global properties.
				value = b_then["properties"][property]
				if value == True:
					if property in b_if["properties"]:
						value = b_if["properties"][property]
					else:
						value = schema["properties"][property]
				enum_data["properties"][property] = value
			# Add information about required fields as well.
			if "required" in b_then:
				enum_data["required"] += b_then["required"]
			enum_data["required"] += schema["required"]
			
			output += schema_to_doclh(enum_data, page, references)
		
	return output



# Opens data.txt and converts its data in DocLangHTML format into HTML files.
# TODO: Split this into a few procedures.
def html_process_data():
	contents = load_file("data.txt")
	data = contents.split("\n")
	
	
	
	# Pass 1: Gather page and reference names
	page_paths = []
	page_names = []
	reference_names = {} # reference -> page name
	
	for line in data:
		line = line.split("\t")
		
		if line[0] == "F":
			page_paths.append(line[1])
		elif line[0] == "N":
			page_names.append(line[1].split(" | ")[0])
		if line[0] == "N" or line[0] == "H2":
			subline = line[1].split(" | ")
			if len(subline) > 1:
				reference_names[subline[1]] = page_paths[-1]
	


	# Pass 2: Generate data from schemas
	new_data = []
	current_page = ""

	for line in data:
		orig_line = line
		line = line.split("\t")

		if line[0] == "F":
			current_page = line[1]
		
		if line[0] == "DI" or line[0] == "DIE":
			schema = json.loads(load_file(line[1]))
			print(schema)
			converted = schema_to_doclh(schema, current_page, reference_names) if line[0] == "DI" else schema_to_doclh_enum(schema, current_page, reference_names)
			print(converted)
			new_data += converted.split("\n")
		else:
			new_data.append(orig_line)
	
	data = new_data
	
	
	
	# Pass 3: Actual processing
	page_name = ""
	page_content = ""
	
	data_mode = False
	last_indent = 0
	
	for line in data:
		line = line.split("\t")
		
		
		
		if not data_mode and line[0] == "D":
			data_mode = True
			page_content += "<div class=\"json\">"
		
		
		
		if data_mode and line[0] != "D":
			while last_indent > 0:
				page_content += "</ul>"
				last_indent -= 1
			
			data_mode = False
			page_content += "</div>"
		
		
		
		if line[0] == "F":
			page_name = line[1]
			page_content = ""
		
			page_content += "<html>"
			page_content += "<head> <meta charset=\"utf-8\"> <link rel=\"stylesheet\" href=\"style.css\"> <title>OpenSMCE Game Documentation</title> </head>"
			page_content += "<body>"
			
			page_content += "<div id=\"banner\"> <img src=\"logo.png\" height=150px> </div>"
			page_content += "<div id=\"banner\"> <h1>OpenSMCE Game Documentation</h1> </div>"
			
			page_content += "<div id=\"navigation\"> <h3>Navigation</h3>"
			page_content += "<ul>"
			for i in range(len(page_paths)):
				path = page_paths[i]
				name = page_names[i]
				if path == page_name:
					page_content += "<li><b>" + name + "</b></li>"
				else:
					page_content += "<li><a href=\"" + path + ".html\">" + name + "</a></li>"
			page_content += "</ul>"
			page_content += "</div>"
			
			page_content += "<div id=\"main\">"
		
		
		
		elif line[0] == "E":
			page_content += "</div>"
			
			page_content += "</body>"
			page_content += "</html>"
		
			file = open(page_name + ".html", "w")
			file.write(page_content)
			file.close()
		
		
		
		elif line[0] == "D":
			indent = 1
			while line[indent] == "":
				indent += 1
			
			while last_indent < indent:
				page_content += "<ul class=\"json\">"
				last_indent += 1
			while last_indent > indent:
				page_content += "</ul>"
				last_indent -= 1
			
			l = line[indent]
			if l[0] == "-":
				s = l[1:].split(" - ")
				
				description = " - ".join(s[1:])
				
				s = s[0].split(" (")
				
				name = s[0][1:]
				optional = len(name) > 0 and name[-1] == "*"
				if optional:
					name = name[:-1]
				
				types = s[1][:-1].split("|")
				
				page_content += "<li>"
				
				for type in types:
					type_res = type.lower()
					if type_res[-1] == "*":
						type_res = "str_" + type_res[:-1]
					page_content += "<img class=\"type\" src=\"icons/" + type_res + ".png\" title=\"" + type + "\" width=\"16px\" height=\"16px\">"
				
				if len(name) == 0:
					page_content += description
				elif optional:
					page_content += "<span class=\"nameOpt\">" + name + "</span>: " + description
				else:
					page_content += "<span class=\"name\">" + name + "</span>: " + description
				page_content += "</li>"
			elif l[0] == "R":
				page_content += l[2:]
		
		
		
		elif line[0] == "R":
			page_content += line[1]
		
		elif line[0] == "N":
			subline = line[1].split(" | ")
			if len(subline) == 1:
				page_content += "<h1>" + subline[0] + "</h1>"
			else:
				page_content += "<h1 id=\"" + subline[1] + "\">" + subline[0] + "</h1>"
		
		elif line[0] == "H2":
			subline = line[1].split(" | ")
			if len(subline) == 1:
				page_content += "<h2>" + subline[0] + "</h2>"
			else:
				page_content += "<h2 id=\"" + subline[1] + "\">" + subline[0] + "</h2>"
		
		elif line[0] == "H3":
			page_content += "<h3>" + line[1] + "</h3>"
		
		elif line[0] == "P":
			page_content += "<p>" + line[1] + "</p>"
		
		elif line[0] == "PS":
			page_content += "<p>" + line[1]
		
		elif line[0] == "PE":
			page_content += line[1] + "</p>"



# Converts DocLang to an internal intermediate DocLangData format.
def docl_to_docld(data):
	out = {}
	current_children = []

	lines = data.split("\n")
	for line in lines:
		line_out = {"optional": False}

		# 4 spaces = one indent.
		line = line.replace("    ", "\t")
		# Count indents and remove indentation.
		indent = 0
		line = line.split("\t")
		while indent < len(line) - 1 and line[indent] == "":
			indent += 1
		line = line[indent]
		# Extract the description.
		line = line.split(" - ")
		if len(line) > 1:
			line_out["description"] = " - ".join(line[1:]).replace("\\n", "\n")
		# Extract tokens.
		line = line[0].split(" ")
		# Skip all lines not starting with -.
		if line[0] != "-":
			continue

		# Go through the tokens, recognize them and fill in the data.
		default = False
		default_string = False
		curly = False
		for i in range(1, len(line)):
			token = line[i]

			# If told to do so, this token will be a default value.
			if default:
				if token == "true" or token == "false": # boolean
					line_out["default"] = token == "true"
				elif token[0] == "\"": # string
					if token[-1] == "\"": # single-word string
						line_out["default"] = token[1:-1]
					else: # start of string
						line_out["default"] = token[1:]
						default_string = True
				elif default_string:
					if token[-1] == "\"": # end of string
						line_out["default"] += " " + token[:-1]
						default_string = False
					else: # middle of string
						line_out["default"] += " " + token
				elif token == "{}": # object (only the empty state is available as defaults for the object)
					line_out["default"] = {}
				elif token[0] == "(": # Vector2 component 1
					line_out["default"] = {}
					line_out["default"]["x"] = float(token[1:-1]) if "." in token[1:-1] else int(token[1:-1])
				elif token[-1] == ")": # Vector2 component 2
					line_out["default"]["y"] = float(token[:-1]) if "." in token[:-1] else int(token[:-1])
				elif "." in token: # float
					line_out["default"] = float(token)
				else: # integer
					line_out["default"] = int(token)
				if token[0] != "(" and not default_string:
					default = False
				continue

			# If we're parsing the curly brace part.
			if curly:
				if token[-1] == "}":
					line_out["keyconst_description"] += token[:-1]
					curly = False
				else:
					line_out["keyconst_description"] += token + " "
				continue

			# Otherwise, just parse the token as normal.
			if token[0] == "(" and token[-1] == ")": # (type) or (Structure)
				# Different types can be separated with | and mixed around, e.g. (type|type|Structure).
				line_out["types"] = []
				subtokens = token[1:-1].split("|")
				for subtoken in subtokens:
					if subtoken[0] == "$": # $expression
						line_out["types"].append({"type": subtoken[1:], "expression": True})
					else: # type
						line_out["types"].append({"type": subtoken})
				# `types` don't exist if there's one type. Instead, have a direct `type` field.
				if len(line_out["types"]) == 1:
					for i in range(len(line_out["types"][0].keys())):
						line_out[list(line_out["types"][0].keys())[i]] = list(line_out["types"][0].values())[i]
				if len(line_out["types"]) < 2:
					del line_out["types"]
			elif token[0] == "[" and token[-1] == "]": # [constraints]
				line_out["constraints"] = token[1:-1].split(",")
			elif token[0] == "\"" and token[-1] == "\"": # "const"
				line_out["const"] = token[1:-1]
			elif token[:2] == "<<" and token[-2:] == ">>": # <<regex>>
				line_out["regex"] = token[2:-2]
			elif token[0] == "{" and token[-1] == ":": # {keyconst: keyconst_description}
				# This is a special token. Because descriptions have spaces, we collect all tokens until the closing brace is found.
				line_out["keyconst"] = token[1:-1]
				line_out["keyconst_description"] = ""
				curly = True
			elif token == "=": # = default_value
				default = True
			else: # name (or name* if optional)
				line_out["name"] = token
				if line_out["name"][-1] == "*":
					line_out["name"] = line_out["name"][:-1]
					line_out["optional"] = True
		
		# Insert the processed line as a child.
		if indent == 0:
			out = line_out
		else:
			parent = current_children[indent - 1]
			if "children" in parent:
				parent["children"].append(line_out)
			else:
				parent["children"] = [line_out]
		
		# Update children.
		if len(current_children) > indent:
			current_children[indent] = line_out
		elif len(current_children) == indent:
			current_children.append(line_out)
		else:
			pass # Throw an error - double indent.
	
	return out



# Returns whether the entry has at least a single Vector2 structure inside itself which has a default value.
def docld_contains_default_vector(entry):
	if "type" in entry and entry["type"] == "Vector2" and "default" in entry:
		return True
	if "children" in entry:
		for child in entry["children"]:
			if docld_contains_default_vector(child):
				return True
	return False



# Converts DocLangData to a JSON schema.
def docld_to_schema(entry, is_root = True, structures_path = "_structures/"):
	simple_types = ["number", "integer", "boolean", "string", "object", "array"]
	constraints = {
		">=": "minimum",
		">": "exclusiveMinimum",
		"<=": "maximum",
		"<": "exclusiveMaximum"
	}

	out = {}

	# The root object has a schema as well.
	if is_root:
		out["$schema"] = "http://json-schema.org/draft-07/schema"
	# Carry the type over.
	if "type" in entry:
		if entry["type"] in simple_types:
			if "expression" in entry:
				out["$ref"] = structures_path + "Expr" + entry["type"].capitalize() + ".json"
			else:
				out["type"] = entry["type"]
		else:
			out["$ref"] = structures_path + ("Expr" if "expression" in entry else "") + entry["type"] + ".json"
	elif "const" in entry:
		out["const"] = entry["const"]
	elif "types" in entry:
		# Deal with multitypes.
		out["anyOf"] = []
		for choice in entry["types"]:
			if "type" in choice:
				if entry["type"] in simple_types:
					out["anyOf"].append({"type": entry["type"]})
				else:
					out["anyOf"].append({"$ref": structures_path + ("Expr" if "expression" in choice else "") + entry["type"] + ".json"})
			elif "const" in choice:
				out["anyOf"].append({"const": choice["const"]})
				
	elif not "children" in entry:
		# Non-typed and non-const values with no children mean that any value will suffice. This is depicted as true.
		return True
	
	# Carry the description as well.
	if "description" in entry:
		stripped_description = markdown_strip(entry["description"])
		out["description"] = stripped_description
		# If we lost some Markdown, make sure to preserve it by putting it in an additional field.
		if stripped_description != entry["description"]:
			out["markdownDescription"] = entry["description"]

	# The rest depends on the type.
	if "type" in entry:
		if entry["type"] == "object":
			if "regex" in entry:
				# So-called "Regex Object".
				out["propertyNames"] = {"pattern": entry["regex"]}
				out["patternProperties"] = {}
				# As with arrays, we care about only one child.
				out["patternProperties"][entry["regex"]] = docld_to_schema(entry["children"][0], False, structures_path)
			elif "keyconst" in entry:
				# So-called "Enum Object".
				key = entry["keyconst"]
				out["properties"] = {key: {"enum": []}}
				out["allOf"] = [{"properties": {key: {"description": entry["keyconst_description"]}}}]
				out["required"] = [key]
				if "children" in entry:
					for child in entry["children"]:
						if "const" in child: # One of the choices in the Enum Object for the typed variable.
							child_block = {}
							# We can't really hook up a call to itself here, because children of this child would get involved and mess things up.
							child_block["if"] = {"properties": {key: {"const": child["const"], "description": child["description"]}}, "required": [key]}
							# Now similar stuff to regular objects. Shenanigans incoming!!!
							# Adding an array as a child at the front ensures that it will come first, display as True and won't show up as required twice.
							child_children = [{"name": key, "optional": True}]
							if "children" in child:
								child_children += child["children"]
							child_block["then"] = docld_to_schema({"type": "object", "children": child_children}, is_root, structures_path)
							if "$schema" in child_block["then"]:
								del child_block["then"]["$schema"]
							del child_block["then"]["type"]
							# Add prepared blocks.
							out["allOf"].append(child_block)
							out["properties"][key]["enum"].append(child["const"])
						else: # "Always-there" properties for Enum Objects.
							# Add this entry to the first block, as it is available all the time.
							out["properties"][child["name"]] = docld_to_schema(child, False, structures_path)
							# Mark as non-optional if necessary.
							if not child["optional"]:
								out["required"].append(child["name"])
							# Allow this parameter for all conditional blocks.
							for child_block in out["allOf"]:
								if "then" in child_block:
									child_block["then"]["properties"][child["name"]] = True
			elif "children" in entry and not "name" in entry["children"][0]:
				# One nameless child in a regular object means that the object behaves like an array, with all keys possible.
				out["patternProperties"] = {}
				out["patternProperties"]["^.*$"] = docld_to_schema(entry["children"][0], False, structures_path)
			else:
				# Regular object.
				out["properties"] = {}
				out["required"] = []
				out["additionalProperties"] = False
				if is_root:
					out["properties"]["$schema"] = True
				if "children" in entry:
					for child in entry["children"]:
						if not child["optional"]:
							out["required"].append(child["name"])
						out["properties"][child["name"]] = docld_to_schema(child, False, structures_path)
				if len(out["required"]) == 0:
					del out["required"]
		elif entry["type"] == "array":
			# Nothing more, nothing less, exactly ONE nameless child must be here.
			out["items"] = docld_to_schema(entry["children"][0], False, structures_path)
		elif entry["type"] == "number" or entry["type"] == "integer":
			# Check constraints.
			if "constraints" in entry:
				for constraint in entry["constraints"]:
					for prefix in constraints:
						if constraint.startswith(prefix):
							number = float(constraint[len(prefix):])
							if entry["type"] == "integer":
								number = int(number)
							out[constraints[prefix]] = number
							break
	# Prepare enums.
	if not "type" in entry or entry["type"] == "string" or entry["type"] == "number" or entry["type"] == "integer":
		if "children" in entry:
			out["oneOf"] = []
			for child in entry["children"]:
				out["oneOf"].append(docld_to_schema(child, False, structures_path))
	
	return out



# Converts a list of fields to traverse through, such as `{{"type": "string", "value": "integers"}, {"type": "integer", "value": "n"}}`
# into e.g. `"{\"integers\", n}"`.
def docld_to_lua_index(fields):
	out = "{"
	for i in range(len(fields)):
		field = fields[i]
		if i > 0:
			out += ", "
		if field["type"] == "string":
			out += "\"" + field["value"] + "\""
		elif field["type"] == "integer":
			out += str(field["value"])
		elif field["type"] == "ref_string":
			out += field["value"]
		elif field["type"] == "ref_integer":
			out += str(field["value"])
	return out + "}"

# Converts a list of fields to traverse through, such as `{{"type": "string", "value": "integers"}, {"type": "integer", "value": "n"}}`
# into e.g. `".integers[n]"`.
# ref_string is indexed by `[n]` instead of `.n`
# ref_integer is indexed by `[tonumber(n)]` instead of `[n]`
def docld_to_lua_context(fields):
	out = ""
	for i in range(len(fields)):
		field = fields[i]
		if field["type"] == "string":
			out += "." + field["value"]
		elif field["type"] == "integer":
			out += "[" + str(field["value"]) + "]"
		elif field["type"] == "ref_string":
			out += "[" + field["value"] + "]"
		elif field["type"] == "ref_integer":
			out += "[tonumber(" + str(field["value"]) + ")]"
	return out

# Determines LDoc (luadoc) type from the DocLD entry, without the `---@type ` prefix.
def docld_to_lua_ldoc(entry):
	# TODO: Do something with this.
	structure_config_lookup = ["number","integer","boolean","string","Vector2","Color","Sprite","Image","ColorPalette","Font","FontFile","SoundEvent","Sound","MusicTrack","MusicPlaylist"]

	optional = entry["optional"]
	out = ""
	if "expression" in entry:
		if entry["expression"]:
			out = "Expression"
	elif "type" in entry:
		if entry["type"] == "object":
			if "keyconst" in entry:
				# Enum object.
				# TODO: Do something with this.
				out = "table"
			elif "regex" in entry:
				# Regex object.
				if not "children" in entry or len(entry["children"]) != 1:
					raise Exception("Regex Objects must have exactly one child!")
				key_type = "number" if is_regex_numeric(entry["regex"]) else "string"
				out = "table<" + key_type + ", " + docld_to_lua_ldoc(entry["children"][0]) + ">"
			else:
				# Regular object.
				out = "{"
				if "children" in entry:
					for child in entry["children"]:
						if out != "{":
							out += ", "
						if not "name" in child:
							raise Exception("Regular objects' children must have a name!")
						out += child["name"] + ": " + docld_to_lua_ldoc(child)
				out += "}"
			# Optional objects and arrays are actually always prepended, even if they are optional and no data is there.
			optional = False
		elif entry["type"] == "array":
			if not "children" in entry or len(entry["children"]) != 1:
				raise Exception("Arrays must have exactly one child!")
			out = docld_to_lua_ldoc(entry["children"][0]) + "[]"
			# Optional objects and arrays are actually always prepended, even if they are optional and no data is there.
			optional = False
		elif entry["type"] == "string":
			if "children" in entry:
				# Enum string.
				for child in entry["children"]:
					if out != "":
						out += "|"
					out += "\"" + child["const"] + "\""
			else:
				# A regular string.
				out = "string"
		else:
			out = entry["type"]
			if not entry["type"] in structure_config_lookup:
				out += "Config"
	if optional and not "default" in entry:
		out += "?"
	return out



# Converts a single entry's simple value (not an array, not an object) to the part after the `=` sign in Lua config class code.
# `name` will be overwritten if it exists in the entry.
def docld_to_lua_value(entry, class_name, fields, optional):
	lua_type_assoc = {
		"number": "parseNumber",
		"integer": "parseInteger",
		"string": "parseString",
		"boolean": "parseBoolean",
		"Vector2": "parseVec2",
		"Color": "parseColor",
		"Sprite": "parseSprite",
		"Image": "parseImage",
		"ColorPalette": "parseColorPalette",
		"Font": "parseFont",
		"FontFile": "parseFontFile",
		"SoundEvent": "parseSoundEvent",
		"Sound": "parseSound",
		"MusicTrack": "parseMusicTrack",
		"MusicPlaylist": "parseMusicPlaylist"
	}
	lua_expr_type_assoc = {
		"number": "parseExprNumber",
		"integer": "parseExprInteger",
		"string": "parseExprString",
		"boolean": "parseExprBoolean",
		"Vector2": "parseExprVec2"
	}
	
	# Deal with simple fields.
	if "type" in entry:
		if entry["type"] == "object" or entry["type"] == "array":
			raise Exception("ERROR: Cannot get a generic object or array parser")
		lookup = lua_expr_type_assoc if "expression" in entry else lua_type_assoc
		if entry["type"] in lookup:
			function = "u." + lookup[entry["type"]] + ("Opt" if optional else "")
		else:
			# If the provided type is not present in the lookup, assume a registered resource parser such as `parseCollectibleGeneratorConfig`
			function = "u.parse" + entry["type"] + "Config" + ("Opt" if optional else "")
		default = ""
		if "default" in entry:
			default = ", "
			if entry["type"] == "boolean":
				default += "true" if entry["default"] else "false"
			elif entry["type"] == "string":
				default += "\"" + entry["default"] + "\""
			elif entry["type"] == "Vector2":
				if entry["default"]["x"] == 0 and entry["default"]["y"] == 0:
					default += "Vec2()"
				else:
					default += "Vec2(" + str(entry["default"]["x"]) + ", " + str(entry["default"]["y"]) + ")"
			else:
				default += str(entry["default"])
		return function + "(data, base, path, " + docld_to_lua_index(fields) + default + ")"
	elif "const" in entry:
		raise Exception("TODO: Consts not supported")
	elif "types" in entry:
		raise Exception("TODO: Multitypes aren't supported")
	raise Exception("TODO: something not supported at all!!!")

# Converts DocLangData to raw Lua config class information.
# You might want to convert it to a fully fledged Lua config class by further processing the result using `docld_to_lua_pack()` and `docld_to_lua_finalize()`.
def docld_to_lua_raw(entry, class_name, schema_path, is_root = True, fields = [], iterators_used = 0):
	out = []

	optional = entry["optional"]
	if "name" in entry:
		name = entry["name"]
	
	# Generate contexts.
	fields_with_name = fields + [{"type": "string", "value": name}] if "name" in entry else fields
	context = docld_to_lua_context(fields)
	context_with_name = docld_to_lua_context(fields_with_name)

	# Deal with fields.
	if "type" in entry:
		if entry["type"] == "object":
			if not is_root:
				# The root object is the class itself, hence the `not is_root` check.
				table_id = "self" + context_with_name
				if not optional or "default" in entry:
					out.append(table_id + " = {}")
				if optional:
					out.append("if data" + context_with_name + " then")
					out.append(1)
					if not "default" in entry:
						out.append(table_id + " = {}")
			if "regex" in entry:
				# So-called "Regex Object".
				child = entry["children"][0]
				out.append("for n, _ in pairs(data" + context_with_name + ") do")
				out.append(1)
				if is_regex_numeric(entry["regex"]):
					new_fields = fields_with_name + [{"type": "ref_integer", "value": "n"}]
				else:
					new_fields = fields_with_name + [{"type": "ref_string", "value": "n"}]
				out += docld_to_lua_raw(child, class_name, schema_path, False, new_fields, iterators_used)
				out.append(-1)
				out.append("end")
			elif "keyconst" in entry:
				# So-called "Enum Object".
				full_keyconst = context_with_name + "." + entry["keyconst"]
				out.append("self" + full_keyconst + " = u.parseString(data, base, path, " + docld_to_lua_index(fields_with_name + [{"type": "string", "value": entry["keyconst"]}]) + ")")
				error_msg = ""
				children_processed = 0
				for child in entry["children"]:
					if "const" in child: # One of the choices in the Enum Object for the typed variable.
						out.append(("if" if children_processed == 0 else "elseif") + " self" + full_keyconst + " == \"" + child["const"] + "\" then")
						out.append(1)
						if "children" in child:
							for subchild in child["children"]:
								out += docld_to_lua_raw(subchild, class_name, schema_path, False, fields_with_name, iterators_used)
						else:
							out.append("-- No fields")
						out.append(-1)
						if children_processed > 0:
							# TODO: This check should not count extra items. For now, the "or" sugar is disabled.
							if False and child == entry["children"][-1]:
								error_msg += " or "
							else:
								error_msg += ", "
						error_msg += "\\\"" + child["const"] + "\\\""
						children_processed += 1
				out.append("else")
				out.append("    error(string.format(\"Unknown " + (name if "name" in entry else class_name) + " type: %s (expected " + error_msg + ")\", self" + full_keyconst + "))")
				out.append("end")
			# Regular object, AND extra children in the enum/regex objects.
			if "children" in entry:
				for child in entry["children"]:
					# Either not a choice in the Enum Object or not the first child (since we've assigned it) in the Regex Object.
					# Uhm... is there any point to extra entries in Regex Objects? I don't see any support or ideas for them anywhere...
					if not "const" in child and (not "regex" in entry or child != entry["children"][0]):
						distinguish_block = (not "type" in child or child["type"] != "string") and "children" in child
						if distinguish_block and (len(out) > 0 and out[-1] != ""):
							out.append("")
						if "children" in child:
							out.append("---@type " + docld_to_lua_ldoc(child))
						out += docld_to_lua_raw(child, class_name, schema_path, False, fields_with_name, iterators_used)
						if distinguish_block:
							out.append("")
			if not is_root:
				if optional:
					out.append(-1)
					out.append("end")
				if "name" in entry and out[-1] != "":
					out.append("")
		elif entry["type"] == "array":
			if len(out) > 0 and out[-1] != "":
				out.append("")
			child = entry["children"][0]
			table_id = context_with_name
			# If it's more than 5 layers deep, that's your fault !! lol
			# I know this is some really terrible Python code
			# Can YOU make it 40,000,000,000% faster?
			if iterators_used >= 5:
				raise Exception("Maximum amount of 5 iterators exhausted. Check depth of your data!")
			iterator = "ijklm"[iterators_used]
			new_fields = fields_with_name + [{"type": "integer", "value": iterator}]
			out.append("self" + table_id + " = {}")
			if optional:
				out.append("if data" + table_id + " then")
				out.append(1)
			out.append("for " + iterator + " = 1, #data" + table_id + " do")
			out.append(1)
			out += docld_to_lua_raw(child, class_name, schema_path, False, new_fields, iterators_used + 1)
			out.append(-1)
			out.append("end")
			if optional:
				out.append(-1)
				out.append("end")
			out.append("")
		else:
			out.append("self" + context_with_name + " = " + docld_to_lua_value(entry, class_name, fields_with_name, optional))
	elif "const" in entry:
		print("TODO: Consts not supported")
	elif "types" in entry:
		print("TODO: Multitypes aren't supported")
	
	# Remove all trailing empty lines.
	while len(out) > 0 and (out[-1] == ""):
		out.pop()
	
	return out

# Packs the raw list of lines and indentation instructions with everything that makes it a valid Config Class file.
# This includes class header, necessary `require`s, a Resource Manager injector
# The result is still a raw list and must be processed into valid Lua code with `docld_to_lua_finalize()`.
def docld_to_lua_pack(raw, entry, class_name, schema_path):
	out = []

	# Lines to go before the raw contents.
	out.append("--!!--")
	out.append("-- Auto-generated by DocLang Generator")
	out.append("-- REMOVE THIS COMMENT IF YOU MODIFY THIS FILE")
	out.append("-- in order to protect it from being overwritten!")
	out.append("--!!--")
	out.append("")
	out.append("local class = require \"com.class\"")
	# Predict the Vector2 require for default vector parameters.
	if docld_contains_default_vector(entry):
		out.append("local Vec2 = require(\"src.Essentials.Vector2\")")
	out.append("")
	out.append("---@class " + class_name)
	out.append("---@overload fun(data, path, isAnonymous):" + class_name)
	out.append("local " + class_name + " = class:derive(\"" + class_name + "\")")
	out.append("")
	out.append(class_name + ".metadata = {")
	out.append(1)
	out.append("schemaPath = \"" + schema_path + "\"")
	out.append(-1)
	out.append("}")
	out.append("")
	out.append("---Constructs an instance of " + class_name + ".")
	out.append("---@param data table Raw data from a file.")
	out.append("---@param path string? Path to the file. Used for error messages and saving data.")
	out.append("---@param isAnonymous boolean? If `true`, this resource is anonymous and its path is invalid for saving data.")
	out.append("---@param base " + class_name + "? If specified, this resource extends the provided resource. Any missing fields are prepended from the base resource.")
	out.append("function " + class_name + ":new(data, path, isAnonymous, base)")
	out.append(1)
	out.append("local u = _ConfigUtils")
	out.append("self._path = path")
	out.append("self._alias = data._alias")
	out.append("self._isAnonymous = isAnonymous")
	out.append("")
	out.append("base = base or {}")
	out.append("")

	# Add raw contents.
	out += raw

	# Lines to go after the raw contents.
	out.append(-1)
	out.append("end")
	out.append("")
	out.append("---Injects functions to Resource Manager regarding this resource type.")
	out.append("---@param ResourceManager ResourceManager Resource Manager class to inject the functions to.")
	out.append("function " + class_name + ".inject(ResourceManager)")
	out.append(1)
	out.append("---@class ResourceManager")
	out.append("ResourceManager = ResourceManager")
	out.append("")
	out.append("---Retrieves a " + class_name + " by given path.")
	out.append("---@param reference string The path to the resource.")
	out.append("---@return " + class_name)
	out.append("function ResourceManager:get" + class_name + "(reference)")
	out.append(1)
	out.append("return self:getResourceConfig(reference, \"" + class_name[:-6] + "\")")
	out.append(-1)
	out.append("end")
	out.append(-1)
	out.append("end")
	out.append("")
	out.append("return " + class_name)

	return out

# Finalizes the generated Lua config class code by turning a raw list of lines and indentation instructions
# into a single string which is (hopefully) a valid Lua code.
def docld_to_lua_finalize(raw):
	output = ""
	indent = 0
	for i in range(len(raw)):
		if type(raw[i]) is int:
			# Integers are indentation instructions.
			indent += raw[i]
		else:
			if raw[i] == "":
				# Don't indent empty lines.
				output += "\n"
				continue
			output += "    " * indent + raw[i] + "\n"
	# Remove the last newline.
	return output[:-1]

# Converts DocLangData to a Lua config class.
def docld_to_lua(entry, class_name, schema_path, pack = True):
	raw = docld_to_lua_raw(entry, class_name, schema_path)
	if pack:
		raw = docld_to_lua_pack(raw, entry, class_name, schema_path)
	return docld_to_lua_finalize(raw)



# Converts DocLang to a JSON schema.
def docl_to_schema(data, structures_path):
	data = docl_to_docld(data)
	return docld_to_schema(data, True, structures_path)

# Converts DocLang to a Lua config class.
def docl_to_lua(data, class_name, schema_path, pack = True):
	data = docl_to_docld(data)
	return docld_to_lua(data, class_name, schema_path, pack)



# Converts a DocLang (.docl) file to an appropriate JSON schema file. Some paths are computed in the process.
def docl_convert_file(path_in, path_out):
	contents = load_file(path_in)
	structures_path = "../" * (len(path_in.split("/")) - 2) + "_structures/"
	new_contents = json.dumps(docl_to_schema(contents, structures_path), indent = 4)
	save_file(path_out, new_contents)

# Converts a DocLang (.docl) file to an appropriate Lua config class file.
def docl_convert_file_lua(path_in, path_out):
	contents = load_file(path_in)
	class_name = ("UI2" if "ui2" in path_in else "") + case_snake_to_pascal(path_in.split("/")[-1][:-5]) + "Config"
	new_contents = docl_to_lua(contents, class_name, path_in[5:-5] + ".json")
	save_file(path_out, new_contents)

# Converts a DocLang (.docl) file to a config class, and then matches its contents with what's in the specified Config Class file (.lua).
def docl_test_file_lua(path_test, path_against):
	contents_test = load_file(path_test)
	try:
		contents_against = load_file(path_against)
	except IOError:
		contents_against = None
	contents_tested = docl_to_lua(contents_test, "ExampleObject", "example_object.json", False)
	if contents_against == None:
		print(path_test + " -> " + path_against + ": " + C_YELLOW + "NO LUA FILE FOUND" + C_RESET)
		print(indent_text(C_YELLOW + C_BOLD + "Should be:" + C_RESET, 4))
		print(indent_text(contents_tested, 8))
		return False
	elif contents_tested == contents_against:
		print(path_test + " -> " + path_against + ": " + C_GREEN + "SUCCESS" + C_RESET)
		return True
	else:
		print(path_test + " -> " + path_against + ": " + C_RED + "FAILURE" + C_RESET)
		print(indent_text(C_YELLOW + C_BOLD + "Expected (in file):" + C_RESET, 4))
		print(indent_text(contents_against, 8))
		print(indent_text(C_YELLOW + C_BOLD + "Actual (generated):" + C_RESET, 4))
		print(indent_text(contents_tested, 8))
		return False

# Checks if the Lua config class file is protected from writing.
def docl_is_config_class_protected(path):
	try:
		contents = load_file(path)
		return contents[:6] != "--!!--"
	except IOError:
		# TODO: When all Config Classes are implemented, set this to False to allow new config files to be created.
		return True



# Converts all .docl files in data folder to the corresponding schemas.
def docl_all_to_schemas():
	for r, d, f in os.walk("data"):
		r = r[4:].replace("\\", "/") # i.e. "data" -> "", "data\config" -> "/config"
		for file in f:
			if not file.endswith(".docl"):
				continue
			path_in = "data" + r + "/" + file
			path_out = "../../schemas" + r + "/" + file[:-5] + ".json"
			print(path_in + " -> " + path_out)
			docl_convert_file(path_in, path_out)

# Converts all .docl files in data folder to the corresponding config class files.
# internal_output works as follows:
#   - True: All config files will be converted and put into the `out_lua` folder. All files will be overwritten and no checks are being performed.
#   - False: The config files will land in `src/Configs` in the root game folder. Only existing and unprotected files will be overwritten.
# After all config classes will be implemented, the flag will be removed and new files could be created, only in `src/Configs`. The `out_lua` folder will be removed.
def docl_all_to_configs(internal_output):
	for r, d, f in os.walk("data"):
		r = r[4:].replace("\\", "/") # i.e. "data" -> "", "data\config" -> "/config"
		for file in f:
			if not file.endswith(".docl"):
				continue
			path_in = "data" + r + "/" + file
			if internal_output:
				path_out = "out_lua/" + ("UI2" if r == "/ui2" else "") + case_snake_to_pascal(file[:-5]) + ".lua"
			else:
				path_out = "../../src/Configs/" + ("UI2" if r == "/ui2" else "") + case_snake_to_pascal(file[:-5]) + ".lua"
			if not internal_output and docl_is_config_class_protected(path_out):
				print(C_YELLOW + path_in + " -> " + path_out + " - Skipped!" + C_RESET)
			else:
				print(C_GREEN + path_in + " -> " + path_out + C_RESET)
				docl_convert_file_lua(path_in, path_out)

# Converts all `.docl` files in the `tests/docl` folder to config class files and checks them with corresponding files from `tests/lua`.
def docl_test_all_configs():
	failure_count = 0
	for r, d, f in os.walk("tests/docl"):
		r = r[10:].replace("\\", "/") # i.e. "tests/docl" -> "", "tests/docl\config" -> "/config"
		for file in f:
			if not file.endswith(".docl"):
				continue
			path_test = "tests/docl" + r + "/" + file
			path_against = "tests/lua" + r + "/" + file[:-5] + ".lua"
			result = docl_test_file_lua(path_test, path_against)
			if not result:
				failure_count += 1
	if failure_count == 0:
		print(C_GREEN + C_BOLD + "All tests have passed! :D" + C_RESET)
	else:
		print(C_RED + C_BOLD + str(failure_count) + " " + ("tests" if failure_count > 1 else "test") + " did not pass... :( Check above for more information." + C_RESET)



# Generates and prints DocLD from DocL in a given file.
def docl_print_docld(path):
	contents = load_file(path)
	print(json.dumps(docl_to_docld(contents), indent = 4))

# Generates and prints a schema from DocL in a given file.
def docl_print_schema(path):
	contents = load_file(path)
	print(json.dumps(docl_to_schema(contents, "structures/"), indent = 4))

# Generates and prints a Lua Config Class from DocL in a given file.
def docl_print_lua(path, class_name, schema_path, pack = True):
	contents = load_file(path)
	print(docl_to_lua(contents, class_name, schema_path, pack))



def main():
	print_usage = True
	if len(sys.argv) >= 2:
		if sys.argv[1] == "-a":
			docl_all_to_schemas()
			docl_all_to_configs(False)
			print_usage = False
		elif sys.argv[1] == "-c":
			docl_all_to_configs(True)
			print_usage = False
		elif sys.argv[1] == "-t":
			docl_test_all_configs()
			print_usage = False
		elif sys.argv[1] == "-pd":
			if len(sys.argv) >= 3:
				docl_print_docld(sys.argv[2])
				print_usage = False
		elif sys.argv[1] == "-ps":
			if len(sys.argv) >= 3:
				docl_print_schema(sys.argv[2])
				print_usage = False

	#docl_print_lua(path, "CollectibleGeneratorConfig", "collectible_generator.json")

	#html_process_data()

	if print_usage:
		print("Usage:")
		print("  generate.py " + C_YELLOW + C_BOLD + "-a" + C_RESET + "         - Converts all DocLang files to schemas and Config Classes.")
		print("  generate.py " + C_YELLOW + C_BOLD + "-c" + C_RESET + "         - Converts all DocLang files to Config Classes without protection checks into the " + C_WHITE + C_BOLD + "out_lua" + C_RESET + " directory.")
		print("  generate.py " + C_YELLOW + C_BOLD + "-t" + C_RESET + "         - Performs DocLang to Config Class tests.")
		print("  generate.py " + C_YELLOW + C_BOLD + "-pd" + C_RESET + " " + C_CYAN + C_BOLD + "<file>" + C_RESET + " - Prints DocLD data from the given DocL file.")
		print("  generate.py " + C_YELLOW + C_BOLD + "-ps" + C_RESET + " " + C_CYAN + C_BOLD + "<file>" + C_RESET + " - Prints a schema generated from the given DocL file.")
	else:
		print("Done")
		input()



if __name__ == "__main__":
	main()