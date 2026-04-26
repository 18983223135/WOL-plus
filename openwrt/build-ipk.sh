#!/bin/bash
# Build ipk for luci-app-wolp - single architecture (ramips/mt7621)

set -e

# 接收外部传入的 TARGET 变量（从 GitHub Actions 的 matrix 传入）
TARGET=${TARGET:-ramips/mt7621}

# 根据 TARGET 确定 OpenWrt 架构名称（用于 IPK 的 Architecture 字段）
case "$TARGET" in
  ramips/mt7621)
    ARCH="mipsel_24kc"
    ;;
  *)
    echo "Unsupported target: $TARGET"
    exit 1
    ;;
esac

echo "=========================================="
echo "  Building for target: $TARGET"
echo "  Architecture: $ARCH"
echo "=========================================="

# ==============================================================================
# 配置
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/ipk-build"
OUTPUT_DIR="$PROJECT_ROOT/release"
SOURCE_DIR="$SCRIPT_DIR/luci-app-wolp"

VERSION="${VERSION:-1.0.1}"
PACKAGE_NAME="luci-app-wolp"
I18N_PACKAGE_NAME="luci-i18n-wolp-zh-cn"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/${PACKAGE_NAME}_"*.ipk "$OUTPUT_DIR/${I18N_PACKAGE_NAME}_"*.ipk
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ==============================================================================
# 构建主包
# ==============================================================================
build_ipk() {
    local ARCH=$1
    local PACKAGE_DIR="$BUILD_DIR/package-$ARCH"
    local IPK_FILE="${PACKAGE_NAME}_${VERSION}_${ARCH}.ipk"

    echo "Building main package for $ARCH..."
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR/CONTROL"

    # control 文件
    cat > "$PACKAGE_DIR/CONTROL/control" << EOF
Package: luci-app-wolp
Version: $VERSION
Depends: libc, luci-base, etherwake, netcat, rpcd-mod-ucode, ucode-mod-fs
Section: luci
Architecture: $ARCH
Maintainer: leeyeel <mumuli52@gmail.com>
Description: LuCI Support for Wake-on-LAN Plus
EOF

    # postinst, prerm, postrm
    cat > "$PACKAGE_DIR/CONTROL/postinst" << 'EOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true
rm -rf /tmp/luci-* 2>/dev/null || true
echo "luci-app-wolp installed"
exit 0
EOF
    cat > "$PACKAGE_DIR/CONTROL/prerm" << 'EOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
echo "Removing luci-app-wolp..."
exit 0
EOF
    cat > "$PACKAGE_DIR/CONTROL/postrm" << 'EOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true
rm -rf /tmp/luci-* 2>/dev/null || true
echo "luci-app-wolp removed"
exit 0
EOF
    chmod 755 "$PACKAGE_DIR/CONTROL/"*

    # 复制文件
    mkdir -p "$PACKAGE_DIR/www/luci-static/resources/view"
    cp "$SOURCE_DIR/htdocs/luci-static/resources/view/wolp.js" \
       "$PACKAGE_DIR/www/luci-static/resources/view/"

    mkdir -p "$PACKAGE_DIR/etc/config"
    cp "$SOURCE_DIR/root/etc/config/luci-wolp" "$PACKAGE_DIR/etc/config/"

    mkdir -p "$PACKAGE_DIR/usr/share/luci/menu.d"
    cp "$SOURCE_DIR/root/usr/share/luci/menu.d/luci-app-wolp.json" \
       "$PACKAGE_DIR/usr/share/luci/menu.d/"

    mkdir -p "$PACKAGE_DIR/usr/share/rpcd/acl.d"
    cp "$SOURCE_DIR/root/usr/share/rpcd/acl.d/luci-app-wolp.json" \
       "$PACKAGE_DIR/usr/share/rpcd/acl.d/"

    mkdir -p "$PACKAGE_DIR/usr/share/rpcd/ucode"
    cp "$SOURCE_DIR/root/usr/share/rpcd/ucode/luci.wolp" \
       "$PACKAGE_DIR/usr/share/rpcd/ucode/"
    chmod 755 "$PACKAGE_DIR/usr/share/rpcd/ucode/luci.wolp"

    # 打包为 tar.gz 格式的 IPK
    echo "2.0" > "$PACKAGE_DIR/debian-binary"
    cd "$PACKAGE_DIR/CONTROL"
    tar --numeric-owner --owner=0 --group=0 -czf "$BUILD_DIR/control-$ARCH.tar.gz" .
    cd "$PACKAGE_DIR"
    tar --numeric-owner --owner=0 --group=0 -czf "$BUILD_DIR/data-$ARCH.tar.gz" www etc usr 2>/dev/null || true
    cd "$SCRIPT_DIR"
    cp "$PACKAGE_DIR/debian-binary" "$BUILD_DIR/debian-binary-$ARCH"

    cd "$BUILD_DIR"
    tar --numeric-owner --owner=0 --group=0 -czf "$OUTPUT_DIR/$IPK_FILE" \
        debian-binary-$ARCH control-$ARCH.tar.gz data-$ARCH.tar.gz
    cd "$OUTPUT_DIR"
    mkdir -p "tmp-$ARCH"
    cd "tmp-$ARCH"
    tar -xzf "../$IPK_FILE"
    mv "debian-binary-$ARCH" "debian-binary"
    mv "control-$ARCH.tar.gz" "control.tar.gz"
    mv "data-$ARCH.tar.gz" "data.tar.gz"
    tar --numeric-owner --owner=0 --group=0 -czf "../$IPK_FILE" \
        debian-binary control.tar.gz data.tar.gz
    cd "$OUTPUT_DIR"
    rm -rf "tmp-$ARCH"
    cd "$SCRIPT_DIR"

    rm -f "$BUILD_DIR/control-$ARCH.tar.gz" "$BUILD_DIR/data-$ARCH.tar.gz" "$BUILD_DIR/debian-binary-$ARCH"
    rm -rf "$PACKAGE_DIR"
    echo "Built: $OUTPUT_DIR/$IPK_FILE"
}

