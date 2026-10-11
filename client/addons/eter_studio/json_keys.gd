@tool
extends RefCounted
static func duplicates(content: String) -> Array[String]:
	var result: Array[String]=[]
	var stack: Array=[]
	var index := 0
	while index<content.length():
		var character := content[index]
		if character in ["{","["]: stack.append({"kind":character,"keys":{}})
		elif character in ["}","]"]:
			if not stack.is_empty(): stack.pop_back()
		elif character=='"':
			var start := index; index+=1
			while index<content.length():
				if content[index]=="\\": index+=2; continue
				if content[index]=='"': break
				index+=1
			var token := content.substr(start,index-start+1)
			var following := index+1
			while following<content.length() and content[following] in [" ","\t","\r","\n"]: following+=1
			if following<content.length() and content[following]==":" and not stack.is_empty() and stack.back().kind=="{":
				var key: Variant=JSON.parse_string(token)
				if stack.back().keys.has(key): result.append(str(key))
				stack.back().keys[key]=true
		index+=1
	return result
