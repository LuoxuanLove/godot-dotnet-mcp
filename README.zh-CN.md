# Godot .NET MCP
[![鏈€鏂扮増鏈琞(https://img.shields.io/github/v/release/LuoxuanLove/godot-dotnet-mcp?label=%E6%9C%80%E6%96%B0%E7%89%88%E6%9C%AC)](https://github.com/LuoxuanLove/godot-dotnet-mcp/releases/latest) [![English README](https://img.shields.io/badge/README-English-24292f)](README.md)

> 杩愯鍦?Godot 缂栬緫鍣ㄨ繘绋嬪唴鐨?MCP 鎻掍欢鈥斺€擜gent 鐩存帴璇诲彇娲荤殑椤圭洰鐘舵€併€佹搷浣滃満鏅笌鑴氭湰銆佽瘖鏂?C# 缁戝畾锛屾棤闇€浠讳綍澶栭儴杩涚▼銆?
![Godot .NET MCP 宸ュ叿椤礭(asset_library/preview-tools-cn.png)

## 杩欐槸浠€涔?
宓屽叆 Godot 缂栬緫鍣ㄨ繘绋嬬殑 MCP 鏈嶅姟绔€傝皟鐢?`intelligence_project_state` 鑾峰彇褰撳墠椤圭洰鐨勭湡瀹炲揩鐓р€斺€斿満鏅暟銆佽剼鏈暟銆侀敊璇粺璁°€佽繍琛岀姸鎬佲€斺€斿啀鐢?`intelligence_project_advise` 鑾峰彇鍏蜂綋鍙墽琛岀殑鏀硅繘寤鸿銆備箣鍚庢牴鎹缓璁紝鐢ㄥ満鏅€佽剼鏈€佽妭鐐规垨璧勬簮宸ュ叿鍋氱簿鍑嗕慨鏀广€?
Intelligence 灞傦紙15 涓唴缃伐鍏凤級鏄?Agent 鐨勬帹鑽愯捣鐐癸紝瑕嗙洊椤圭洰蹇収銆佸満鏅垎鏋愩€佽剼鏈粨鏋勬鏌ャ€丆# 缁戝畾瀹¤涓庣鍙锋悳绱紝璇诲彇鐨勬槸娲荤殑缂栬緫鍣ㄧ姸鎬侊紝鑰屼笉鏄鐩樹笂鐨勬枃浠跺揩鐓с€?
濡傞渶鎵╁睍宸ュ叿闆嗭細鍦?`custom_tools/` 涓斁缃?`.gd` 鏂囦欢锛屽疄鐜?`handles / get_tools / execute`锛屽伐鍏峰悕缁熶竴浠?`user_` 寮€澶淬€傛彃浠惰嚜鍔ㄥ彂鐜板苟鍔犺浇銆俙plugin_evolution` 宸ュ叿缁勮礋璐ｈ剼鎵嬫灦銆佸璁″拰鍒犻櫎銆?
鎻掍欢渚ц繍琛屾€佽嚜妫€缁熶竴閫氳繃 `plugin_runtime_state`锛屼笉鍐嶉澶栨柊澧炵嫭绔嬭嚜妫€宸ュ叿銆俙action=get_lsp_diagnostics_status` 鏄缁嗙殑 LSP 鑷鍏ュ彛锛汭ntelligence 宸ュ叿鍙毚闇茶交閲忓仴搴锋憳瑕侊紝鍏朵腑 `project_state(include_runtime_health=true)` 浼氳繑鍥?`lsp_diagnostics` 鍜?`tool_loader` 涓や唤绠€鐭姸鎬併€?
`intelligence_script_analyze(include_diagnostics=true)` 鐜板湪浼氬厛杩斿洖缁撴瀯淇℃伅锛屽啀鍩轰簬宸蹭繚瀛樺埌纾佺洏鐨勮剼鏈唴瀹瑰湪鍚庡彴琛ラ綈 GDScript LSP 璇婃柇銆傜涓€娆¤皟鐢ㄥ彲鑳芥槸 `pending`锛屽悗缁皟鐢ㄤ細璇诲彇宸茬紦瀛樼殑缁撴灉銆傛湭淇濆瓨鐨勭紪杈戝櫒缂撳啿鍖烘敼鍔ㄦ殏涓嶅寘鍚湪鍐呫€?
## 涓轰粈涔堢敤杩欎釜鎻掍欢

- **杩愯鍦ㄧ紪杈戝櫒鍐呴儴**锛氬湪 Godot 杩涚▼涓繍琛岋紝鍦烘櫙鏌ヨ銆佽剼鏈鍙栧拰灞炴€т慨鏀圭洿鎺ュ弽鏄犵紪杈戝櫒鐨勭湡瀹炵姸鎬併€?- **Godot.NET 浼樺厛**锛欳# 缁戝畾妫€鏌ワ紙`intelligence_bindings_audit`锛夈€佸鍑烘垚鍛樺垎鏋愩€乣.cs` 鑴氭湰淇ˉ鍧囧唴缃紝涓嶆槸闄勫姞鍔熻兘銆?- **Intelligence 浼樺厛**锛歚intelligence_project_state` 鈫?`intelligence_project_advise` 鈫?鍏蜂綋鎿嶄綔锛屾槸璁捐濂界殑宸ヤ綔娴侊紝涓嶉渶瑕佺寽浠庡摢涓師瀛愬伐鍏峰叆鎵嬨€?- **鍙敤鎴锋墿灞?*锛歚custom_tools/` 涓殑鑴氭湰浣滀负涓€绛夊伐鍏峰姞杞斤紝鏃犻渶閲嶅缓鎻掍欢銆俙plugin_evolution` 绠＄悊鍏ㄧ敓鍛藉懆鏈熴€?
## 鐜瑕佹眰

- Godot `4.6+`
- 寤鸿浣跨敤 Godot Mono / .NET 鐗堟湰
- 鍙帴鍏ョ殑 MCP 瀹㈡埛绔紝渚嬪锛?  - Claude Code
  - Codex CLI
  - Gemini CLI
  - Claude Desktop
  - Cursor

## 瀹夎

### 鏂瑰紡涓€锛氱洿鎺ュ鍒舵彃浠剁洰褰?
灏嗘彃浠舵斁鍒颁綘鐨?Godot 椤圭洰鍐咃細

```text
addons/godot_dotnet_mcp
```

鐒跺悗锛?
1. 鐢?Godot 鎵撳紑椤圭洰銆?2. 杩涘叆 `Project Settings > Plugins`銆?3. 鍚敤 `Godot .NET MCP`銆?4. 鍦ㄥ彸渚?Dock 涓墦寮€ `MCPDock`銆?5. 纭绔彛鍚庡惎鍔ㄦ湇鍔°€?
### 鏂瑰紡浜岋細浣滀负 Git Submodule

浠撳簱鏍圭洰褰曞唴鍚?`addons/godot_dotnet_mcp/`锛坴0.4 鍚庨噸缁勶紝鎻掍欢涓嶅啀鍦ㄤ粨搴撴牴閮級銆傛坊鍔犲瓙妯″潡鏃讹紝鍏嬮殕鍒扮埗绾х洰褰曪細

```bash
git submodule add https://github.com/LuoxuanLove/godot-dotnet-mcp.git _godot-dotnet-mcp
```

鎻掍欢浣嶄簬 `_godot-dotnet-mcp/addons/godot_dotnet_mcp/`锛屽皢璇ョ洰褰曞鍒舵垨绗﹀彿閾炬帴鍒伴」鐩殑 `addons/` 涓嬪嵆鍙€傚闇€鏇寸畝鍗曠殑鏂瑰紡锛屾帹鑽愪娇鐢ㄦ柟寮忎笁銆?
### 鏂瑰紡涓夛細浣跨敤鍙戝竷鍖?
浠?GitHub Releases 椤甸潰涓嬭浇鏈€鏂板彂甯冨寘锛?
```text
https://github.com/LuoxuanLove/godot-dotnet-mcp/releases
```

瑙ｅ帇鍚庝繚鎸佺洰褰曠粨鏋勪负锛?
```text
addons/godot_dotnet_mcp
```

鍐嶆寜"鏂瑰紡涓€"鍚敤鍗冲彲銆?
## 蹇€熷紑濮?
### 1. 鍚姩鏈湴鏈嶅姟

鍚敤鎻掍欢鍚庯紝鏈嶅姟鍙牴鎹凡淇濆瓨璁剧疆鑷姩鍚姩锛屼篃鍙湪 `MCPDock > Server` 涓墜鍔ㄥ惎鍔ㄣ€?
鍋ュ悍妫€鏌ワ細

```text
GET http://127.0.0.1:3000/health
```

宸ュ叿鍒楄〃锛?
```text
GET http://127.0.0.1:3000/api/tools
```

MCP 涓诲叆鍙ｏ細

```text
POST http://127.0.0.1:3000/mcp
```

### 2. 杩炴帴瀹㈡埛绔?
鎵撳紑 `MCPDock > Config`锛岄€夋嫨鐩爣骞冲彴鍚庢煡鐪嬫垨澶嶅埗鐢熸垚缁撴灉銆?
- 妗岄潰绔樉绀?JSON 閰嶇疆銆佺洰鏍囪矾寰勫拰鍐欏叆鎿嶄綔
- CLI 瀹㈡埛绔樉绀哄搴斿懡浠ゆ枃鏈?- `Claude Code` 棰濆鏀寔 `user / project` 浣滅敤鍩熷垏鎹?
鎺ㄨ崘椤哄簭锛?
1. 閫夋嫨鐩爣瀹㈡埛绔€?2. 纭鏈嶅姟鍦板潃鍜岀敓鎴愬唴瀹广€?3. 闇€瑕佽嚜鍔ㄨ惤鍦版椂浣跨敤 `Write Config`銆?4. 鍙兂鎵嬪姩澶勭悊鏃朵娇鐢?`Copy`銆?
### 3. 楠岃瘉杩炴帴

寤鸿纭锛?
- `/health` 杩斿洖姝ｅ父锛屽苟鍖呭惈 `tool_loader_status`锛岃繖鏍风┖宸ュ叿闆嗘垨閫€鍖栫姸鎬佷細琚槑纭爣鍑烘潵
- `/api/tools` 鑳借繑鍥炲綋鍓嶅彲瑙佺殑 MCP 宸ュ叿鍒楄〃锛屽苟鍦ㄥ彲鐢ㄦ椂鍖呭惈 `plugin_runtime_*`锛涘彲瑙佹€ц繃婊ょ幇鍦ㄦ槸 fail-closed
- MCP 瀹㈡埛绔兘澶熻繛鎺ュ埌 `http://127.0.0.1:3000/mcp`

### 4. 璇诲彇鏈€杩戜竴娆′富椤圭洰杩愯鐘舵€?
浣跨敤 `intelligence_runtime_diagnose` 璇诲彇鏈€杩戜竴娆＄敱缂栬緫鍣ㄥ惎鍔ㄧ殑杩愯鏃朵俊鎭€斺€旈敊璇€佺紪璇戦棶棰樸€佹€ц兘鏁版嵁銆備富椤圭洰鍋滄鍚庝粛鍙鍙栥€?
## 璺緞绾﹀畾

- 璧勬簮璺緞缁熶竴浣跨敤 `res://`
- 鑺傜偣璺緞榛樿鎺ㄨ崘鐩稿褰撳墠鍦烘櫙鏍硅妭鐐癸紝渚嬪 `Player/Camera2D`
- 涔熸敮鎸?`/root/...` 椋庢牸璺緞
- 宸ュ叿鍐欐搷浣滈粯璁よ姹?鍐欏悗鍙鍥?

## 鏂囨。

- [README.md](README.md)
- [CHANGELOG.md](CHANGELOG.md)
- [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md)
- [docs/姒傝堪.md](docs/%E6%A6%82%E8%BF%B0.md)
- [docs/妯″潡/Intelligence宸ュ叿灞?md](docs/%E6%A8%A1%E5%9D%97/Intelligence%E5%B7%A5%E5%85%B7%E5%B1%82.md)
- [docs/妯″潡/宸ュ叿绯荤粺.md](docs/%E6%A8%A1%E5%9D%97/%E5%B7%A5%E5%85%B7%E7%B3%BB%E7%BB%9F.md)
- [docs/妯″潡/鐢ㄦ埛鎵╁睍.md](docs/%E6%A8%A1%E5%9D%97/%E7%94%A8%E6%88%B7%E6%89%A9%E5%B1%95.md)
- [docs/鏋舵瀯/鏈嶅姟涓庤矾鐢?md](docs/%E6%9E%B6%E6%9E%84/%E6%9C%8D%E5%8A%A1%E4%B8%8E%E8%B7%AF%E7%94%B1.md)
- [docs/鏋舵瀯/閰嶇疆涓庣晫闈?md](docs/%E6%9E%B6%E6%9E%84/%E9%85%8D%E7%BD%AE%E4%B8%8E%E7%95%8C%E9%9D%A2.md)
- [docs/鏋舵瀯/瀹夎涓庡彂甯?md](docs/%E6%9E%B6%E6%9E%84/%E5%AE%89%E8%A3%85%E4%B8%8E%E5%8F%91%E5%B8%83.md)

## 褰撳墠杈圭晫

- 褰撳墠璋冭瘯鍥炶鏀寔涓婚」鐩繍琛屾椂妗ユ帴浜嬩欢涓庣紪杈戝櫒璋冭瘯浼氳瘽鐘舵€侊紝浣嗕笉鏄?Godot 鍘熺敓 Output / Debugger 闈㈡澘鐨?1:1 鏂囨湰闀滃儚
- 璇诲彇杩愯鏃剁姸鎬佹帹鑽愪娇鐢?`intelligence_runtime_diagnose`
- 鏈€杩戜竴娆℃崟鑾风殑浼氳瘽鐘舵€佷笌鐢熷懡鍛ㄦ湡浜嬩欢鍦ㄤ富椤圭洰鍋滄鍚庝粛鍙鍙栵紱鑻ヨ瑙傚療瀹炴椂鏂板浜嬩欢锛屼粛闇€淇濇寔涓婚」鐩繍琛?- 渚濊禆缂栬緫鍣ㄥ疄鏃剁姸鎬佺殑鑳藉姏寤鸿鍦ㄧ湡瀹為」鐩伐浣滄祦涓仛涓€娆￠獙璇?
