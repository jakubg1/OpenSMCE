import os, json



def convert_schema_type(schema):
	schema_type_assoc = {
		"integer": "number",
		"array": "list",
		"Color*": "Color",
		"Vector2*": "Vector2",
		"ExprVector2*": "Expression|Vector2"
	}
	
	if "anyOf" in schema:
		types = []
		for child in schema["anyOf"]:
			type = convert_schema_type(child)
			if not type in types:
				types.append(type)
		type = "|".join(types)
	elif "$ref" in schema:
		ref_path = schema["$ref"].split("/")
		if len(ref_path) > 1 and ref_path[-2] == "_structures":
			type = ref_path[-1].split(".")[0] + "*"
		else:
			type = "object"
	elif "const" in schema or "enum" in schema:
		type = "string"
	else:
		type = schema["type"]
	if type in schema_type_assoc:
		type = schema_type_assoc[type]

	return type



def convert_schema(schema, page, references, name = "", indent = 1):
	# Alternatives use special syntax.
	if "oneOf" in schema and not "type" in schema:
		output = "D" + "\t" * indent + "R <div class=\"jsonChoice\">\n"
		output += "D" + "\t" * indent + "R One of the following:\n"
		for data in schema["oneOf"]:
			output += convert_schema(data, page, references, name, indent)
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
			output += convert_schema(key_data, page, references, key, indent + 1)
	elif "patternProperties" in schema:
		output += convert_schema(schema["patternProperties"][list(schema["patternProperties"].keys())[0]], page, references, "", indent + 1)
	
	if "items" in schema:
		output += convert_schema(schema["items"], page, references, "", indent + 1)
	
	return output



def convert_schema_enum(schema, page, references):
	output = ""

	for i in range(len(schema["allOf"])):
		if i == 0:
			continue
		else:
			type_name = list(schema["allOf"][i]["if"]["properties"].keys())[0]
			output += "H3\t<i>" + schema["allOf"][i]["if"]["properties"][type_name]["const"] + "</i>\n"
			output += "P\t" + schema["allOf"][i]["if"]["properties"][type_name]["description"] + "\n"
			enum_data = {
				"type": schema["type"],
				"description": schema["description"],
				"properties": {},
				"required": schema["allOf"][i]["if"]["required"]
			}
			for property in schema["allOf"][i]["then"]["properties"]:
				if property == "$schema":
					continue
				# Copy all properties from the "then" section, if it has a True value then borrow from the "if" section, or from the global properties.
				value = schema["allOf"][i]["then"]["properties"][property]
				if value == True:
					if property in schema["allOf"][i]["if"]["properties"]:
						value = schema["allOf"][i]["if"]["properties"][property]
					else:
						value = schema["properties"][property]
				enum_data["properties"][property] = value
			if "required" in schema["allOf"][i]["then"]:
				enum_data["required"] += schema["allOf"][i]["then"]["required"]
			enum_data["required"] += schema["required"]
			
			output += convert_schema(enum_data, page, references)
		
	return output



def process_data():
	file = open("data.txt", "r")
	contents = file.read()
	file.close()
	
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
			file = open(line[1], "r")
			schema = json.loads(file.read())
			file.close()
			print(schema)
			converted = convert_schema(schema, current_page, reference_names) if line[0] == "DI" else convert_schema_enum(schema, current_page, reference_names)
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



# Finds all pairs of Markdown. Kinda dodgy because it's not extensively used. Available pairs are `code`, *italic*, **bold** and ***bold italic***.
# Returns a list of text segments with a formatting field.
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



def docl_parse(data):
	out = {}
	current_children = []

	lines = data.split("\n")
	for line in lines:
		line_out = {}

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
		curly = False
		for i in range(1, len(line)):
			token = line[i]
			# If we're parsing the curly brace part.
			if curly:
				if token[-1] == "}":
					line_out["keyconst_description"] += token[:-1]
					curly = False
				else:
					line_out["keyconst_description"] += token + " "
				continue

			# Otherwise, just parse the token as normal.
			if token[0] == "(" and token[-1] == ")": # (type) or ($ref) or (#internal_ref) or (Structure)
				# Different types can be separated with | and mixed around, e.g. (#internal_ref|#internal_ref|Structure).
				line_out["types"] = []
				subtokens = token[1:-1].split("|")
				for subtoken in subtokens:
					if subtoken[0] == "$": # $ref
						line_out["types"].append({"ref": subtoken[1:]})
					elif subtoken[0] == "#": # #internal_ref
						line_out["types"].append({"internal_ref": subtoken})
					elif subtoken[0].lower() != subtoken[0]: # Structure
						line_out["types"].append({"structure": subtoken})
					else: # type
						line_out["types"].append({"type": subtoken})
				# "types" don't exist if there's one type. Instead, have a direct field: "ref", "internal_ref", "structure" or "type".
				if len(line_out["types"]) == 1:
					line_out[list(line_out["types"][0].keys())[0]] = list(line_out["types"][0].values())[0]
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
			else: # name
				line_out["name"] = token
		
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



