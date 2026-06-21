import os

for root, dirs, files in os.walk('modules'):
    for file in files:
        if file.endswith('.tf') and file != 'outputs.tf' and file != 'variables.tf':
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                content = f.read()

            new_content = ""
            i = 0
            while i < len(content):
                # Search for tags = { or tags= {
                if content[i:i+6] == 'tags =' or content[i:i+5] == 'tags=':
                    # check if the next non-whitespace char is {
                    j = i + (6 if content[i:i+6] == 'tags =' else 5)
                    while j < len(content) and content[j].isspace():
                        j += 1
                    if j < len(content) and content[j] == '{':
                        # We found a tags block. Let's find the matching }
                        brace_count = 1
                        k = j + 1
                        while k < len(content) and brace_count > 0:
                            if content[k] == '{':
                                brace_count += 1
                            elif content[k] == '}':
                                brace_count -= 1
                            k += 1
                        
                        # Now j is the index of {, k-1 is the index of }
                        inner_content = content[j+1:k-1]
                        replacement = f"merge({{{inner_content}}}, var.tags)"
                        new_content += content[i:i] + "tags = " + replacement
                        i = k
                        continue
                new_content += content[i]
                i += 1
                
            if content != new_content:
                with open(path, 'w') as f:
                    f.write(new_content)
        elif file == 'variables.tf':
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                content = f.read()
            if 'variable "tags"' not in content:
                with open(path, 'a') as f:
                    f.write('\nvariable "tags" {\n  type    = map(string)\n  default = {}\n}\n')
