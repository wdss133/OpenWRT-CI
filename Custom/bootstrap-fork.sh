#!/usr/bin/env bash
# ============================================================================
# Custom/bootstrap-fork.sh —— fork VIKINGYFY/OpenWRT-CI 后的一键定制
#
# 幂等：可以反复执行，结果一致。每次重新 fork 上游后跑一次即可。
# 用法：bash Custom/bootstrap-fork.sh [仓库根目录]
#
# 做的事：
#   1. Config/IPQ807X-WIFI-YES.txt  → 只留 qualcommax/ipq807x/redmi_ax6-stock
#   2. Config/PRIVATE.txt           → 由 Custom/packages.seed 生成（插件清单）
#   3. Scripts/PRIVATE.sh           → 由 Custom/private.sh 生成（iStore/wechatpush/预启用）
#   4. 新增 .github/workflows/CUSTOM-AX6.yml（每月 3 次的编译入口，含月末 Gate）
#   5. 新增 .github/workflows/Custom-Clean.yml（按 36 个月末 + 当月 清理 Release）
#   6. QCA-ALL.yml                 → 摘掉 workflow_run 触发（避免 Auto-Clean 每天触发全平台编译）
#   7. Auto-Clean.yml              → 只清运行记录，不再删 Release / tag
# ============================================================================
set -Eeuo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

CONFIG_NAME="${CONFIG_NAME:-IPQ807X-WIFI-YES}"
DEVICE="${DEVICE:-redmi_ax6-stock}"
THEME="${THEME:-argon}"

log()  { printf '[bootstrap] %s\n' "$*"; }
warn() { printf '::warning::%s\n' "$*"; }
die()  { printf '[bootstrap][error] %s\n' "$*" >&2; exit 1; }

[ -f .github/workflows/QCA-ALL.yml ] || die "这里不像 OpenWRT-CI 仓库根目录（找不到 .github/workflows/QCA-ALL.yml）"
[ -d Custom ]                       || die "找不到 Custom/ 目录"
[ -f "Config/$CONFIG_NAME.txt" ]     || die "找不到 Config/$CONFIG_NAME.txt"

# ---------------------------------------------------------------------------
# 1) 设备清单：只留一台
# ---------------------------------------------------------------------------
cat > "Config/${CONFIG_NAME}.txt" <<EOF
#设备平台（由 Custom/bootstrap-fork.sh 生成，勿手改）
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq807x=y
#设备列表：只编这一台
CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_${DEVICE}=y
EOF
log "Config/${CONFIG_NAME}.txt → 仅 ${DEVICE}"

# ---------------------------------------------------------------------------
# 2) 插件清单 → Config/PRIVATE.txt（被 Scripts/Settings.sh 追加到 .config）
# ---------------------------------------------------------------------------
cp Custom/packages.seed Config/PRIVATE.txt
log "Config/PRIVATE.txt ← Custom/packages.seed（$(grep -c '^CONFIG_PACKAGE_.*=y' Custom/packages.seed) 个包）"

# ---------------------------------------------------------------------------
# 3) 私有扩展脚本 → Scripts/PRIVATE.sh（被 Scripts/Packages.sh source）
# ---------------------------------------------------------------------------
cp Custom/private.sh Scripts/PRIVATE.sh
chmod +x Scripts/PRIVATE.sh
log "Scripts/PRIVATE.sh ← Custom/private.sh"

# ---------------------------------------------------------------------------
# 4) 安装两个自有 workflow（幂等覆盖）
# ---------------------------------------------------------------------------
install -m 644 Custom/workflows/CUSTOM-AX6.yml   .github/workflows/CUSTOM-AX6.yml
install -m 644 Custom/workflows/Custom-Clean.yml .github/workflows/Custom-Clean.yml
log "已安装 CUSTOM-AX6.yml / Custom-Clean.yml"

# 把主题名同步进新 workflow（单一来源：bootstrap 的 THEME 变量）
sed -i -E "s#^([[:space:]]*)WRT_THEME: .*\$#\1WRT_THEME: ${THEME}#" .github/workflows/CUSTOM-AX6.yml

