# .NET Support

この文書は、C# static analysis の範囲、export の識別、scene binding check、境界を説明します。

---

## 何をやるか

plugin の .NET support は、C# の構造を素早く読むためのものです。

- file を開かずに構造を理解したい
- export member を見たい
- class や method の骨格を知りたい
- scene との binding に問題がないか確認したい

---

## 何をやらないか

- project 全体を compile して解釈することはしない
- SemanticModel に依存しない
- 外部 IDE debugger の代わりにはしない
- heavy な code analysis engine にはしない

---

## Roslyn の使い方

Roslyn は syntax-first で使います。

- syntax tree を読む
- class、base type、method、enum、export member を抜く
- analysis の結果を tool response に返す

---

## export の識別

C# export は、script と scene の bridge で重要です。

- どの member が export されているかを見る
- scene に入っている値と対応を取る
- 変な binding があれば診断する

---

## scene binding check

scene binding check では、次のような問題を探します。

- NodePath がずれている
- export が scene に反映されていない
- custom Resource の定義と scene 側の使い方が合っていない

---

## 境界

- plugin 内 Roslyn は、Godot .NET project の実務に合わせる
- しかし、フルな C# compiler service にはしない
- まず実用的な binding と構造の確認を優先する

---

## 関連文書

- script / scene analysis は [脚本与场景分析.md](脚本与场景分析.md)
- tool system 全体は [工具系统.md](工具系统.md)
- runtime service との接点は [../架构/运行时服务.md](../架构/运行时服务.md)