# ==============================================================================
# 构建中文包
# ==============================================================================
build_i18n() {
    local ARCH=$1
    local PACKAGE_DIR="$BUILD_DIR/i18n-$ARCH"
    local IPK_FILE="${I18N_PACKAGE_NAME}_${VERSION}_${ARCH}.ipk"

    echo "Building Chinese translation for $ARCH..."
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR/CONTROL"

    cat > "$PACKAGE_DIR/CONTROL/control" << EOF
Package: luci-i18n-wolp-zh-cn
Version: $VERSION
Depends: luci-app-wolp
Section: luci
Architecture: $ARCH
Maintainer: leeyeel <mumuli52@gmail.com>
Description: Chinese translation for luci-app-wolp
EOF
    cat > "$PACKAGE_DIR/CONTROL/postinst" << 'EOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
rm -f /usr/lib/lua/luci/i18n/wolp.zh-cn.lmo
/etc/init.d/uhttpd restart 2>/dev/null || true
echo "Chinese translation installed"
exit 0
EOF
    cat > "$PACKAGE_DIR/CONTROL/postrm" << 'EOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
rm -f /usr/lib/lua/luci/i18n/wolp.zh-cn.lmo
/etc/init.d/uhttpd restart 2>/dev/null || true
echo "Chinese translation removed"
exit 0
EOF
    chmod 755 "$PACKAGE_DIR/CONTROL/"*

    mkdir -p "$PACKAGE_DIR/usr/lib/lua/luci/i18n"
    if [ -f "$SOURCE_DIR/po/zh_Hans/wolp.po" ]; then
        "$SCRIPT_DIR/po2lmo" "$SOURCE_DIR/po/zh_Hans/wolp.po" \
            "$PACKAGE_DIR/usr/lib/lua/luci/i18n/wolp.zh-cn.lmo"
    else
        echo "Error: wolp.po not found"
        exit 1
    fi

    echo "2.0" > "$PACKAGE_DIR/debian-binary"
    cd "$PACKAGE_DIR/CONTROL"
    tar --numeric-owner --owner=0 --group=0 -czf "$BUILD_DIR/control-i18n-$ARCH.tar.gz" .
    cd "$PACKAGE_DIR"
    tar --numeric-owner --owner=0 --group=0 -czf "$BUILD_DIR/data-i18n-$ARCH.tar.gz" usr
    cd "$SCRIPT_DIR"
    cp "$PACKAGE_DIR/debian-binary" "$BUILD_DIR/debian-binary-i18n-$ARCH"

    cd "$BUILD_DIR"
    tar --numeric-owner --owner=0 --group=0 -czf "$OUTPUT_DIR/$IPK_FILE" \
        debian-binary-i18n-$ARCH control-i18n-$ARCH.tar.gz data-i18n-$ARCH.tar.gz
    cd "$OUTPUT_DIR"
    mkdir -p "tmp-i18n-$ARCH"
    cd "tmp-i18n-$ARCH"
    tar -xzf "../$IPK_FILE"
    mv "debian-binary-i18n-$ARCH" "debian-binary"
    mv "control-i18n-$ARCH.tar.gz" "control.tar.gz"
    mv "data-i18n-$ARCH.tar.gz" "data.tar.gz"
    tar --numeric-owner --owner=0 --group=0 -czf "../$IPK_FILE" \
        debian-binary control.tar.gz data.tar.gz
    cd "$OUTPUT_DIR"
    rm -rf "tmp-i18n-$ARCH"
    cd "$SCRIPT_DIR"

    rm -f "$BUILD_DIR/control-i18n-$ARCH.tar.gz" "$BUILD_DIR/data-i18n-$ARCH.tar.gz" "$BUILD_DIR/debian-binary-i18n-$ARCH"
    rm -rf "$PACKAGE_DIR"
    echo "Built: $OUTPUT_DIR/$IPK_FILE"
}

# ==============================================================================
# 执行构建
# ==============================================================================
build_ipk "$ARCH"
build_i18n "$ARCH"

echo ""
echo "=========================================="
echo "  Build completed for $ARCH"
echo "=========================================="
ls -lh "$OUTPUT_DIR/"*.ipk