# ---------------------------------------------------------------------------
# 5) 断开所有平台的 workflow_run 自动触发
#    上游是「Auto-Clean 跑完 → 5 个平台全量编译」，每个平台几十台设备。
#    我们只要 AX6，所以除了自己的 CUSTOM-AX6，其余 *-ALL.yml 一律只保留手动触发。
# ---------------------------------------------------------------------------
BROKEN=0
for f in .github/workflows/*-ALL.yml; do
	[ -e "$f" ] || continue
	[ "$(basename "$f")" = "CUSTOM-AX6.yml" ] && continue
	if grep -q '^  workflow_run:' "$f"; then
		sed -i '/^  workflow_run:$/,/^      - completed$/d' "$f"
		sed -i '/^  #.*Auto-Clean.*$/d' "$f"
		BROKEN=$((BROKEN + 1))
	fi
	# 顺手把 matrix 收敛，避免手动跑时编一整个平台
	sed -i -E "s#^([[:space:]]*)CONFIG: \[.*\][[:space:]]*\$#\1CONFIG: [${CONFIG_NAME}]#" "$f"
done
log "已断开 ${BROKEN} 个平台的 Auto-Clean 自动触发（保留 workflow_dispatch）"

# 清理频率：上游是每周清一次 ccache，会导致下次全量编译，改成每月 1 号
if [ -f .github/workflows/Cache-Clean.yml ]; then
	sed -i -E 's#^([[:space:]]*- cron:).*#\1 0 20 1 * *#' .github/workflows/Cache-Clean.yml
	log "Cache-Clean.yml：改为每月 1 号清理（避免每次编译都全量重建）"
fi

# ---------------------------------------------------------------------------
# 6) Auto-Clean：只清运行记录，保留 Release 与 tag
#    （原版是每天删光所有 Release，会把历史固件一起清掉）
# ---------------------------------------------------------------------------
AUTO=.github/workflows/Auto-Clean.yml
sed -i -E "s#^([[:space:]]*- cron:).*#\1 0 20 * * 1#" "$AUTO"           # 每周一 04:00 北京
sed -i -E "s#^([[:space:]]*)delete_releases: true#\1delete_releases: false#" "$AUTO"
sed -i -E "s#^([[:space:]]*)delete_tags: true#\1delete_tags: false#" "$AUTO"
sed -i -E "s#^([[:space:]]*)releases_keep_latest: 0#\1releases_keep_latest: 0#" "$AUTO"
sed -i -E "s#^([[:space:]]*)workflows_keep_day: 0#\1workflows_keep_day: 3#" "$AUTO"
sed -i '/自动清理/s/.*/  #自动清理：每周一 04:00（北京时间），只清运行记录，不动 Release \/ tag/' "$AUTO"
log "Auto-Clean.yml：不再删 Release/tag，运行记录保留 3 天，每周一清理"

# ---------------------------------------------------------------------------
# 7) 自检
# ---------------------------------------------------------------------------
n_dev="$(grep -c '^CONFIG_TARGET_DEVICE_.*=y' "Config/${CONFIG_NAME}.txt" || true)"
[ "$n_dev" = "1" ] || die "设备筛选异常：Config/${CONFIG_NAME}.txt 里有 ${n_dev} 个机型"
grep -q "DEVICE_${DEVICE}=y" "Config/${CONFIG_NAME}.txt" || die "设备名不对：${DEVICE}"
grep -q 'workflow_run:' .github/workflows/QCA-ALL.yml && die "QCA-ALL 仍有 workflow_run"
grep -q 'delete_releases: true' "$AUTO" && die "Auto-Clean 仍会删 Release"

log "完成。自检通过："
log "  机型：${DEVICE}（WIFI-YES）"
log "  主题：${THEME}"
log "  编译日：每月 10 / 20 / 月末，北京时间 21:00"
log "  下一步：git add -A && git commit -m 'custom: AX6 only + 自选插件 + 每月3次' && git push"
