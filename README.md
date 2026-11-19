# TxtToWav

テキストファイルに記述した周波数と再生時間から、WAVファイルを生成するPowerShellスクリプトです。

## 概要

指定した周波数のサイン波を生成し、WAVファイルとして出力します。  
周波数に `0` を指定すると無音になります。

## 使い方

### 1. 入力ファイルの作成

`music.txt` に周波数と再生時間を記述します。  
同梱の`music.txt`は一例です。  
1行につき、以下の形式で記述します。

```text
周波数 再生時間
```

- 周波数：Hz（小数も指定可能）
- 再生時間：ms（整数）
- 空行および `#` で始まる行は無視されます。

### 2. WAVファイルの生成

PowerShellで以下を実行します。

```powershell
.\TxtToWav.ps1
```

同じフォルダにある `music.txt` を読み込み、`music.wav` を生成します。  
同梱の`music.wav`は生成例です。  
入力ファイルと出力ファイルを指定することもできます。

```powershell
.\TxtToWav.ps1 -InputFile "input.txt" -OutputFile "output.wav"
```
