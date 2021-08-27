

##  pyinstaller

安装 pyinstaller

`````
python -m pip install pyinstaller
`````

安装后，把Scripts所在路径添加到PATH中。

`````
pyinstaller -F main.py
`````



去除控制台加`-w`

````
pyinstaller -F -w main.py
````



加入应用图标`-i`

```
pyinstaller -F -w -i .\resource\app.ico  main.py
```



执行上面的命令后会生成一个spec文件

```python
# -*- mode: python ; coding: utf-8 -*-

block_cipher = None


a = Analysis(['main.py'],
             pathex=['E:\\project\\python\\OSTools\\com.xiyue.huohua.tools'],
             binaries=[],
             datas=[],
             hiddenimports=[],
             hookspath=[],
             runtime_hooks=[],
             excludes=[],
             win_no_prefer_redirects=False,
             win_private_assemblies=False,
             cipher=block_cipher,
             noarchive=False)
pyz = PYZ(a.pure, a.zipped_data,
             cipher=block_cipher)
exe = EXE(pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas,
          [],
          name='main',
          debug=False,
          bootloader_ignore_signals=False,
          strip=False,
          upx=True,
          upx_exclude=[],
          runtime_tmpdir=None,
          console=False )

```

执行配置

````
pyinstaller -F main.spec
````

````python
# -*- mode: python ; coding: utf-8 -*
block_cipher = None
a = Analysis(['main.py'],
                pathex=['E:\\project\\python\\OSTools\\com.xiyue.huohua.tools'],
                binaries=[],
                datas=[],
                hiddenimports=[],
                hookspath=[],
                runtime_hooks=[],
                excludes=[],
                win_no_prefer_redirects=False,
                win_private_assemblies=False,
                cipher=block_cipher,
                noarchive=False)
pyz = PYZ(a.pure, a.zipped_data,cipher=block_cipher)
a.datas += [('huohua.ico','E:\\project\\python\\OSTools\\com.xiyue.huohua.tools\\resource\\huohua.ico','DATA')]
exe = EXE(pyz,
            a.scripts,
            a.binaries,
            a.zipfiles,
            a.datas,
            [],
            name='小工具',
            debug=False,
            bootloader_ignore_signals=False,
            strip=False,
            upx=True,
            upx_exclude=[],
            runtime_tmpdir=None,
            console=False,
            icon='E:\\project\\python\\OSTools\\com.xiyue.huohua.tools\\resource\\huohua.ico')

````

