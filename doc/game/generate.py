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
		"Sprite*": "str_sprite"
	}
	
	
	
	page_paths = []
	page_names = []
	
	for line in data:
		line = line.split("\t")
		
		if line[0] == "F":
			page_paths.append(line[1])
		elif line[0] == "N":
			page_names.append(line[1])
	
	
	
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
			page_content += "<li><a href=\"index.html\">Main Page</a></li>"
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
				s = l.split(" |")
				
				description = s[1]
				
				s = s[0].split(" (")
				
				name = s[0][2:]
				optional = len(name) > 0 and name[-1] == "*"
				if optional:
					name = name[:-1]
				
				type = s[1][:-1]
				if type in type_assoc:
					type = type_assoc[type]
				
				page_content += "<li class=\"" + type + "\">"
				if len(name) == 0:
					page_content += description
				elif optional:
					page_content += "<span class=\"nameOpt\">" + name + "</span>: " + description
				else:
					page_content += "<span class=\"name\">" + name + "</span>: " + description
				page_content += "</li>"
		
		
		
		elif line[0] == "R":
			page_content += line[1]
		
		elif line[0] == "N":
			page_content += "<h1>" + line[1] + "</h1>"
		
		elif line[0] == "H2":
			page_content += "<h2>" + line[1] + "</h2>"
		
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