def docl_convert_entry(entry, is_root = True, structures_path = "_structures/"):
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
		out["type"] = entry["type"]
	elif "internal_ref" in entry:
		out["$ref"] = entry["internal_ref"]
	elif "ref" in entry:
		out["$ref"] = entry["ref"] + ".json"
	elif "structure" in entry:
		out["$ref"] = structures_path + entry["structure"] + ".json"
	elif "const" in entry:
		out["const"] = entry["const"]
	elif "types" in entry:
		# Deal with multitypes.
		out["anyOf"] = []
		for choice in entry["types"]:
			if "type" in choice:
				out["anyOf"].append({"type": choice["type"]})
			elif "internal_ref" in choice:
				out["anyOf"].append({"$ref": choice["internal_ref"]})
			elif "ref" in choice:
				out["anyOf"].append({"$ref": choice["ref"] + ".json"})
			elif "structure" in choice:
				out["anyOf"].append({"$ref": structures_path + choice["structure"] + ".json"})
			elif "const" in choice:
				out["anyOf"].append({"const": choice["const"]})
				
	elif not "children" in entry:
		# Non-typed and non-const values with no children mean that any value will suffice. This is depicted as true.
		return True
	
	# Carry the description as well.
	if "description" in entry:
		stripped_description = markdown_strip(entry["description"])
		out["description"] = stripped_description
		# If we lost some Markdown, make sure to preserve it via an additional field.
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
				out["patternProperties"]["^.*$"] = docl_convert_entry(entry["children"][0], False, structures_path)
			elif "keyconst" in entry:
				# So-called "Enum Object".
				key = entry["keyconst"]
				out["properties"] = {key: {"enum": []}}
				out["allOf"] = [{"properties": {key: {"description": entry["keyconst_description"]}}}]
				if "children" in entry:
					for child in entry["children"]:
						child_block = {}
						# We can't really hook up a call to itself here, because children of this child would get involved and mess things up.
						child_block["if"] = {"properties": {key: {"const": child["const"], "description": child["description"]}}, "required": [key]}
						# Now similar stuff to regular objects. Shenanigans incoming!!!
						# Adding an array as a child at the front with an asterisk ensures that it will come first, display as True and won't show up as required twice.
						child_children = [{"name": key + "*"}]
						if "children" in child:
							child_children += child["children"]
						child_block["then"] = docl_convert_entry({"type": "object", "children": child_children}, False, structures_path)
						del child_block["then"]["type"]
						# Add prepared blocks.
						out["allOf"].append(child_block)
						out["properties"][key]["enum"].append(child["const"])
				out["required"] = [key]
			elif not "name" in entry["children"][0]: # One nameless child in a regular object means that the object behaves like an array, with all keys possible.
				out["patternProperties"] = {}
				out["patternProperties"]["^.*$"] = docl_convert_entry(entry["children"][0], False, structures_path)
			else: # Regular object.
				out["properties"] = {}
				out["required"] = []
				out["additionalProperties"] = False
				if is_root:
					out["properties"]["$schema"] = True
				if "children" in entry:
					for child in entry["children"]:
						name = child["name"]
						# Names ending with an asterisk depict optional properties.
						if name[-1] == "*":
							name = name[:-1]
						else:
							out["required"].append(name)
						out["properties"][name] = docl_convert_entry(child, False, structures_path)
				if len(out["required"]) == 0:
					del out["required"]
		elif entry["type"] == "array":
			# Nothing more, nothing less, exactly ONE nameless child must be here.
			out["items"] = docl_convert_entry(entry["children"][0], False, structures_path)
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
				out["oneOf"].append(docl_convert_entry(child, False, structures_path))
	
	return out



def docl_to_schema(data, structures_path):
	data = docl_parse(data)
	return docl_convert_entry(data, True, structures_path)



def docl_convert_file(path_in, path_out):
	file = open(path_in, "r")
	contents = file.read()
	file.close()
	structures_path = "../" * (len(path_in.split("/")) - 2) + "_structures/"
	new_contents = json.dumps(docl_to_schema(contents, structures_path), indent = 4)
	file = open(path_out, "w")
	file.write(new_contents)
	file.close()



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



def docl_test():
	file = open("data2.txt", "r")
	contents = file.read()
	file.close()
	print(json.dumps(docl_to_schema(contents), indent = 4))



def main():
	#docl_test()
	docl_all_to_schemas()
	#process_data()
	print("Done")
	input()



if __name__ == "__main__":
	main()