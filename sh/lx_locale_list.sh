#!/bin/bash
set -uo pipefail

list_color_init() {
    export gl_hui=$'\033[38;5;59m'
    export gl_hong=$'\033[38;5;9m'
    export gl_lv=$'\033[38;5;10m'
    export gl_huang=$'\033[38;5;11m'
    export gl_lan=$'\033[38;5;32m'
    export gl_bai=$'\033[38;5;15m'
    export gl_zi=$'\033[38;5;13m'
    export gl_bufan=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_linux_locale() {
    {
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "类别" "当前值" "状态" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "$reset"

        local vars
        vars="LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL"

        for var in $vars; do
            val=$(locale -k "$var" 2>/dev/null | head -1 | cut -d= -f2-)
            [ -z "$val" ] && val=$(eval "echo \"\${$var:-}\"" 2>/dev/null)
            if [ -z "$val" ]; then
                printf "%s%s\t%s%s\t%s%s\n" "$gl_lan" "$var$reset" \
                       "$gl_hong" "(未设置)$reset" \
                       "$gl_hong" "缺失$reset"
            else
                printf "%s%s\t%s%s\t%s%s\n" "$gl_lan" "$var$reset" \
                       "$gl_bufan" "$val$reset" \
                       "$gl_lv" "正常$reset"
            fi
        done

        echo ""
        echo -e "${gl_zi}--- 系统键盘布局 ---${gl_bai}"

        if command -v localectl &> /dev/null; then
            layout=$(localectl status 2>/dev/null | grep "Layout" | awk -F: '{print $2}' | xargs)
            model=$(localectl status 2>/dev/null | grep "Model" | awk -F: '{print $2}' | xargs)
            variant=$(localectl status 2>/dev/null | grep "Variant" | awk -F: '{print $2}' | xargs)
            printf "%s%s\t%s%s\n" "$gl_hui" "键盘布局" "键盘模型" "$reset"
            printf "%s%s\t%s%s\n" "$gl_hui" "--------" "--------" "$reset"
            printf "%s%s\t%s%s\n" "$gl_lv" "${layout:---}$reset" \
                   "$gl_huang" "${model:---}$reset"
            [ -n "$variant" ] && printf "%s%s\t%s%s\n" "$gl_bufan" "变体: $variant$reset"
        else
            printf "%s%s\n" "$gl_huang" "(localectl 命令不可用)$reset"
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux语言环境列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_locale
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
