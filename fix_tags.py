import os
import re

for root, dirs, files in os.walk('modules'):
    for file in files:
        if file == 'variables.tf':
            path = os.path.join(root, file)
            with open(path, 'a') as f:
                f.write('\nvariable "tags" {\n  type    = map(string)\n  default = {}\n}\n')
        elif file.endswith('.tf') and file != 'outputs.tf':
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                content = f.read()

            # Replace existing tags = { ... } with tags = merge({ ... }, var.tags)
            content = re.sub(r'tags\s*=\s*\{([^{}]*)\}', r'tags = merge({\1}, var.tags)', content)

            # Find all resource blocks
            def add_tags(match):
                block = match.group(0)
                if 'tags = ' not in block and 'tags =' not in block:
                    # insert tags = var.tags before the last '}'
                    last_brace_index = block.rfind('}')
                    if last_brace_index != -1:
                        block = block[:last_brace_index] + '  tags = var.tags\n' + block[last_brace_index:]
                return block

            # This regex attempts to find a top-level resource block. It's tricky because of nested blocks.
            # Instead of parsing HCL in python, let's just add tags to existing ones first, then see.
            with open(path, 'w') as f:
                f.write(content)
