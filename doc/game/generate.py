import json



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
	if "oneOf" in schema:
		# Prepare for enum generation.
		if len(description) == 1:
			description[0] += " Available values are:"
		else:
			description.append("Available values are:")
	if "$ref" in schema:
		ref_path = schema["$ref"].split("/")
		# If we're referencing to a full file, and not just a sturcture, add a link in the document.
		if (len(ref_path) <= 1 or ref_path[-2] != "_structures") and ref_path[0] != "#":
			reference = ref_path[-1].split(".")[0]
			if not reference in references:
				message = "More info... uhh dead link :( Fix me!"
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

	properties_root = None
	if "properties" in schema:
		properties_root = schema
	elif "patternProperties" in schema:
		properties_root = schema["patternProperties"][list(schema["patternProperties"].keys())[0]]
	
	if properties_root != None:
		for key in properties_root["properties"]:
			if key == "$schema":
				continue
			key_data = properties_root["properties"][key]
			if not key in properties_root["required"]:
				key += "*"
			output += convert_schema(key_data, page, references, key, indent + 1)
	
	if "items" in schema:
		output += convert_schema(schema["items"], page, references, "", indent + 1)
	
	return output



def convert_schema_enum(schema, page, references):
	output = ""

	for i in range(len(schema["allOf"])):
		if i == 0:
			continue
		else:
			output += "H3\t<i>" + schema["allOf"][i]["if"]["properties"]["type"]["const"] + "</i>\n"
			output += "P\t" + schema["allOf"][i]["if"]["properties"]["type"]["description"] + "\n"
			enum_data = {
				"type": schema["type"],
				"description": schema["description"],
				"properties": {},
				"required": schema["allOf"][i]["if"]["required"]
			}
			for property in schema["allOf"][i]["then"]["properties"]:
				# Copy all properties from the "then" section, if it has a True value then borrow from the "if" section.
				value = schema["allOf"][i]["then"]["properties"][property]
				if value == True:
					value = schema["allOf"][i]["if"]["properties"][property]
				enum_data["properties"][property] = value
			if "required" in schema["allOf"][i]["then"]:
				enum_data["required"] += schema["allOf"][i]["then"]["required"]
			
			output += convert_schema(enum_data, page, references)
		
	return output



def main():
	file = open("data.txt", "r")
	contents = file.read()
	file.close()
	
	data = contents.split("\n")
	
	type_assoc = {
		"Font*": "str_font",
		"ColorPalette*": "str_palette",
		"Particle*": "str_particle",
		"SoundEvent*": "str_sound",
		"Music*": "str_music",
		"Sprite*": "str_sprite",
		"CollectibleGenerator*": "str_collectible_generator",
		"Expression": "expression",
		"Vector2": "vector2"
	}
	
	
	
	# Pass 1: Gather page and reference names
	page_paths = []
	page_names = []
	reference_names = {} # reference -> page name
	
	for line in data:
		line = line.split("\t")
		
		if line[0] == "F":
			page_paths.append(line[1])
		elif line[0] == "N":
			page_names.append(line[1])
		elif line[0] == "H2":
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
					type_res = type
					if type in type_assoc:
						type_res = type_assoc[type]
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
			page_content += "<h1>" + line[1] + "</h1>"
		
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
	
	
	
	print("Done")
	input()



if __name__ == "__main__":
	main()