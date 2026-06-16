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

list_beautify_git_tag_info() {
    local tag_ver="$1"
    {
        raw_data=$(git show "${tag_ver}" | sed -n '/^Tagger:/,/^commit/{//!p}' | sed '/^$/d')
        if [ -z "$raw_data" ]; then
            printf "%s%s\t%s%s\n" "$gl_huang" "(无标签信息)" "$gl_huang" "未找到标签 ${tag_ver} 或无Tagger相关内容" "$reset"
        else
            echo "$raw_data" | awk -v key_color="$gl_lan" \
                                 -v val_color="$gl_bufan" \
                                 -v reset="$reset" '
            BEGIN {
                FS=": ";
                OFS="\t"
                map_key["Tagger"] = "标签创建人"
                map_key["Date"] = "创建时间"
                map_week["Mon"] = "周一"
                map_week["Tue"] = "周二"
                map_week["Wed"] = "周三"
                map_week["Thu"] = "周四"
                map_week["Fri"] = "周五"
                map_week["Sat"] = "周六"
                map_week["Sun"] = "周日"
                map_month["Jan"] = "01月"
                map_month["Feb"] = "02月"
                map_month["Mar"] = "03月"
                map_month["Apr"] = "04月"
                map_month["May"] = "05月"
                map_month["Jun"] = "06月"
                map_month["Jul"] = "07月"
                map_month["Aug"] = "08月"
                map_month["Sep"] = "09月"
                map_month["Oct"] = "10月"
                map_month["Nov"] = "11月"
                map_month["Dec"] = "12月"
                is_desc = 0
            }
            /^[A-Za-z]+: / {
                eng_key = $1
                content = $2
                show_key = (eng_key in map_key) ? map_key[eng_key] : eng_key
                if (eng_key == "Date") {
                    split(content, dt, " ")
                    w = dt[1]; m = dt[2]; day = dt[3]; time = dt[4]; year = dt[5]; zone = dt[6]
                    cn_week = (w in map_week) ? map_week[w] : w
                    cn_month = (m in map_month) ? map_month[m] : m
                    content = year "年" cn_month day "日 " time " " cn_week " 时区" zone
                }
                print key_color show_key reset, val_color content reset
                is_desc = 0
                next
            }
            {
                if (is_desc == 0) {
                    print key_color "标签备注" reset, val_color $0 reset
                    is_desc = 1
                } else {
                    print key_color "" reset, val_color $0 reset
                }
            }
            '
        fi
    } | column_if_available
}

list_beautify_all() {
    local tag="${1:-}"

    clear
    if [ -n "$tag" ]; then
        echo -e "${gl_zi}>>> Git标签 ${tag} 基础信息${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        list_beautify_git_tag_info "${tag}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    else
        local tag_list
        tag_list=$(git tag 2>/dev/null)
        if [ -z "$tag_list" ]; then
            echo -e "${gl_huang}无标签${gl_bai}"
            break_end
            return
        fi
        echo "$tag_list" | while IFS= read -r t; do
            [ -z "$t" ] && continue
            echo -e "${gl_zi}>>> Git标签 ${t} 基础信息${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            list_beautify_git_tag_info "${t}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        done
    fi
    break_end
}

list_beautify_all "$@"
