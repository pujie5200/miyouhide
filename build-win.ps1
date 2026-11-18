# build-win.ps1 — 在 Windows 上用 LLVM(clang + ld64.lld) 交叉编译 iOS arm64 dylib
# 用法:  powershell -ExecutionPolicy Bypass -File build-win.ps1
param(
    [string]$LLVM = "E:\DP\github\llvm\clang+llvm-19.1.7-x86_64-pc-windows-msvc"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$clang = Join-Path $LLVM "bin\clang.exe"
$ld64  = Join-Path $LLVM "bin\ld64.lld.exe"
if (!(Test-Path $clang)) { throw "clang 不存在: $clang" }
if (!(Test-Path $ld64))  { throw "ld64.lld 不存在: $ld64" }

$out = Join-Path $root "build"
Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $out | Out-Null

$common = @(
    "-target", "arm64-apple-ios14.0",
    "-fobjc-arc", "-fobjc-exceptions", "-fblocks",
    "-O2", "-Wall",
    "-Isrc",
    "-c"
)

$objs = @()
foreach ($src in @("src\WLHook.m", "src\WLUI.m")) {
    $obj = Join-Path $out (([IO.Path]::GetFileNameWithoutExtension($src)) + ".o")
    Write-Host "== clang $src"
    & $clang @common $src -o $obj
    if ($LASTEXITCODE -ne 0) { throw "编译失败: $src" }
    $objs += $obj
}

Write-Host "== ld64.lld 链接"
& $ld64 -arch arm64 `
    -platform_version ios 14.0 14.0 `
    -dylib `
    -undefined dynamic_lookup `
    -install_name "@executable_path/MiYouHide.dylib" `
    -adhoc_codesign `
    -o (Join-Path $out "MiYouHide.dylib") `
    @objs
if ($LASTEXITCODE -ne 0) { throw "链接失败" }

$dylib = Join-Path $out "MiYouHide.dylib"
Write-Host "== 产物: $dylib"
Get-Item $dylib | Select-Object FullName, Length | Format-List
