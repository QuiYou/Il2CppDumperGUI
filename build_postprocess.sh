#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="${GITHUB_REPOSITORY:-Leeksov/Il2CppDumperGUI}"

PROJ_DIR=""
for candidate in \
    "${IL2CPP_POSTPROCESS_DIR:-}" \
    "$SCRIPT_DIR/Il2CppPostProcess" \
    "$SCRIPT_DIR/Il2CppDumperGUI/Il2CppPostProcess" \
    "$SCRIPT_DIR/Il2CppDumperGUI/Il2CppDumperGUI/Il2CppPostProcess"
do
    if [ -n "$candidate" ] && [ -f "$candidate/Il2CppPostProcess.csproj" ]; then
        PROJ_DIR="$candidate"
        break
    fi
done

OUT_DIR=""
for candidate in \
    "$SCRIPT_DIR/Il2CppDumperGUI/Resources" \
    "$SCRIPT_DIR/Il2CppDumperGUI/Il2CppDumperGUI/Resources" \
    "$SCRIPT_DIR/Resources"
do
    if [ -d "$candidate" ]; then
        OUT_DIR="$candidate"
        break
    fi
done

download_prebuilt() {
    local release_api
    local asset_url
    local tmpdir

    release_api="https://api.github.com/repos/$REPO/releases/latest"
    asset_url="$(curl -fsSL "$release_api" | awk -F'"' '/browser_download_url/ {print $4; exit}')"

    if [ -z "$asset_url" ]; then
        echo "错误：找不到发布资源 $release_api"
        exit 1
    fi

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    echo "从以下位置下载预构建的后处理资源："
    echo "  $asset_url"
    curl -fL "$asset_url" -o "$tmpdir/Il2CppDumperGUI.zip"
    unzip -jo "$tmpdir/Il2CppDumperGUI.zip" \
        "Il2CppDumperGUI.app/Contents/Resources/Il2CppPostProcess" \
        "Il2CppDumperGUI.app/Contents/Resources/Il2CppDummyDll.dll" \
        -d "$OUT_DIR"
    chmod +x "$OUT_DIR/Il2CppPostProcess"
}

if [ -z "$OUT_DIR" ]; then
    echo "错误：找不到应用程序资源目录"
    echo "已检查:"
    echo "  - $SCRIPT_DIR/Il2CppDumperGUI/Resources"
    echo "  - $SCRIPT_DIR/Il2CppDumperGUI/Il2CppDumperGUI/Resources"
    echo "  - $SCRIPT_DIR/Resources"
    exit 1
fi

if [ -z "$PROJ_DIR" ]; then
    echo "本次检出中未找到 Il2CppPostProcess.csproj 文件"
    echo "回退到最新的预构建版本资源"
    echo ""
    mkdir -p "$OUT_DIR"
    download_prebuilt
    echo ""
    echo "=== 成功 ==="
    file "$OUT_DIR/Il2CppPostProcess"
    ls -lh "$OUT_DIR/Il2CppPostProcess" "$OUT_DIR/Il2CppDummyDll.dll"
    echo ""
    echo "现在重新构建 Xcode 项目."
    exit 0
fi

# Find dotnet only when building from source.
if [ -x "/opt/homebrew/opt/dotnet@8/libexec/dotnet" ]; then
    DOTNET="/opt/homebrew/opt/dotnet@8/libexec/dotnet"
    export DOTNET_ROOT="/opt/homebrew/opt/dotnet@8/libexec"
elif [ -x "/usr/local/share/dotnet/dotnet" ]; then
    DOTNET="/usr/local/share/dotnet/dotnet"
    export DOTNET_ROOT="/usr/local/share/dotnet"
else
    echo "错误：未找到 dotnet。安装：brew install dotnet@8"
    exit 1
fi

echo "使用: $DOTNET"
"$DOTNET" --version
echo ""

cd "$PROJ_DIR"

echo "=== 构建 arm64（苹果芯片） ==="
"$DOTNET" publish Il2CppPostProcess.csproj \
    -r osx-arm64 --self-contained -c Release \
    -p:PublishSingleFile=true -p:PublishTrimmed=true \
    -p:InvariantGlobalization=true \
    -o bin/publish-arm64

echo ""
echo "=== 构建 x64（Intel） ==="
"$DOTNET" publish Il2CppPostProcess.csproj \
    -r osx-x64 --self-contained -c Release \
    -p:PublishSingleFile=true -p:PublishTrimmed=true \
    -p:InvariantGlobalization=true \
    -o bin/publish-x64

echo ""
echo "=== 创建通用二进制文件 ==="
mkdir -p "$OUT_DIR"
lipo -create \
    bin/publish-arm64/Il2CppPostProcess \
    bin/publish-x64/Il2CppPostProcess \
    -output "$OUT_DIR/Il2CppPostProcess"
chmod +x "$OUT_DIR/Il2CppPostProcess"
cp "$PROJ_DIR/Libraries/Il2CppDummyDll.dll" "$OUT_DIR/Il2CppDummyDll.dll"

echo ""
echo "=== 成功 ==="
file "$OUT_DIR/Il2CppPostProcess"
ls -lh "$OUT_DIR/Il2CppPostProcess" "$OUT_DIR/Il2CppDummyDll.dll"
echo ""
echo "现在重新构建 Xcode 项目."
