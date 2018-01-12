console.show()
console.write("处理网盘目录\n")

TITLE_LEVEL=['01超级会员','','','','','']
LINE_NUMBER = 0

file = open(r"z:\2.txt" , "a")


for i in range(editor.getLineCount()) :
    line = editor.getLine(i)
    line_level = 0
    title = ''
    
    try:
        int(line.lstrip()[:2])
    except ValueError:
        # editor.deleteLine(i)
        continue
    
    if line.startswith('          ') :
        line_level = 5
    elif line.startswith('        ') :
        line_level = 4
        TITLE_LEVEL[5] = ''
    elif line.startswith('      ') :
        line_level = 3
        TITLE_LEVEL[4] = ''
        TITLE_LEVEL[5] = ''
    elif line.startswith('    ') :
        line_level = 2
        TITLE_LEVEL[3] = ''
        TITLE_LEVEL[4] = ''
        TITLE_LEVEL[5] = ''
    elif line.startswith('  ') :
        line_level = 1
        TITLE_LEVEL[2] = ''
        TITLE_LEVEL[3] = ''
        TITLE_LEVEL[4] = ''
        TITLE_LEVEL[5] = ''
        
    TITLE_LEVEL[line_level] = line.strip().replace(' ', '')
    title = '|'.join(TITLE_LEVEL[:line_level])
    file.write(title+ ':' + line.strip() +'\n')
    # console.write("TLEVEL = " + '|'.join(TITLE_LEVEL) + '\n')
    LINE_NUMBER += 1
    
    if LINE_NUMBER % 1000 == 0 :
        console.write("已经更新：" + str(LINE_NUMBER) + '\n')

file.close()
console.write("更新完毕！")
