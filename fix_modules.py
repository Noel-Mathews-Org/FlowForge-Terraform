import re

files_to_modify = ['env/prod/main.tf', 'env/dev/main.tf']

for path in files_to_modify:
    with open(path, 'r') as f:
        content = f.read()
    
    # We want to add tags = var.tags to every module "..." { block.
    # We can split the file by module " and process each block.
    # But since we just want to inject tags, a regex might be risky. Let's just do a simple replacement if we find module blocks.
    lines = content.split('\n')
    new_lines = []
    in_module = False
    brace_count = 0
    
    for line in lines:
        if line.startswith('module "'):
            in_module = True
            brace_count = line.count('{') - line.count('}')
            new_lines.append(line)
        elif in_module:
            brace_count += line.count('{') - line.count('}')
            if brace_count == 0: # closing brace of the module
                new_lines.append('  tags = var.tags')
                in_module = False
            new_lines.append(line)
        else:
            new_lines.append(line)
            
    with open(path, 'w') as f:
        f.write('\n'.join(new_lines))
